--!strict

--[=[
	Who is working in the working folder, and which of them is its admin. While the panel is open,
	this user leaves a heartbeat and a joined time as attributes on the folder (`AdminRules` names
	them); the admin alone changes the shared map settings and hides parts. These attributes are not
	undoable edits, so they are written outside any recording and cleared on leaving. This user's
	last activity is published too, about once a minute, so teammates may take over an idle admin.

	The rules live in `Pure/AdminRules`. Only the user who should become admin writes the change,
	so two clients never race to claim it. The result is mirrored into `AppState` for the panel.

	@class Admin
]=]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local AdminRules = require("../Pure/AdminRules")
local AppState = require("../State/AppState")
local Trove = require("../Packages/Trove")

export type Deps = {
	State: AppState.AppState,
	Say: (text: string) -> (),
	--[=[ True while the panel is open; only then is this user present. ]=]
	IsOpen: () -> boolean,
}

export type Admin = {
	--[=[ This user's id, or 0 when Studio cannot say, which counts as working alone. ]=]
	UserId: number,
	_deps: Deps,
	_folder: Instance?,
	_watch: RBXScriptConnection?,
	_beat: number,
	_clock: number,
	_alive: boolean,
	_activeAt: number,
	_wroteAt: number,
	_fresh: boolean,
	_camera: RBXScriptConnection?,
	_shown: string,
	_names: { [number]: string },
	_avatars: { [number]: string },
	_asked: { [number]: boolean },
}

local LEGACY_PREFIX = "VluxyBT_Active_"
local REFRESH = 1

local Admin = {}

--[[
	@return number -- the Studio user id, or 0 when it cannot be read
]]
local function readUserId(): number
	local ok, id = pcall(function()
		return game:GetService("StudioService"):GetUserId()
	end)

	return if ok and type(id) == "number" then id else 0
end

--[[
	@param name string
	@return boolean -- whether the attribute is one of the presence or admin attributes
]]
local function isOurs(name: string): boolean
	return string.sub(name, 1, #AdminRules.HERE_PREFIX) == AdminRules.HERE_PREFIX
		or string.sub(name, 1, #AdminRules.JOINED_PREFIX) == AdminRules.JOINED_PREFIX
		or string.sub(name, 1, #AdminRules.ACTIVE_PREFIX) == AdminRules.ACTIVE_PREFIX
		or name == AdminRules.ADMIN
		or name == AdminRules.REQUEST
end

--[[
	@param self Admin
	@param id number

	Looks up the user's name and head shot once, off the main path, and redraws when they arrive.
]]
local function lookup(self: Admin, id: number)
	if self._asked[id] or id <= 0 then
		return
	end

	self._asked[id] = true
	task.spawn(function()
		local okName, name = pcall(function()
			return Players:GetNameFromUserIdAsync(id)
		end)

		if okName and type(name) == "string" then
			self._names[id] = name
		end

		local okImage, image = pcall(function()
			return Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)

		if okImage and type(image) == "string" then
			self._avatars[id] = image
		end

		if self._alive then
			Admin.Refresh(self)
		end
	end)
end

--[[
	@param self Admin

	Notes that this user did something just now; `Admin.Step` publishes it.
]]
local function markActive(self: Admin)
	self._activeAt = os.time()
	self._fresh = true
end

--[[
	@param self Admin

	Follows the current camera, so moving it counts as activity; called again when the camera changes.
]]
local function watchCamera(self: Admin)
	if self._camera then
		self._camera:Disconnect()
		self._camera = nil
	end

	local camera = workspace.CurrentCamera

	if camera and self._alive then
		self._camera = camera:GetPropertyChangedSignal("CFrame"):Connect(function()
			markActive(self)
		end)
	end
end

--[[
	@param self Admin
	@param trove Trove

	Counts keys, mouse buttons, mouse moves and wheel, camera moves, script typing, selection
	changes, undo, redo and finished edits as this user's activity.
]]
local function watchActivity(self: Admin, trove: Trove.Trove)
	local function mark()
		markActive(self)
	end

	trove:Connect(UserInputService.InputBegan, function(input: InputObject)
		local kind = input.UserInputType

		if
			kind == Enum.UserInputType.Keyboard
			or kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.MouseButton2
			or kind == Enum.UserInputType.MouseButton3
		then
			mark()
		end
	end)
	trove:Connect(UserInputService.InputChanged, function(input: InputObject)
		local kind = input.UserInputType

		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.MouseWheel then
			mark()
		end
	end)
	pcall(function()
		trove:Connect(game:GetService("ScriptEditorService").TextDocumentDidChange, mark)
	end)
	trove:Connect(Selection.SelectionChanged, mark)
	trove:Connect(ChangeHistoryService.OnUndo, mark)
	trove:Connect(ChangeHistoryService.OnRedo, mark)
	trove:Connect(ChangeHistoryService.OnRecordingFinished, mark)
	trove:Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
		watchCamera(self)
	end)
	watchCamera(self)
end

--[=[
	@param deps Deps
	@param trove Trove -- stops the lookups and drops the folder and activity watches when the plugin unloads
	@return Admin
]=]
function Admin.new(deps: Deps, trove: Trove.Trove): Admin
	local self: Admin = {
		UserId = readUserId(),
		_deps = deps,
		_folder = nil,
		_watch = nil,
		_beat = 0,
		_clock = 0,
		_alive = true,
		_activeAt = os.time(),
		_wroteAt = 0,
		_fresh = false,
		_camera = nil,
		_shown = "",
		_names = {},
		_avatars = {},
		_asked = {},
	}

	watchActivity(self, trove)
	trove:Add(function()
		self._alive = false

		if self._watch then
			self._watch:Disconnect()
			self._watch = nil
		end

		if self._camera then
			self._camera:Disconnect()
			self._camera = nil
		end
	end)

	return self
end

--[=[
	@param self Admin
	@param id number
	@return string -- the user's name, or a stand-in until it loads
]=]
function Admin.NameOf(self: Admin, id: number): string
	lookup(self, id)

	return self._names[id] or `User {id}`
end

--[=[
	@param self Admin
	@return string -- the admin's name, for messages
]=]
function Admin.AdminName(self: Admin): string
	local id = self._deps.State.AdminId()

	return if id then Admin.NameOf(self, id) else "nobody"
end

--[[
	@param folder Instance
	@param now number
	@return { AdminRules.Entry } -- the users present on the folder
]]
local function presentOn(folder: Instance, now: number): { AdminRules.Entry }
	return AdminRules.Present(AdminRules.Read(folder:GetAttributes()), now)
end

--[=[
	Rereads the folder: claims admin when this user should have it, forgets long-gone users, and
	updates the people, admin and request shown in the panel.

	@param self Admin
]=]
function Admin.Refresh(self: Admin)
	local state = self._deps.State
	local folder = self._folder
	local me = self.UserId

	if not folder or me == 0 then
		self._shown = ""
		state.People({})
		state.AdminId(nil)
		state.IsAdmin(true)
		state.AdminRequest(nil)

		return
	end

	local now = os.time()
	local entries = AdminRules.Read(folder:GetAttributes())
	local named = folder:GetAttribute(AdminRules.ADMIN)
	local current = if type(named) == "number" then named else nil

	if RunService:IsEdit() and AdminRules.ShouldClaim(entries, current, me, now) then
		folder:SetAttribute(AdminRules.ADMIN, me)
		current = me
	end

	local admin = AdminRules.Choose(entries, current, now)
	local isAdmin = admin == nil or admin == me
	local present = AdminRules.Present(entries, now)
	local request = AdminRules.ParseRequest(folder:GetAttribute(AdminRules.REQUEST), now)
	local asking = false

	for _, entry in present do
		asking = asking or entry.UserId == request
	end

	if isAdmin and RunService:IsEdit() then
		for _, id in AdminRules.Forgotten(entries, now) do
			folder:SetAttribute(AdminRules.HERE_PREFIX .. id, nil)
			folder:SetAttribute(AdminRules.JOINED_PREFIX .. id, nil)
			folder:SetAttribute(AdminRules.ACTIVE_PREFIX .. id, nil)
		end
	end

	local people: { AppState.Person } = {}
	local keys: { string } = {}

	for _, entry in present do
		local id = entry.UserId
		local idle = AdminRules.IsIdle(entry, now)
		local person: AppState.Person = {
			UserId = id,
			Name = Admin.NameOf(self, id),
			Avatar = self._avatars[id] or "",
			Admin = id == admin,
			Me = id == me,
			Idle = idle,
			IdleMinutes = AdminRules.IdleSeconds(entry, now) // 60,
		}

		table.insert(people, person)
		table.insert(
			keys,
			`{id}|{person.Name}|{person.Avatar}|{person.Admin}|{if idle then person.IdleMinutes else -1}`
		)
	end

	local shown = table.concat(keys, ",")
	local wasAdmin = state.IsAdmin()
	local wasAsked = state.AdminRequest()
	local nowAsked = if isAdmin and asking and request ~= me then request else nil

	if shown ~= self._shown then
		self._shown = shown
		state.People(people)
	end

	state.AdminId(admin)
	state.IsAdmin(isAdmin)
	state.AdminRequest(nowAsked)

	if #present > 1 and isAdmin and not wasAdmin then
		self._deps.Say("You are now the admin of this folder.")
	end

	if nowAsked and nowAsked ~= wasAsked then
		self._deps.Say(`{Admin.NameOf(self, nowAsked)} asks for admin; answer on the Working Folder card.`)
	end
end

--[=[
	Stops being present on the folder: clears this user's attributes, and hands admin on.

	@param self Admin
]=]
function Admin.Leave(self: Admin)
	local folder = self._folder
	local me = self.UserId

	if self._watch then
		self._watch:Disconnect()
		self._watch = nil
	end

	self._folder = nil

	if folder and folder.Parent and RunService:IsEdit() then
		folder:SetAttribute(AdminRules.HERE_PREFIX .. me, nil)
		folder:SetAttribute(AdminRules.JOINED_PREFIX .. me, nil)
		folder:SetAttribute(AdminRules.ACTIVE_PREFIX .. me, nil)

		if folder:GetAttribute(AdminRules.ADMIN) == me then
			folder:SetAttribute(AdminRules.ADMIN, nil)
		end

		if AdminRules.ParseRequest(folder:GetAttribute(AdminRules.REQUEST), os.time()) == me then
			folder:SetAttribute(AdminRules.REQUEST, nil)
		end
	end

	Admin.Refresh(self)
end

--[[
	@param self Admin
	@param folder Instance

	Writes this user's last activity onto the folder, so teammates can tell when they went idle.
]]
local function publishActive(self: Admin, folder: Instance)
	folder:SetAttribute(AdminRules.ACTIVE_PREFIX .. self.UserId, self._activeAt)
	self._wroteAt = os.time()
	self._fresh = false
end

--[[
	@param self Admin
	@param folder Instance

	Becomes present on the folder. A joined time left by this user's last plugin session is kept
	while its heartbeat is fresh, so reloading the plugin keeps their place in line.
]]
local function enter(self: Admin, folder: Instance)
	local me = self.UserId
	local now = os.time()
	local seen = folder:GetAttribute(AdminRules.HERE_PREFIX .. me)
	local joined = folder:GetAttribute(AdminRules.JOINED_PREFIX .. me)

	self._folder = folder

	if not (type(seen) == "number" and now - seen < AdminRules.GONE_AFTER and type(joined) == "number") then
		folder:SetAttribute(AdminRules.JOINED_PREFIX .. me, now)
	end

	folder:SetAttribute(AdminRules.HERE_PREFIX .. me, now)
	markActive(self)
	publishActive(self, folder)
	self._beat = 0
	self._watch = folder.AttributeChanged:Connect(function(name)
		if isOurs(name) then
			self._clock = REFRESH
		end
	end)
end

--[=[
	Runs every frame: follows the working folder and the panel being open, beats every
	`AdminRules.HEARTBEAT` seconds, and publishes new activity at most every `AdminRules.ACTIVE_EVERY`
	seconds. Rereads the folder once a second or when it changes.

	@param self Admin
	@param dt number
]=]
function Admin.Step(self: Admin, dt: number)
	local folder = if self._deps.IsOpen()
			and RunService:IsEdit()
			and self.UserId ~= 0
		then self._deps.State.Folder()
		else nil

	if folder and not folder:IsDescendantOf(workspace) then
		folder = nil
	end

	if folder ~= self._folder then
		Admin.Leave(self)

		if folder then
			enter(self, folder)
		end

		self._clock = REFRESH
	end

	self._beat += dt

	local here = self._folder

	if here and self._beat >= AdminRules.HEARTBEAT then
		self._beat = 0
		here:SetAttribute(AdminRules.HERE_PREFIX .. self.UserId, os.time())
	end

	if here and self._fresh and os.time() - self._wroteAt >= AdminRules.ACTIVE_EVERY then
		publishActive(self, here)
	end

	self._clock += dt

	if self._clock >= REFRESH then
		self._clock = 0
		Admin.Refresh(self)
	end
end

--[=[
	@param self Admin
	@return boolean -- whether this user may change shared settings now; says who may when not
]=]
function Admin.Allows(self: Admin): boolean
	if self._deps.State.IsAdmin() then
		return true
	end

	self._deps.Say(AdminRules.LockedText(Admin.AdminName(self)))

	return false
end

--[=[
	@param self Admin
	@param folder Instance
	@return boolean -- whether someone else is present on the folder now
]=]
function Admin.OthersOn(self: Admin, folder: Instance): boolean
	for _, entry in presentOn(folder, os.time()) do
		if entry.UserId ~= self.UserId then
			return true
		end
	end

	return false
end

--[=[
	@param self Admin
	@return boolean -- whether a teammate has the plugin open on this folder, or an older plugin open anywhere
]=]
function Admin.OthersHere(self: Admin): boolean
	if self._folder and Admin.OthersOn(self, self._folder) then
		return true
	end

	for name, stamp in workspace:GetAttributes() do
		if
			string.sub(name, 1, #LEGACY_PREFIX) == LEGACY_PREFIX
			and type(stamp) == "number"
			and math.abs(os.time() - stamp) < AdminRules.GONE_AFTER
		then
			return true
		end
	end

	return false
end

--[=[
	Hands admin to another user present on the folder. Only the admin may.

	@param self Admin
	@param userId number
]=]
function Admin.Give(self: Admin, userId: number)
	local folder = self._folder

	if not folder or not Admin.Allows(self) or userId == self.UserId then
		return
	end

	if not Admin.OthersOn(self, folder) then
		return self._deps.Say(`{Admin.NameOf(self, userId)} is not here any more.`)
	end

	folder:SetAttribute(AdminRules.ADMIN, userId)
	folder:SetAttribute(AdminRules.REQUEST, nil)
	Admin.Refresh(self)
	self._deps.Say(`{Admin.NameOf(self, userId)} is now the admin.`)
end

--[=[
	Asks the admin to hand admin over; the request runs out after `AdminRules.REQUEST_FOR` seconds.

	@param self Admin
]=]
function Admin.Request(self: Admin)
	local folder = self._folder

	if not folder then
		return self._deps.Say("Pick a working folder first.")
	end

	if self._deps.State.IsAdmin() then
		return self._deps.Say("You are already the admin.")
	end

	folder:SetAttribute(AdminRules.REQUEST, AdminRules.FormatRequest(self.UserId, os.time()))
	self._deps.Say(`Asked {Admin.AdminName(self)} for admin.`)
end

--[[
	@param self Admin
	@param folder Instance
	@return boolean -- whether this user may take admin from an idle admin now
]]
local function canTakeOver(self: Admin, folder: Instance): boolean
	local now = os.time()
	local entries = AdminRules.Read(folder:GetAttributes())
	local named = folder:GetAttribute(AdminRules.ADMIN)
	local admin = AdminRules.Choose(entries, if type(named) == "number" then named else nil, now)

	return AdminRules.CanTakeOver(self.UserId, admin, entries, now)
end

--[=[
	@param self Admin
	@return boolean -- whether someone else is admin, present and idle, so this user may take over
]=]
function Admin.CanTakeOver(self: Admin): boolean
	local folder = self._folder

	return folder ~= nil and canTakeOver(self, folder)
end

--[=[
	Takes admin from an idle admin, after checking again that they are still idle.

	@param self Admin
]=]
function Admin.TakeOver(self: Admin)
	local folder = self._folder

	if not folder or not RunService:IsEdit() then
		return self._deps.Say("Pick a working folder first.")
	end

	if self._deps.State.IsAdmin() then
		return self._deps.Say("You are already the admin.")
	end

	if not canTakeOver(self, folder) then
		return self._deps.Say(`{Admin.AdminName(self)} is not idle any more; request admin instead.`)
	end

	markActive(self)
	publishActive(self, folder)
	folder:SetAttribute(AdminRules.ADMIN, self.UserId)

	if AdminRules.ParseRequest(folder:GetAttribute(AdminRules.REQUEST), os.time()) == self.UserId then
		folder:SetAttribute(AdminRules.REQUEST, nil)
	end

	Admin.Refresh(self)
	self._deps.Say("You are now the admin.")
end

--[=[
	Turns down the open admin request. Only the admin may.

	@param self Admin
]=]
function Admin.Ignore(self: Admin)
	if self._folder and self._deps.State.IsAdmin() then
		self._folder:SetAttribute(AdminRules.REQUEST, nil)
		Admin.Refresh(self)
	end
end

return Admin
