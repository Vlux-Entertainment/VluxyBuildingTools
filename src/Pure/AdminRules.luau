--!strict

--[=[
	Who is the admin of a working folder. Each user with the plugin open on the folder leaves a
	heartbeat and the time they joined as attributes on it; these rules read those values and decide
	who is present, who is admin, and whether an admin request still stands. Plain data only.

	The admin is whoever the folder names while they are present. When they are gone, the user
	present the longest takes over (ties go to the lower user id), and a user alone is always admin.

	@class AdminRules
]=]

--[=[
	One user's presence on a folder.

	@interface Entry
	@within AdminRules
	.UserId number
	.Joined number -- os.time() when they started working in the folder
	.Seen number -- os.time() of their last heartbeat
]=]
export type Entry = { UserId: number, Joined: number, Seen: number }

local AdminRules = {}

--[=[
	The attribute prefix for a user's last heartbeat, followed by their user id.

	@prop HERE_PREFIX string
	@within AdminRules
]=]
AdminRules.HERE_PREFIX = "VluxyBT_Here_"

--[=[
	The attribute prefix for when a user joined the folder, followed by their user id.

	@prop JOINED_PREFIX string
	@within AdminRules
]=]
AdminRules.JOINED_PREFIX = "VluxyBT_Joined_"

--[=[
	The attribute naming the admin's user id.

	@prop ADMIN string
	@within AdminRules
]=]
AdminRules.ADMIN = "VluxyBT_Admin"

--[=[
	The attribute holding a pending admin request, as "userId:time".

	@prop REQUEST string
	@within AdminRules
]=]
AdminRules.REQUEST = "VluxyBT_AdminRequest"

--[=[
	Seconds between heartbeats.

	@prop HEARTBEAT number
	@within AdminRules
]=]
AdminRules.HEARTBEAT = 15

--[=[
	Seconds without a heartbeat after which a user counts as gone.

	@prop GONE_AFTER number
	@within AdminRules
]=]
AdminRules.GONE_AFTER = 45

--[=[
	Seconds after which a gone user's attributes may be removed from the folder.

	@prop FORGET_AFTER number
	@within AdminRules
]=]
AdminRules.FORGET_AFTER = 600

--[=[
	Seconds an admin request stays open.

	@prop REQUEST_FOR number
	@within AdminRules
]=]
AdminRules.REQUEST_FOR = 60

--[=[
	Reads the presence entries out of a folder's attributes. A user with a heartbeat but no joined
	time counts as joining at their heartbeat.

	@param attributes { [string]: any } -- the folder's attributes, as `GetAttributes` returns them
	@return { Entry } -- one per user with a heartbeat, in no particular order
]=]
function AdminRules.Read(attributes: { [string]: any }): { Entry }
	local entries: { Entry } = {}

	for name, value in attributes do
		local digits = string.match(name, "^" .. AdminRules.HERE_PREFIX .. "(%d+)$")
		local id = tonumber(digits)

		if id and type(value) == "number" then
			local joined = attributes[AdminRules.JOINED_PREFIX .. id]

			table.insert(entries, {
				UserId = id,
				Joined = if type(joined) == "number" then joined else value,
				Seen = value,
			})
		end
	end

	return entries
end

--[=[
	@param entry Entry
	@param now number -- os.time()
	@return boolean -- whether the user's heartbeat is recent enough to count them as present
]=]
function AdminRules.IsHere(entry: Entry, now: number): boolean
	return now - entry.Seen < AdminRules.GONE_AFTER
end

--[=[
	@param entries { Entry }
	@param now number
	@return { Entry } -- the users present, longest present first, ties by lower user id
]=]
function AdminRules.Present(entries: { Entry }, now: number): { Entry }
	local here: { Entry } = {}

	for _, entry in entries do
		if AdminRules.IsHere(entry, now) then
			table.insert(here, entry)
		end
	end

	table.sort(here, function(a, b)
		if a.Joined ~= b.Joined then
			return a.Joined < b.Joined
		end

		return a.UserId < b.UserId
	end)

	return here
end

--[=[
	@param entries { Entry }
	@param named number? -- the user id the folder names as admin, if any
	@param now number
	@return number? -- the admin: the named user while present, else the longest present; nil when nobody is
]=]
function AdminRules.Choose(entries: { Entry }, named: number?, now: number): number?
	local here = AdminRules.Present(entries, now)

	if named then
		for _, entry in here do
			if entry.UserId == named then
				return named
			end
		end
	end

	return if here[1] then here[1].UserId else nil
end

--[=[
	Only the user who should become admin writes the change, so two clients never race to claim it.

	@param entries { Entry }
	@param named number? -- the admin the folder names now
	@param me number
	@param now number
	@return boolean -- whether this user should write themselves in as admin
]=]
function AdminRules.ShouldClaim(entries: { Entry }, named: number?, me: number, now: number): boolean
	return named ~= me and AdminRules.Choose(entries, named, now) == me
end

--[=[
	@param entries { Entry }
	@param now number
	@return { number } -- the user ids gone long enough to be removed from the folder
]=]
function AdminRules.Forgotten(entries: { Entry }, now: number): { number }
	local ids: { number } = {}

	for _, entry in entries do
		if now - entry.Seen >= AdminRules.FORGET_AFTER then
			table.insert(ids, entry.UserId)
		end
	end

	return ids
end

--[=[
	@param userId number
	@param time number
	@return string -- the request attribute's value
]=]
function AdminRules.FormatRequest(userId: number, time: number): string
	return `{userId}:{time}`
end

--[=[
	@param value any -- the request attribute's value
	@param now number
	@return number? -- the user asking for admin, or nil when there is no request or it has run out
]=]
function AdminRules.ParseRequest(value: any, now: number): number?
	if type(value) ~= "string" then
		return nil
	end

	local id, time = string.match(value, "^(%d+):(%d+)$")
	local userId, sent = tonumber(id), tonumber(time)

	if not userId or not sent or now - sent >= AdminRules.REQUEST_FOR or sent - now > AdminRules.GONE_AFTER then
		return nil
	end

	return userId
end

--[=[
	@param name string -- the admin's name
	@return string -- the hover text of a control only the admin may change
]=]
function AdminRules.LockedText(name: string): string
	return `Only the admin ({name}) can change this.`
end

return AdminRules
