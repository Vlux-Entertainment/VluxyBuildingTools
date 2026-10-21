-- Vlux Blockout Tools 2.0. Personal Roblox Studio plugin.
-- Ordinary anchored Parts; local CoreGui previews; recorded scene edits.
if not plugin then return end
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
local Input = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local toolbar = plugin:CreateToolbar("Vlux Blockout")
local toggle = toolbar:CreateButton("Blockout Tools", "Vlux Blockout Tools", "", "Blockout Tools")
toggle.ClickableWhenViewportHidden = true
local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 360, 740, 320, 420)
local widget = plugin:CreateDockWidgetPluginGuiAsync("VluxBlockoutTools_v2", info)
widget.Title = "VLUX | Blockout Tools"
local mouse = plugin:GetMouse()
local palette = {
    Color3.fromRGB(188,148,158), Color3.fromRGB(187,158,142),
    Color3.fromRGB(184,184,138), Color3.fromRGB(151,178,146),
    Color3.fromRGB(137,181,166), Color3.fromRGB(139,176,187),
    Color3.fromRGB(145,161,190), Color3.fromRGB(165,149,190),
    Color3.fromRGB(185,145,181), Color3.fromRGB(187,153,167),
}
local rng = Random.new()
local settings = {Grid=1, Elevation=0, Height=12, Thickness=1, Width=8, Floor=1,
    Steps=12, Rise=0.75, Run=1.5, Landing=0, Depth=12, Extend=8,
    OpenWidth=6, OpenHeight=10, Sill=0, Offset=0, Copies=3, ArchHeight=10, ArchDepth=2, ArchSegments=16, SurfaceGridSize=4, StairHeight=6, RampHeight=6,
    DX=12, DY=0, DZ=0, Yaw=0, Roof=false, Pastel=false, Align=false, ShowGrid=true, Axis="X"}
pcall(function()
    local saved = plugin:GetSetting("VluxBlockoutSettings_v2")
    if type(saved)=="table" then
        for k,v in pairs(settings) do if type(saved[k])==type(v) then settings[k]=saved[k] end end
    end
end)
local paletteOn=false
local surfaceGridOn=false
local extendDrag=nil
local extendHover=false
local uiRefresh=function() end
local configRefresh=function() end
local resetExtra=function() end
local worldLabel=nil
local mode, first, current = nil, nil, nil
local sourceRoots, sourceParts, sourcePivot, sourceSize = {}, {}, nil, nil
local previewSpecs = {}
local previewValid = false
local buttons = {}
local fieldBoxes = {}
local connections = {}
local ghosts = {}
local ghostFolder = Instance.new("Folder")
ghostFolder.Name = "VluxBlockout_LocalPreview"
ghostFolder.Parent = CoreGui
local gridFolder = Instance.new("Folder")
gridFolder.Name="SurfaceGrid_LocalOnly"; gridFolder.Parent=CoreGui
local faceHandles=Instance.new("Handles")
faceHandles.Name="DragToExtend"; faceHandles.Style=Enum.HandlesStyle.Resize
faceHandles.Color3=Color3.fromRGB(115,220,190); faceHandles.Visible=false; faceHandles.Parent=ghostFolder
local planeGrid = Instance.new("WireframeHandleAdornment")
planeGrid.Name="ConstructionGrid"; planeGrid.Adornee=workspace.Terrain
planeGrid.Color3=Color3.fromRGB(145,165,185); planeGrid.Transparency=0.65
planeGrid.AlwaysOnTop=false; planeGrid.Parent=ghostFolder
local previewWire=Instance.new("WireframeHandleAdornment")
previewWire.Name="ShapedPreviews"; previewWire.Adornee=workspace.Terrain
previewWire.Color3=Color3.fromRGB(115,188,171); previewWire.Thickness=2
previewWire.AlwaysOnTop=false; previewWire.Parent=ghostFolder
local panelColor = Color3.fromRGB(27,30,38)
local accent = Color3.fromRGB(115,188,171)
local textColor = Color3.fromRGB(230,233,239)
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k,v in pairs(props) do obj[k]=v end
    obj.Parent=parent
    return obj
end
local scroll = make("ScrollingFrame", {Size=UDim2.fromScale(1,1), BackgroundColor3=panelColor,
    BorderSizePixel=0, ScrollBarThickness=5, AutomaticCanvasSize=Enum.AutomaticSize.Y,
    CanvasSize=UDim2.new()}, widget)
make("UIPadding", {PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),
    PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,16)}, scroll)
make("UIListLayout", {Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder}, scroll)
local order=0
local function row(height)
    order=order+1
    return make("Frame",{Size=UDim2.new(1,0,0,height),BackgroundTransparency=1,LayoutOrder=order},scroll)
end
local function label(text,height,color)
    local r=row(height or 22)
    return make("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        Text=text,Font=Enum.Font.Gotham,TextSize=12,TextColor3=color or textColor,
        TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},r)
end
label("VLUX  /  BLOCKOUT TOOLS",26,accent)
label("2.0  •  Draw it. Drag it. Build it.",20)
local status=label("Choose a tool below. All dimensions are in studs.",60,accent)
local function say(text) status.Text=text end
local function save() pcall(function() plugin:SetSetting("VluxBlockoutSettings_v2",settings) end) end
local function clearGhosts()
    for _,g in ipairs(ghosts) do g.Visible=false end
    planeGrid:Clear()
    previewWire:Clear()
end
local function resetPoint()
    first=nil; current=nil; previewSpecs={}; previewValid=false; clearGhosts()
    if worldLabel then worldLabel.Enabled=false end
    resetExtra()
end
local function stop()
    mode=nil; extendDrag=nil; faceHandles.Adornee=nil; faceHandles.Visible=false; resetPoint()
    for _,b in pairs(buttons) do b.BackgroundColor3=Color3.fromRGB(46,51,64) end
    plugin:Deactivate()
    configRefresh()
end
local function edit(action, callback)
    if not Run:IsEdit() then say("Stop the playtest before building."); return false end
    local id=History:TryBeginRecording("Vlux_"..action,action)
    if not id then say("Cannot begin an edit right now. Finish the other tool action first."); return false end
    local ok,err=pcall(callback)
    History:FinishRecording(id,ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
    if not ok then say("Action cancelled: "..tostring(err)); warn("Vlux Blockout: "..tostring(err)) end
    return ok
end
local function snap(n)
    local grid=math.max(0.05,settings.Grid)
    return math.round(n/grid)*grid
end
local function horizontalPoint(y)
    local ray=mouse.UnitRay
    if math.abs(ray.Direction.Y)<0.00001 then return nil end
    local t=(y-ray.Origin.Y)/ray.Direction.Y
    if t<=0 or t>100000 then return nil end
    local p=ray.Origin+ray.Direction*t
    return Vector3.new(snap(p.X),y,snap(p.Z))
end
local function selectedRoots()
    local all=Selection:Get(); local result={}
    for _,obj in ipairs(all) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and obj:IsDescendantOf(workspace) then
            local nested=false
            for _,other in ipairs(all) do if other~=obj and obj:IsDescendantOf(other) then nested=true; break end end
            if not nested then table.insert(result,obj) end
        end
    end
    return result
end
local function partsOf(roots)
    local out={}; local seen={}
    for _,obj in ipairs(roots) do
        if obj:IsA("BasePart") and not seen[obj] then table.insert(out,obj); seen[obj]=true end
        for _,p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") and not seen[p] then table.insert(out,p); seen[p]=true end
        end
    end
    return out
end
local function bounds(parts)
    local low=Vector3.new(math.huge,math.huge,math.huge)
    local high=-low
    for _,p in ipairs(parts) do
        for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
            local v=p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)*0.5)
            low=Vector3.new(math.min(low.X,v.X),math.min(low.Y,v.Y),math.min(low.Z,v.Z))
            high=Vector3.new(math.max(high.X,v.X),math.max(high.Y,v.Y),math.max(high.Z,v.Z))
        end end end
    end
    return CFrame.new((low+high)*0.5),high-low
end
local function spec(out,size,cf,name,source,class)
    if size.X>0.001 and size.Y>0.001 and size.Z>0.001 then
        assert(math.max(size.X,size.Y,size.Z)<=2048,"A generated Part exceeds Studio's 2048-stud size limit. Reduce dimensions.")
        table.insert(out,{size=size,cf=cf,name=name or "Block",source=source,class=class or "Part"})
    end
end
local function materialize(out,title)
    local model=Instance.new("Model"); model.Name=title; model.Parent=workspace
    for _,s in ipairs(out) do
        local p=Instance.new(s.class)
        p.Name=s.name; p.Size=s.size; p.CFrame=s.cf; p.Anchored=true
        p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
        p.Material=Enum.Material.SmoothPlastic
        p.Color=Color3.fromRGB(163,162,165)
        if s.source then
            for _,k in ipairs({"Color","Material","MaterialVariant","Transparency","Reflectance","CanCollide","CanTouch","CanQuery","CastShadow","CollisionGroup","Locked"}) do
                p[k]=s.source[k]
            end
            -- Preserve the intended color when the separate Greybox Colors toggle is active.
            local original=s.source:GetAttribute("VluxGreybox_OriginalColor_v1")
            if typeof(original)=="Color3" then p.Color=original end
        end
        p.Parent=model
    end
    Selection:Set({model})
    return model
end
local function segment(out,a,b,width,height,name)
    local d=b-a; local length=d.Magnitude
    if length<0.05 then return end
    local center=(a+b)*0.5+Vector3.new(0,height*0.5,0)
    spec(out,Vector3.new(width,height,length),CFrame.lookAt(center,center+d),name)
end
local function rectangle(a,b)
    local low=Vector3.new(math.min(a.X,b.X),a.Y,math.min(a.Z,b.Z))
    local high=Vector3.new(math.max(a.X,b.X),a.Y,math.max(a.Z,b.Z))
    return low,high,(low+high)*0.5
end
local function roomSpecs(a,b)
    local out={}; local lo,hi,c=rectangle(a,b); local w=hi.X-lo.X; local d=hi.Z-lo.Z
    local t=settings.Thickness; local h=settings.Height; local f=settings.Floor
    if w<2*t+0.05 or d<2*t+0.05 then return out end
    spec(out,Vector3.new(w,f,d),CFrame.new(c-Vector3.new(0,f/2,0)),"Floor")
    spec(out,Vector3.new(w,h,t),CFrame.new(c.X,a.Y+h/2,lo.Z+t/2),"Wall_North")
    spec(out,Vector3.new(w,h,t),CFrame.new(c.X,a.Y+h/2,hi.Z-t/2),"Wall_South")
    spec(out,Vector3.new(t,h,d-2*t),CFrame.new(lo.X+t/2,a.Y+h/2,c.Z),"Wall_West")
    spec(out,Vector3.new(t,h,d-2*t),CFrame.new(hi.X-t/2,a.Y+h/2,c.Z),"Wall_East")
    if settings.Roof then spec(out,Vector3.new(w,f,d),CFrame.new(c+Vector3.new(0,h+f/2,0)),"Ceiling") end
    return out
end
local function pathSpecs(a,b,corridor)
    local out={}; local d=b-a; local length=d.Magnitude
    if length<0.05 then return out end
    if not corridor then segment(out,a,b,settings.Thickness,settings.Height,"Wall"); return out end
    local cf=CFrame.lookAt((a+b)*0.5,(a+b)*0.5+d)
    local w=settings.Width; local t=settings.Thickness; local h=settings.Height; local f=settings.Floor
    spec(out,Vector3.new(w+2*t,f,length),cf*CFrame.new(0,-f/2,0),"Floor")
    for _,sign in ipairs({-1,1}) do
        spec(out,Vector3.new(t,h,length),cf*CFrame.new(sign*(w+t)/2,h/2,0),"CorridorWall")
    end
    if settings.Roof then spec(out,Vector3.new(w+2*t,f,length),cf*CFrame.new(0,h+f/2,0),"Ceiling") end
    return out
end
local function directionCF(a,b)
    local d=b-a
    if d.Magnitude<0.05 then return nil end
    return CFrame.lookAt(a,a+d)
end
local function stairSpecs(a,b,ramp)
    local out={}; local cf=directionCF(a,b); if not cf then return out end
    local length=(b-a).Magnitude
    local n=math.clamp(math.ceil(length/settings.Run),1,200)
    local run=length/n; local height=ramp and settings.RampHeight or settings.StairHeight
    local rise=height/n
    if ramp then
        -- WedgePart rises toward local +Z. Rotate it to rise away from the first click.
        spec(out,Vector3.new(settings.Width,height,length),cf*CFrame.new(0,height/2,-length/2)*CFrame.Angles(0,math.pi,0),"Ramp",nil,"WedgePart")
    else
        for i=1,n do
            spec(out,Vector3.new(settings.Width,rise*i,run),cf*CFrame.new(0,rise*i/2,-run*(i-0.5)),"Step_"..i)
        end
    end
    if settings.Landing>0 then
        spec(out,Vector3.new(settings.Width,height,settings.Landing),cf*CFrame.new(0,height/2,-length-settings.Landing/2),"Landing")
    end
    return out
end
local function blockSpecs(a,b)
    local out={}; local lo,hi,c=rectangle(a,b)
    spec(out,Vector3.new(hi.X-lo.X,settings.Height,hi.Z-lo.Z),CFrame.new(c+Vector3.new(0,settings.Height/2,0)),"Block")
    return out
end
-- Extrude a planar triangle as two exact triangular WedgeParts.
local function trianglePrism(out,a,b,c,depth,name,source)
    if (b-a).Magnitude<(c-a).Magnitude then b,c=c,b end
    if (b-a).Magnitude<(c-b).Magnitude then a,c=c,a end
    local base=b-a; if base.Magnitude<0.0001 then return end
    local unit=base.Unit
    local foot=a+unit*((c-a):Dot(unit))
    local rise=c-foot; local height=rise.Magnitude
    if height<0.001 then return end
    local up=rise.Unit
    for _,endPoint in ipairs({a,b}) do
        local run=foot-endPoint
        if run.Magnitude>0.001 then
            local back=run.Unit
            local center=(foot+endPoint)*0.5+rise*0.5
            spec(out,Vector3.new(depth,height,run.Magnitude),
                CFrame.fromMatrix(center,up:Cross(back),up,back),name,source,"WedgePart")
        end
    end
end
local function quadPrism(out,a,b,c,d,depth,name,source)
    trianglePrism(out,a,b,c,depth,name,source)
    trianglePrism(out,a,c,d,depth,name,source)
end
local function archSpecs(a,b)
    local out={}; local direction=b-a; local width=direction.Magnitude
    if width<0.1 then return out end
    local radius=width/2; local t=settings.Thickness
    local spring=settings.ArchHeight-radius
    if spring<0 then return out end
    local right=direction.Unit; local up=Vector3.yAxis; local back=right:Cross(up)
    local cf=CFrame.fromMatrix((a+b)*0.5,right,up,back)
    local depth=settings.ArchDepth
    for _,sign in ipairs({-1,1}) do
        spec(out,Vector3.new(t,spring,depth),cf*CFrame.new(sign*(radius+t/2),spring/2,0),"Arch_Post")
    end
    local n=math.floor(settings.ArchSegments)
    local function point(r,angle) return cf:PointToWorldSpace(Vector3.new(r*math.cos(angle),spring+r*math.sin(angle),0)) end
    for i=0,n-1 do
        local x=i*math.pi/n; local y=(i+1)*math.pi/n
        quadPrism(out,point(radius,x),point(radius+t,x),point(radius+t,y),point(radius,y),depth,"Arch_Curve")
    end
    return out
end
local function hitSurface()
    local ray=mouse.UnitRay
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=mode=="Place" and sourceRoots or {}
    return workspace:Raycast(ray.Origin,ray.Direction*100000,params)
end
local function plainBlock(p)
    return p and p.ClassName=="Part" and p.Shape==Enum.PartType.Block
end
local openingTarget=nil
local function openingSpecs(hit,arched)
    local out={}; local p=hit and hit.Instance; openingTarget=nil
    if not plainBlock(p) then return out,"Click a rectangular Part wall (not a mesh, union, or wedge)." end
    if #p:GetChildren()>0 then return out,"Use an undecorated wall. Openings replace the wall with new Parts." end
    if p.Locked then return out,"Unlock the wall before creating an opening." end
    local cf=p.CFrame; local size=p.Size
    if size.Z>size.X then cf=cf*CFrame.Angles(0,math.pi/2,0); size=Vector3.new(size.Z,size.Y,size.X) end
    local w=settings.OpenWidth; local h=settings.OpenHeight; local sill=arched and 0 or settings.Sill
    if arched and h<w/2 then return out,"Arch height must be at least half the opening width." end
    local localHit=cf:PointToObjectSpace(hit.Position)
    local x=snap(localHit.X); local bottom=-size.Y/2+sill; local top=bottom+h
    local left=x-w/2; local right=x+w/2
    if left<=-size.X/2+0.01 or right>=size.X/2-0.01 or sill<0 or top>size.Y/2+0.001 then
        return out,"Opening must fit inside the wall, with wall remaining on both sides."
    end
    spec(out,Vector3.new(left+size.X/2,size.Y,size.Z),cf*CFrame.new((-size.X/2+left)/2,0,0),"Opening_Left",p)
    spec(out,Vector3.new(size.X/2-right,size.Y,size.Z),cf*CFrame.new((right+size.X/2)/2,0,0),"Opening_Right",p)
    if arched then
        local radius=w/2; local spring=bottom+h-radius
        local n=math.floor(settings.ArchSegments)
        for i=0,n-1 do
            local a=math.pi-i*math.pi/n; local b=math.pi-(i+1)*math.pi/n
            local x1=x+radius*math.cos(a); local y1=spring+radius*math.sin(a)
            local x2=x+radius*math.cos(b); local y2=spring+radius*math.sin(b)
            quadPrism(out,cf:PointToWorldSpace(Vector3.new(x1,y1,0)),cf:PointToWorldSpace(Vector3.new(x2,y2,0)),
                cf:PointToWorldSpace(Vector3.new(x2,size.Y/2,0)),cf:PointToWorldSpace(Vector3.new(x1,size.Y/2,0)),size.Z,"Arch_Header",p)
        end
    else
        spec(out,Vector3.new(w,size.Y/2-top,size.Z),cf*CFrame.new(x,(top+size.Y/2)/2,0),"Opening_Header",p)
    end
    if sill>0 then spec(out,Vector3.new(w,sill,size.Z),cf*CFrame.new(x,-size.Y/2+sill/2,0),"Opening_Sill",p) end
    openingTarget=p
    return out,"Click to replace this wall with an opening. Undo restores the original wall."
end
local function extendSpecs(hit,distance)
    local out={}; local p=hit and hit.Instance
    if not plainBlock(p) then return out,"Click a rectangular Part face to add a matching block." end
    local n=p.CFrame:VectorToObjectSpace(hit.Normal)
    local axis=1; if math.abs(n.Y)>math.abs(n.X) then axis=2 end
    if math.abs(n.Z)>math.abs(axis==1 and n.X or n.Y) then axis=3 end
    local unit=axis==1 and Vector3.xAxis or (axis==2 and Vector3.yAxis or Vector3.zAxis)
    local component=axis==1 and n.X or (axis==2 and n.Y or n.Z)
    local old=axis==1 and p.Size.X or (axis==2 and p.Size.Y or p.Size.Z)
    local length=distance or settings.Extend
    local size=axis==1 and Vector3.new(length,p.Size.Y,p.Size.Z) or
        (axis==2 and Vector3.new(p.Size.X,length,p.Size.Z) or Vector3.new(p.Size.X,p.Size.Y,length))
    spec(out,size,p.CFrame*CFrame.new(unit*(component>=0 and 1 or -1)*(old+length)/2),"FaceExtension",p)
    return out,"Click to add a connected block. Length: "..length.." studs."
end
local placementCF=nil
local function placeSpecs(hit)
    local out={}; placementCF=nil
    if not hit or not sourcePivot then return out,"Select an object, then choose Stamp copies." end
    for _,p in ipairs(sourceParts) do if not p:IsDescendantOf(workspace) then return out,"Selection changed or was removed. Choose Stamp copies again." end end
    local rot=CFrame.Angles(0,math.rad(settings.Yaw),0)
    local normal=hit.Normal
    if settings.Align then
        local reference=math.abs(normal.Y)>0.95 and Vector3.xAxis or Vector3.yAxis
        local right=reference:Cross(normal).Unit
        rot=CFrame.fromMatrix(Vector3.zero,right,normal,right:Cross(normal))*rot
    end
    -- Project the rotated bounding box onto the hit normal to seat it flush.
    local radius=(math.abs(normal:Dot(rot.RightVector))*sourceSize.X+
        math.abs(normal:Dot(rot.UpVector))*sourceSize.Y+math.abs(normal:Dot(rot.LookVector))*sourceSize.Z)/2
    local target=CFrame.new(hit.Position+normal*(radius+settings.Offset))*rot
    placementCF=target
    for _,p in ipairs(sourceParts) do spec(out,p.Size,target*sourcePivot:ToObjectSpace(p.CFrame),p.Name) end
    return out,"Click to place a copy flush to this surface. Yaw and offset are in the panel."
end
local function drawGhosts(out)
    previewWire:Clear()
    local count=math.min(#out,600)
    for i=1,count do
        local g=ghosts[i]
        if not g then
            g=Instance.new("BoxHandleAdornment")
            g.Name="Preview"; g.Adornee=workspace.Terrain; g.AlwaysOnTop=false
            g.ZIndex=0; g.Transparency=0.55; g.Color3=accent; g.Parent=ghostFolder
            ghosts[i]=g
        end
        local s=out[i]
        g.Size=s.size; g.CFrame=workspace.Terrain.CFrame:ToObjectSpace(s.cf); g.Visible=s.class~="WedgePart"
        if s.class=="WedgePart" then
            local h=s.size/2
            local vertices={Vector3.new(-h.X,-h.Y,-h.Z),Vector3.new(h.X,-h.Y,-h.Z),Vector3.new(-h.X,-h.Y,h.Z),
                Vector3.new(h.X,-h.Y,h.Z),Vector3.new(-h.X,h.Y,h.Z),Vector3.new(h.X,h.Y,h.Z)}
            for _,edge in ipairs({{1,2},{1,3},{2,4},{3,4},{3,5},{4,6},{5,6},{1,5},{2,6}}) do
                previewWire:AddLine(workspace.Terrain.CFrame:PointToObjectSpace(s.cf:PointToWorldSpace(vertices[edge[1]])),
                    workspace.Terrain.CFrame:PointToObjectSpace(s.cf:PointToWorldSpace(vertices[edge[2]])))
            end
        end
    end
    for i=count+1,#ghosts do ghosts[i].Visible=false end
end
local instructions={
    Wall="Click start and end points. Keep clicking to connect walls. Enter starts a new chain; Esc exits.",
    Corridor="Click a corridor start and end. Continue clicking for connected segments. Joints may overlap at bends.",
    Room="Click two opposite corners. Elevation is the finished floor height.",
    Block="Click two opposite footprint corners. Height comes from the panel.",
    Stairs="Click the first step and the end of the stair run. Length is drawn; Height sets the total rise.",
    Ramp="Click the bottom and top footprint point. Drag distance sets length; Height sets the rise.",
    Arch="Click the two inner edges at ground level. Height is the arch clearance; Depth is the frame depth.",
    ArchOpening="Hover over a plain wall and click to cut an arched doorway. Adjust width/height below.",
    Opening="Click an undecorated rectangular wall. Opening is centered on the cursor horizontally; sill sets its height.",
    Extend="Click a block to select it, then drag a green face handle OUTWARD. Release to add a connected block.",
    Place="Select an object first. Click surfaces to stamp copies. R rotates the preview 90 degrees.",
    Measure="Click two surface points. A distance label stays in the viewport. Esc clears it.",
}
local function activate(name)
    stop()
    if not Run:IsEdit() then say("Stop the playtest before using tools."); return end
    if name=="Place" then
        sourceRoots=selectedRoots(); sourceParts=partsOf(sourceRoots)
        if #sourceParts==0 then say("Select an object first, then choose Stamp copies."); return end
        if #sourceParts>600 then say("Stamp copies supports up to 600 Parts in the source selection."); return end
        for _,root in ipairs(sourceRoots) do if not root.Archivable then say("Enable Archivable on each selected root before copying."); return end end
        sourcePivot,sourceSize=bounds(sourceParts)
    end
    mode=name; plugin:Activate(true)
    configRefresh()
    if name=="Extend" then
        local chosen=Selection:Get()
        if #chosen==1 and plainBlock(chosen[1]) then faceHandles.Adornee=chosen[1]; faceHandles.Visible=true end
    end
    if buttons[name] then buttons[name].BackgroundColor3=Color3.fromRGB(65,112,105) end
    say(instructions[name])
end
-- Reversible colors. Compatibility keys also recover the original standalone plugin.
local ORIGINAL="VluxGreybox_OriginalColor_v1"
local UNION="VluxGreybox_OriginalUsePartColor_v1"
local ACTIVE="VluxGreybox_Enabled_v1"
local colored=setmetatable({}, {__mode="k"})
local candidates={}
local gridObjects={}
local gridDirty=true
local lastGridCamera=nil
local function eligibleGrid(p)
    return (plainBlock(p) or p:IsA("WedgePart")) and p.Transparency<1
end
local function applyPastel(p)
    if not p:IsA("BasePart") then return end
    if typeof(p:GetAttribute(ORIGINAL))~="Color3" then p:SetAttribute(ORIGINAL,p.Color) end
    if p:IsA("PartOperation") then
        if typeof(p:GetAttribute(UNION))~="boolean" then p:SetAttribute(UNION,p.UsePartColor) end
        p.UsePartColor=true
    end
    p.Color=palette[rng:NextInteger(1,#palette)]
    colored[p]=true
end
local function restorePastel(p)
    if not p:IsA("BasePart") then return end
    local color=p:GetAttribute(ORIGINAL)
    if typeof(color)=="Color3" then p.Color=color; p:SetAttribute(ORIGINAL,nil) end
    local union=p:GetAttribute(UNION)
    if p:IsA("PartOperation") and typeof(union)=="boolean" then p.UsePartColor=union; p:SetAttribute(UNION,nil) end
end
local function setPastels(value)
    stop()
    local ok=edit(value and "Show pastel colors" or "Restore original colors",function()
        if value then
            workspace:SetAttribute(ACTIVE,true)
            for _,p in ipairs(workspace:GetDescendants()) do if p:IsA("BasePart") then applyPastel(p) end end
        else
            for _,p in ipairs(game:GetDescendants()) do if p:IsA("BasePart") then restorePastel(p) end end
            for p in pairs(colored) do pcall(restorePastel,p) end
            colored=setmetatable({}, {__mode="k"})
            workspace:SetAttribute(ACTIVE,nil)
        end
    end)
    if ok then paletteOn=value; uiRefresh(); say(value and "Pastel colors ON. Click again to restore originals. Your teammates see these colors too." or "Pastel colors OFF. Original colors restored.") end
end

-- Surface grids are intersections with world X/Y/Z planes, rather than stretched UVs.
-- Only ordinary block/wedge surfaces are overlaid; meshes keep their original shape.
local function partFaces(p)
    local h=p.Size/2
    local function v(x,y,z) return Vector3.new(x*h.X,y*h.Y,z*h.Z) end
    if p:IsA("WedgePart") then
        local a,b,c,d,e,f=v(-1,-1,-1),v(1,-1,-1),v(-1,-1,1),v(1,-1,1),v(-1,1,1),v(1,1,1)
        return {{a,b,d,c},{c,d,f,e},{a,c,e},{b,f,d},{a,e,f,b}}
    end
    return {
        {v(-1,1,-1),v(-1,1,1),v(1,1,1),v(1,1,-1)},
        {v(-1,-1,-1),v(1,-1,-1),v(1,-1,1),v(-1,-1,1)},
        {v(-1,-1,-1),v(-1,-1,1),v(-1,1,1),v(-1,1,-1)},
        {v(1,-1,-1),v(1,1,-1),v(1,1,1),v(1,-1,1)},
        {v(-1,-1,1),v(1,-1,1),v(1,1,1),v(-1,1,1)},
        {v(-1,-1,-1),v(-1,1,-1),v(1,1,-1),v(1,-1,-1)},
    }
end
local function surfaceSegments(p,spacing,camera)
    local lines={}; local limit=360
    for _,face in ipairs(partFaces(p)) do
        local points={}
        for _,v in ipairs(face) do table.insert(points,p.CFrame:PointToWorldSpace(v)) end
        local normal=(points[2]-points[1]):Cross(points[3]-points[1]).Unit
        -- Wedge face winding may differ. Choose an outward normal using the part center.
        local center=Vector3.zero
        for _,v in ipairs(points) do center=center+v/#points end
        if normal:Dot(center-p.Position)<0 then normal=-normal end
        for _,axis in ipairs({"X","Y","Z"}) do
            local lo,hi=math.huge,-math.huge
            for _,v in ipairs(points) do lo=math.min(lo,v[axis]); hi=math.max(hi,v[axis]) end
            if hi-lo>0.001 then
                local firstPlane=math.ceil(lo/spacing); local lastPlane=math.floor(hi/spacing)
                -- Bound the work on unusually large surfaces without changing grid scale.
                local near=math.round(camera[axis]/spacing)
                firstPlane=math.max(firstPlane,near-48); lastPlane=math.min(lastPlane,near+48)
                for plane=firstPlane,lastPlane do
                    local value=plane*spacing; local hits={}
                    local function add(v)
                        for _,h in ipairs(hits) do if (h-v).Magnitude<0.0001 then return end end
                        table.insert(hits,v)
                    end
                    for i=1,#points do
                        local a=points[i]; local b=points[i%#points+1]
                        local da=a[axis]-value; local db=b[axis]-value
                        if math.abs(da)<0.00001 then add(a) end
                        if da*db<0 then add(a+(b-a)*(da/(da-db))) end
                    end
                    if #hits>=2 and (hits[2]-hits[1]).Magnitude>0.002 then
                        table.insert(lines,{p.CFrame:PointToObjectSpace(hits[1]+normal*0.012),p.CFrame:PointToObjectSpace(hits[2]+normal*0.012)})
                        if #lines>=limit then return lines end
                    end
                end
            end
        end
    end
    return lines
end
local function clearSurfaceGrid()
    for _,record in pairs(gridObjects) do record.obj:Destroy() end
    gridObjects={}; lastGridCamera=nil; gridDirty=true
end
local function updateSurfaceGrid()
    if not surfaceGridOn or not Run:IsEdit() then
        if next(gridObjects) then clearSurfaceGrid() end
        return
    end
    local cam=workspace.CurrentCamera; if not cam then return end
    local camera=cam.CFrame.Position
    if not lastGridCamera or (lastGridCamera-camera).Magnitude>16 then gridDirty=true end
    if gridDirty then
        local nearby={}
        for p in pairs(candidates) do
            if p:IsDescendantOf(workspace) and eligibleGrid(p) then
                local distance=(p.Position-camera).Magnitude-p.Size.Magnitude/2
                if distance<512 then table.insert(nearby,{p=p,d=distance}) end
            end
        end
        table.sort(nearby,function(a,b) return a.d<b.d end)
        local keep={}
        for i=1,math.min(#nearby,180) do keep[nearby[i].p]=true end
        for p,r in pairs(gridObjects) do if not keep[p] then r.obj:Destroy(); gridObjects[p]=nil end end
        for p in pairs(keep) do
            if not gridObjects[p] then
                local g=Instance.new("WireframeHandleAdornment")
                g.Name="WorldSurfaceGrid"; g.Adornee=p; g.Color3=Color3.fromRGB(52,62,75)
                g.Transparency=0.22; g.Thickness=1; g.AlwaysOnTop=false; g.Parent=gridFolder
                gridObjects[p]={obj=g}
            else gridObjects[p].cf=nil end
        end
        lastGridCamera=camera; gridDirty=false
    end
    -- Spread rebuilds across frames. Adornee transforms follow movement immediately.
    local budget=8
    for p,r in pairs(gridObjects) do
        if not p:IsDescendantOf(workspace) or not eligibleGrid(p) then
            r.obj:Destroy(); gridObjects[p]=nil; gridDirty=true
        elseif r.cf~=p.CFrame or r.size~=p.Size or r.spacing~=settings.SurfaceGridSize then
            r.obj:Clear()
            for _,line in ipairs(surfaceSegments(p,settings.SurfaceGridSize,camera)) do r.obj:AddLine(line[1],line[2]) end
            r.cf=p.CFrame; r.size=p.Size; r.spacing=settings.SurfaceGridSize
            budget=budget-1; if budget<=0 then break end
        end
    end
end
local function setSurfaceGrid(value)
    surfaceGridOn=value
    if not value then clearSurfaceGrid() else gridDirty=true end
    uiRefresh()
    say(value and "Surface grid ON: world-aligned lines on nearby block and wedge Parts. Only you see this overlay." or "Surface grid OFF. No materials were changed.")
end

local hud=make("ScreenGui",{Name="VluxBlockout_Readout",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=1000,Enabled=false},CoreGui)
worldLabel=hud
local floating=make("TextLabel",{Size=UDim2.fromOffset(210,46),AnchorPoint=Vector2.new(0.5,1),BackgroundColor3=Color3.fromRGB(23,36,40),
    BackgroundTransparency=0.08,BorderSizePixel=0,TextColor3=Color3.fromRGB(187,244,224),TextSize=16,Font=Enum.Font.GothamBold,TextWrapped=true},hud)
make("UICorner",{CornerRadius=UDim.new(0,7)},floating)
make("UIStroke",{Color=accent,Thickness=1},floating)
local readoutPosition=nil
local function readout(position,text)
    readoutPosition=position; floating.Text=text; hud.Enabled=true
end
local function positionReadout()
    if not hud.Enabled or not readoutPosition then return end
    local camera=workspace.CurrentCamera
    if camera then
        local p,onScreen=camera:WorldToViewportPoint(readoutPosition)
        floating.Visible=onScreen and p.Z>0
        floating.Position=UDim2.fromOffset(p.X,p.Y-16)
    end
end
local measureLine=Instance.new("WireframeHandleAdornment")
measureLine.Name="Measurement"; measureLine.Adornee=workspace.Terrain; measureLine.Color3=accent
measureLine.AlwaysOnTop=true; measureLine.Thickness=2; measureLine.Parent=ghostFolder
local measurement=nil
local function drawMeasurement(a,b)
    measureLine:Clear()
    local base=workspace.Terrain.CFrame
    measureLine:AddLine(base:PointToObjectSpace(a),base:PointToObjectSpace(b))
    for _,point in ipairs({a,b}) do
        for _,axis in ipairs({Vector3.xAxis,Vector3.yAxis,Vector3.zAxis}) do
            measureLine:AddLine(base:PointToObjectSpace(point-axis*0.18),base:PointToObjectSpace(point+axis*0.18))
        end
    end
    local distance=(b-a).Magnitude
    readout((a+b)*0.5,string.format("%.2f studs",distance))
end

for _,p in ipairs(workspace:GetDescendants()) do
    if p:IsA("BasePart") then
        candidates[p]=true
        if typeof(p:GetAttribute(ORIGINAL))=="Color3" then paletteOn=true; colored[p]=true end
    end
end
if workspace:GetAttribute(ACTIVE)==true then paletteOn=true end
connections[#connections+1]=workspace.DescendantAdded:Connect(function(p)
    if p:IsA("BasePart") then
        candidates[p]=true; gridDirty=true
        task.defer(function()
            if not Run:IsEdit() or not p:IsDescendantOf(workspace) then return end
            if paletteOn then applyPastel(p) else restorePastel(p) end
        end)
    end
end)
connections[#connections+1]=workspace.DescendantRemoving:Connect(function(p)
    if candidates[p] then candidates[p]=nil; gridDirty=true end
end)
local function syncColors()
    paletteOn=workspace:GetAttribute(ACTIVE)==true
    if not paletteOn then
        for p in pairs(candidates) do if typeof(p:GetAttribute(ORIGINAL))=="Color3" then paletteOn=true; break end end
    end
    uiRefresh(); gridDirty=true
end
connections[#connections+1]=History.OnUndo:Connect(syncColors)
connections[#connections+1]=History.OnRedo:Connect(syncColors)

resetExtra=function()
    measurement=nil; measureLine:Clear()
end
local function update()
    if not mode or not Run:IsEdit() then clearGhosts(); previewValid=false; return end
    if extendDrag then return end
    local out={}; local message=nil
    planeGrid:Clear()
    if mode=="Extend" then
        clearGhosts()
        if faceHandles.Adornee then
            local p=faceHandles.Adornee
            if not p:IsDescendantOf(workspace) then faceHandles.Adornee=nil; faceHandles.Visible=false end
        end
        return
    elseif mode=="Opening" or mode=="ArchOpening" or mode=="Place" then
        local hit=hitSurface()
        if mode=="Place" then out,message=placeSpecs(hit)
        else out,message=openingSpecs(hit,mode=="ArchOpening") end
    elseif mode=="Measure" then
        local hit=hitSurface()
        current=hit and hit.Position or horizontalPoint(settings.Elevation)
        if current and first then
            drawMeasurement(first,current)
            message="Click to keep this measurement. The number stays in the viewport."
        elseif measurement then
            drawMeasurement(measurement.a,measurement.b)
        end
    else
        current=horizontalPoint(first and first.Y or settings.Elevation)
        if current and settings.ShowGrid then
            local grid=math.max(0.05,settings.Grid)
            local origin=Vector3.new(math.round(current.X/grid)*grid,current.Y+0.02,math.round(current.Z/grid)*grid)
            local radius=grid*15
            for i=-15,15 do
                local x=origin.X+i*grid; local z=origin.Z+i*grid
                planeGrid:AddLine(Vector3.new(x,origin.Y,origin.Z-radius),Vector3.new(x,origin.Y,origin.Z+radius))
                planeGrid:AddLine(Vector3.new(origin.X-radius,origin.Y,z),Vector3.new(origin.X+radius,origin.Y,z))
            end
        end
        if current and first then
            local b=current
            if Input:IsKeyDown(Enum.KeyCode.LeftShift) or Input:IsKeyDown(Enum.KeyCode.RightShift) then
                local d=b-first
                b=math.abs(d.X)>=math.abs(d.Z) and Vector3.new(b.X,first.Y,first.Z) or Vector3.new(first.X,first.Y,b.Z)
                current=b
            end
            if mode=="Room" then out=roomSpecs(first,b)
            elseif mode=="Block" then out=blockSpecs(first,b)
            elseif mode=="Wall" or mode=="Corridor" then out=pathSpecs(first,b,mode=="Corridor")
            elseif mode=="Stairs" or mode=="Ramp" then out=stairSpecs(first,b,mode=="Ramp")
            elseif mode=="Arch" then out=archSpecs(first,b) end
            local d=b-first
            if mode=="Arch" and #out==0 then
                message="Arch height must be at least half the drawn span. Increase clearance height or draw a narrower arch."
            else
                message="Click to build. Hold Shift for a straight direction; Esc cancels."
                local text
                if mode=="Room" or mode=="Block" then text=string.format("%.1f × %.1f studs",math.abs(d.X),math.abs(d.Z))
                elseif mode=="Arch" then text=string.format("Span %.1f  |  Height %.1f",d.Magnitude,settings.ArchHeight)
                elseif mode=="Stairs" then text=string.format("Run %.1f  |  Rise %.1f",d.Magnitude,settings.StairHeight)
                elseif mode=="Ramp" then text=string.format("Run %.1f  |  Rise %.1f",d.Magnitude,settings.RampHeight)
                else text=string.format("%.1f studs",d.Magnitude) end
                readout((first+b)*0.5,text)
            end
        elseif current then
            spec(out,Vector3.new(0.25,0.15,0.25),CFrame.new(current),"Start")
        end
    end
    previewSpecs=out
    previewValid=#out>0 and (first~=nil or mode=="Opening" or mode=="ArchOpening" or mode=="Place")
    drawGhosts(out)
    if message then say(message) end
end

local function cloneRoots(roots,transform,parent)
    local copies={}
    for _,root in ipairs(roots) do
        local copy=root:Clone()
        assert(copy,"A selected object cannot be cloned. Check Archivable.")
        copy:PivotTo(transform(root:GetPivot()))
        copy.Parent=parent or root.Parent
        table.insert(copies,copy)
    end
    return copies
end
local function finishExtension()
    local drag=extendDrag
    if not drag then return end
    extendDrag=nil
    if drag.length and drag.length>=math.max(0.05,settings.Grid) and drag.source.Parent then
        local out=extendSpecs({Instance=drag.source,Normal=drag.normal},drag.length)
        local built
        if edit("Drag face extension",function() built=materialize(out,"Face_Extension") end) then
            local p=built:FindFirstChildWhichIsA("BasePart")
            faceHandles.Adornee=p; faceHandles.Visible=p~=nil
            say("Added "..drag.length.." studs. Drag another handle to keep building.")
        end
    else say("Drag a green face handle outward to create an extension.") end
    clearGhosts(); hud.Enabled=false
end
connections[#connections+1]=faceHandles.MouseEnter:Connect(function() extendHover=true end)
connections[#connections+1]=faceHandles.MouseLeave:Connect(function() extendHover=false end)
connections[#connections+1]=faceHandles.MouseButton1Down:Connect(function(face)
    if mode~="Extend" or not faceHandles.Adornee or not Run:IsEdit() then return end
    local p=faceHandles.Adornee
    extendDrag={source=p,normal=p.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)),length=0}
end)
connections[#connections+1]=faceHandles.MouseDrag:Connect(function(face,distance)
    if not extendDrag then return end
    local length=math.clamp(snap(distance),0,2048)
    extendDrag.length=length
    if length>0.001 then
        local out=extendSpecs({Instance=extendDrag.source,Normal=extendDrag.normal},length)
        drawGhosts(out)
        readout(out[1].cf.Position,string.format("Extend %.2f studs",length))
        say("Release to add "..length.." studs. Esc cancels this extension.")
    else clearGhosts(); hud.Enabled=false end
end)
connections[#connections+1]=faceHandles.MouseButton1Up:Connect(finishExtension)
connections[#connections+1]=mouse.Button1Down:Connect(function()
    if not mode or not Run:IsEdit() or extendDrag or extendHover and mode=="Extend" then return end
    if mode=="Extend" then
        local hit=hitSurface()
        if hit and plainBlock(hit.Instance) and not hit.Instance.Locked then
            faceHandles.Adornee=hit.Instance; faceHandles.Visible=true
            say("Drag a green face handle outward. Release to add the new block.")
        else say("Click an unlocked rectangular block, then drag one of its green handles.") end
        return
    end
    local ok,err=pcall(update)
    if not ok then say(tostring(err)); return end
    if mode=="Opening" or mode=="ArchOpening" then
        if not previewValid then return end
        local target=openingTarget
        edit(mode=="ArchOpening" and "Create arched doorway" or "Create opening",function()
            materialize(previewSpecs,mode=="ArchOpening" and "Arched_Doorway" or "Wall_Opening")
            assert(target and target.Parent,"Wall no longer exists")
            target:Destroy()
        end)
    elseif mode=="Place" then
        if not previewValid or not placementCF then return end
        local target=placementCF
        edit("Stamp copy",function()
            local copies=cloneRoots(sourceRoots,function(cf) return target*sourcePivot:ToObjectSpace(cf) end)
            Selection:Set(copies)
        end)
    elseif mode=="Measure" and current then
        if not first then
            measurement=nil; first=current; measureLine:Clear()
            say("Now click the second surface point. Distance is shown beside the line.")
        else
            measurement={a=first,b=current}; drawMeasurement(first,current)
            say(string.format("%.2f studs. Click to start another measurement; Esc clears it.",(current-first).Magnitude))
            first=nil
        end
    elseif current then
        if not first then first=current; say("Move to the other point. Click to build.")
        elseif previewValid then
            local keep=mode=="Wall" or mode=="Corridor"
            local nextPoint=current
            if edit("Build "..mode,function() materialize(previewSpecs,"Vlux_"..mode) end) then
                first=keep and nextPoint or nil; clearGhosts(); hud.Enabled=false
                say(keep and "Click the next endpoint, or Start new chain to begin elsewhere." or instructions[mode])
            end
        end
    end
end)
connections[#connections+1]=Input.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 and extendDrag then task.defer(finishExtension) end
end)
connections[#connections+1]=Input.InputBegan:Connect(function(input,processed)
    if not mode or Input:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.Escape then stop(); say("Tool stopped. Your completed builds stay in the map.")
    elseif input.KeyCode==Enum.KeyCode.R and mode=="Place" then
        settings.Yaw=(settings.Yaw+90)%360
        if fieldBoxes.Yaw then fieldBoxes.Yaw.Text=tostring(settings.Yaw) end
        save()
    elseif input.KeyCode==Enum.KeyCode.Return or input.KeyCode==Enum.KeyCode.KeypadEnter then
        resetPoint(); say(instructions[mode])
    elseif input.KeyCode==Enum.KeyCode.RightBracket or input.KeyCode==Enum.KeyCode.LeftBracket then
        local key=mode=="Arch" and "ArchHeight" or mode=="Stairs" and "StairHeight" or mode=="Ramp" and "RampHeight" or "Height"
        settings[key]=math.clamp(settings[key]+(input.KeyCode==Enum.KeyCode.RightBracket and 1 or -1)*settings.Grid,0.1,2048)
        if fieldBoxes[key] then fieldBoxes[key].Text=tostring(settings[key]) end
        save()
    end
end)
connections[#connections+1]=plugin.Deactivation:Connect(function()
    mode=nil; extendDrag=nil; extendHover=false; faceHandles.Visible=false; faceHandles.Adornee=nil; resetPoint()
    for _,b in pairs(buttons) do b.BackgroundColor3=Color3.fromRGB(46,51,64) end
    configRefresh()
end)
local elapsed=0
connections[#connections+1]=Run.Heartbeat:Connect(function(dt)
    positionReadout()
    elapsed=elapsed+dt
    if elapsed>=0.05 then
        elapsed=0
        if not Run:IsEdit() then
            if mode then stop() end
            if next(gridObjects) then clearSurfaceGrid() end
            return
        end
        if mode then
            local ok,err=pcall(update)
            if not ok then stop(); say("Preview stopped: "..tostring(err)); warn(err) end
        end
        local ok,err=pcall(updateSurfaceGrid)
        if not ok then surfaceGridOn=false; clearSurfaceGrid(); uiRefresh(); say("Surface grid stopped: "..tostring(err)) end
    end
end)

-- Clean panel: only settings relevant to the current tool are visible.
local page="Build"
local advanced=false
local uiRows={}
local tabButtons={}
local function register(r,which,modes,isAdvanced,condition)
    table.insert(uiRows,{row=r,page=which,modes=modes,advanced=isAdvanced,condition=condition})
end
configRefresh=function()
    for _,r in ipairs(uiRows) do
        local visible=not r.page or r.page==page
        if r.modes then visible=visible and r.modes[mode or "None"]==true end
        if r.advanced then visible=visible and advanced end
        if r.condition then visible=visible and r.condition() end
        r.row.Visible=visible
    end
    for title,b in pairs(tabButtons) do b.BackgroundColor3=title==page and Color3.fromRGB(65,112,105) or Color3.fromRGB(46,51,64) end
end
local function section(text,which,modes,isAdvanced,condition)
    local l=label(text,24,accent); register(l.Parent,which,modes,isAdvanced,condition)
end
local function hint(text,height,which,modes,isAdvanced,condition)
    local l=label(text,height or 44); register(l.Parent,which,modes,isAdvanced,condition)
end
local function actionRow(items,which,modes,isAdvanced,condition)
    local r=row(34); local n=#items; local result={}
    register(r,which,modes,isAdvanced,condition)
    for i,item in ipairs(items) do
        local b=make("TextButton",{Size=UDim2.new(1/n,-4,1,0),Position=UDim2.new((i-1)/n,0,0,0),
            BackgroundColor3=Color3.fromRGB(46,51,64),BorderSizePixel=0,Text=item[1],TextWrapped=true,
            TextColor3=textColor,Font=Enum.Font.Gotham,TextSize=12,AutoButtonColor=true},r)
        make("UICorner",{CornerRadius=UDim.new(0,5)},b)
        b.MouseButton1Click:Connect(function()
            local ok,err=pcall(item[2])
            if not ok then say("Action stopped: "..tostring(err)); warn(err) end
        end)
        if item[3] then buttons[item[3]]=b end
        table.insert(result,b)
    end
    return result
end
local displayButtons=actionRow({{"Pastel colors: OFF",function() setPastels(not paletteOn) end},
    {"Surface grid: OFF",function() setSurfaceGrid(not surfaceGridOn) end}})
uiRefresh=function()
    displayButtons[1].Text="Pastel colors: "..(paletteOn and "ON" or "OFF")
    displayButtons[2].Text="Surface grid: "..(surfaceGridOn and "ON" or "OFF")
    for i,on in ipairs({paletteOn,surfaceGridOn}) do
        displayButtons[i].BackgroundColor3=on and Color3.fromRGB(65,112,105) or Color3.fromRGB(46,51,64)
    end
    configRefresh()
end
local function numeric(key,title,min,max,step,which,modes,isAdvanced,condition)
    local r=row(30); register(r,which,modes,isAdvanced,condition)
    make("TextLabel",{Size=UDim2.new(0.49,0,1,0),BackgroundTransparency=1,Text=title,
        TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.Gotham,TextSize=12,TextColor3=textColor},r)
    local box=make("TextBox",{Size=UDim2.new(0.27,-4,1,0),Position=UDim2.fromScale(0.59,0),
        BackgroundColor3=Color3.fromRGB(39,44,55),BorderSizePixel=0,Text=tostring(settings[key]),
        TextColor3=textColor,Font=Enum.Font.Gotham,TextSize=12,ClearTextOnFocus=false},r)
    fieldBoxes[key]=box
    local function apply(value)
        if value and value==value and math.abs(value)<math.huge then
            settings[key]=math.clamp(value,min,max)
            if key=="Copies" or key=="ArchSegments" then settings[key]=math.floor(settings[key]) end
            save(); if key=="SurfaceGridSize" then gridDirty=true end
        end
        box.Text=tostring(settings[key])
    end
    box.FocusLost:Connect(function() apply(tonumber(box.Text)) end)
    for _,pair in ipairs({{-1,0.49,"−"},{1,0.86,"+"}}) do
        local b=make("TextButton",{Size=UDim2.new(0.10,-2,1,0),Position=UDim2.fromScale(pair[2],0),
            BackgroundColor3=Color3.fromRGB(46,51,64),BorderSizePixel=0,Text=pair[3],TextColor3=accent,
            Font=Enum.Font.GothamBold,TextSize=18},r)
        b.MouseButton1Click:Connect(function() apply(settings[key]+pair[1]*(step or settings.Grid)) end)
    end
end
numeric("SurfaceGridSize","Surface grid size",0.5,128,1,nil,nil,false,function() return surfaceGridOn end)
local tabs=actionRow({{"Build",function() stop(); page="Build"; configRefresh(); say("Choose a building tool.") end},
    {"Arrange",function() stop(); page="Arrange"; configRefresh(); say("Select objects, then choose a layout action.") end},
    {"Help",function() stop(); page="Help"; configRefresh() end}})
tabButtons={Build=tabs[1],Arrange=tabs[2],Help=tabs[3]}
local function tools(pairsList)
    local items={}
    for _,pair in ipairs(pairsList) do
        local name=pair[1]
        table.insert(items,{pair[2],function() activate(name) end,name})
    end
    actionRow(items,"Build")
end
tools({{"Wall","Draw walls"},{"Corridor","Draw corridor"}})
tools({{"Room","Draw room"},{"Block","Draw block"}})
tools({{"Stairs","Draw stairs"},{"Ramp","Draw ramp"}})
tools({{"Arch","Arch frame"},{"ArchOpening","Arched doorway"}})
tools({{"Opening","Door / window"},{"Extend","Drag face extend"}})
tools({{"Place","Stamp copies"},{"Measure","Measure distance"}})
actionRow({{"Stop tool (Esc)",function() stop(); say("Tool stopped. Choose another tool whenever you are ready.") end}},"Build",nil,false,function() return mode~=nil end)
actionRow({{"Start new chain",function() resetPoint(); say(instructions[mode] or "Choose a drawing tool first.") end}},"Build",{Wall=true,Corridor=true})
section("TOOL SETTINGS","Build",nil,false,function() return mode~=nil end)
local drawModes={Wall=true,Corridor=true,Room=true,Block=true,Stairs=true,Ramp=true,Arch=true}
local heightModes={Wall=true,Corridor=true,Room=true,Block=true}
numeric("Grid","Snap increment",0.05,128,0.5,"Build",drawModes)
numeric("Elevation","Floor level (Y)",-10000,10000,nil,"Build",drawModes)
actionRow({{"Use selected floor height",function()
    local parts=partsOf(selectedRoots())
    if #parts==0 then say("Select a floor first, then click Use selected floor height."); return end
    local cf,size=bounds(parts); settings.Elevation=cf.Y+size.Y/2
    fieldBoxes.Elevation.Text=tostring(settings.Elevation); resetPoint(); save()
    say("Drawing floor is now Y = "..settings.Elevation..".")
end}},"Build",drawModes)
numeric("Height","Height",0.1,2048,nil,"Build",heightModes)
numeric("Thickness","Wall / frame thickness",0.05,128,nil,"Build",{Wall=true,Corridor=true,Room=true,Arch=true})
numeric("Width","Clear width",0.1,1024,nil,"Build",{Corridor=true,Stairs=true,Ramp=true})
numeric("StairHeight","Total stair rise",0.1,1024,nil,"Build",{Stairs=true})
numeric("RampHeight","Ramp rise",0.1,1024,nil,"Build",{Ramp=true})
numeric("ArchHeight","Clearance at arch top",0.1,1024,nil,"Build",{Arch=true})
numeric("ArchDepth","Frame depth",0.1,256,nil,"Build",{Arch=true})
numeric("OpenWidth","Opening width",0.1,1024,nil,"Build",{Opening=true,ArchOpening=true})
numeric("OpenHeight","Opening height",0.1,1024,nil,"Build",{Opening=true,ArchOpening=true})
numeric("Sill","Bottom above floor",0,1024,nil,"Build",{Opening=true})
actionRow({{"Door preset",function()
    settings.OpenWidth=4;settings.OpenHeight=8;settings.Sill=0
    for _,k in ipairs({"OpenWidth","OpenHeight","Sill"}) do fieldBoxes[k].Text=tostring(settings[k]) end
    save();say("Door: 4 studs wide, 8 high, starts at the wall bottom.")
end},{"Window preset",function()
    settings.OpenWidth=5;settings.OpenHeight=4;settings.Sill=3
    for _,k in ipairs({"OpenWidth","OpenHeight","Sill"}) do fieldBoxes[k].Text=tostring(settings[k]) end
    save();say("Window: 5 studs wide, 4 high, 3 studs above the wall bottom.")
end}},"Build",{Opening=true})
numeric("Yaw","Copy rotation",-360,360,90,"Build",{Place=true})
hint("Select a source object before Stamp copies. Click a surface to place copies; R rotates by 90°. The original stays where it is.",60,"Build",{Place=true})
hint("Click a block, then drag a GREEN HANDLE outward. Release to build. The next block is selected automatically so you can keep extending.",60,"Build",{Extend=true})
hint("Click two surface points. A line and a STUD DISTANCE stay in the viewport. Click again for a new reading. Esc clears it.",60,"Build",{Measure=true})
actionRow({{"More options ▾",function() advanced=not advanced; configRefresh() end}},"Build",nil,false,function() return mode~=nil end)
numeric("Run","Approx. step depth",0.1,64,0.25,"Build",{Stairs=true},true)
numeric("Landing","Top landing depth",0,256,nil,"Build",{Stairs=true,Ramp=true},true)
numeric("Floor","Floor / ceiling thickness",0.05,128,0.25,"Build",{Room=true,Corridor=true},true)
numeric("ArchSegments","Arch smoothness",4,48,4,"Build",{Arch=true,ArchOpening=true},true)
numeric("Offset","Surface gap",-256,256,0.25,"Build",{Place=true},true)
local ceilingButton=actionRow({{"Ceiling",function() settings.Roof=not settings.Roof; save(); uiRefresh() end}},"Build",{Room=true,Corridor=true})[1]
local alignButton=actionRow({{"Align copy to surface",function() settings.Align=not settings.Align; save(); uiRefresh() end}},"Build",{Place=true},true)[1]
local oldRefresh=uiRefresh
uiRefresh=function()
    ceilingButton.Text="Ceiling: "..(settings.Roof and "ON" or "OFF")
    alignButton.Text="Tilt copy to surface: "..(settings.Align and "ON" or "OFF")
    oldRefresh()
end

section("REPEAT SELECTED OBJECTS","Arrange")
numeric("Copies","Extra copies",1,100,1,"Arrange")
numeric("DX","X spacing",-2048,2048,nil,"Arrange")
numeric("DY","Y spacing",-2048,2048,nil,"Arrange")
numeric("DZ","Z spacing",-2048,2048,nil,"Arrange")
actionRow({{"Make repeated copies",function()
    stop(); local roots=selectedRoots(); local parts=partsOf(roots)
    if #parts==0 then say("Select Parts or Models first."); return end
    if #parts*settings.Copies>10000 then say("Limit: 10,000 copied Parts per action."); return end
    for _,r in ipairs(roots) do if not r.Archivable then say("Enable Archivable on selected objects first."); return end end
    local step=Vector3.new(settings.DX,settings.DY,settings.DZ)
    if step.Magnitude<0.001 then say("Give the copies some X, Y, or Z spacing first."); return end
    if edit("Repeat objects",function()
        local all={}
        for i=1,settings.Copies do
            for _,copy in ipairs(cloneRoots(roots,function(cf) return cf+step*i end)) do table.insert(all,copy) end
        end
        Selection:Set(all)
    end) then say("Copies created. Ctrl+Z undoes the whole set.") end
end}},"Arrange")
section("MIRROR SELECTED LAYOUT","Arrange")
hint("Reflects positions across world X=0, Y=0, or Z=0. Asymmetric mesh geometry keeps its original shape.",48,"Arrange")
local axisButton
local axisButtons=actionRow({{"Axis: "..settings.Axis,function()
    settings.Axis=settings.Axis=="X" and "Y" or settings.Axis=="Y" and "Z" or "X"
    axisButton.Text="Axis: "..settings.Axis; save()
end},{"Make mirror copy",function()
    stop(); local roots=selectedRoots(); if #partsOf(roots)==0 then say("Select Parts or Models first."); return end
    for _,r in ipairs(roots) do if not r.Archivable then say("Enable Archivable on selected objects first."); return end end
    local axis=settings.Axis
    local function reflect(v) return Vector3.new(axis=="X" and -v.X or v.X,axis=="Y" and -v.Y or v.Y,axis=="Z" and -v.Z or v.Z) end
    local function reflectCF(cf)
        local up=reflect(cf.UpVector);local back=reflect(-cf.LookVector)
        return CFrame.fromMatrix(reflect(cf.Position),up:Cross(back),up,back)
    end
    if edit("Mirror objects",function()
        local copies=cloneRoots(roots,function(cf) return cf end)
        for _,copy in ipairs(copies) do
            local pivot=copy:GetPivot()
            for _,part in ipairs(partsOf({copy})) do part.CFrame=reflectCF(part.CFrame) end
            if copy:IsA("Model") and not copy.PrimaryPart then copy.WorldPivot=reflectCF(pivot) end
        end
        Selection:Set(copies)
    end) then say("Mirrored across world "..axis.." = 0.") end
end}},"Arrange")
axisButton=axisButtons[1]
section("QUICK ACTIONS","Arrange")
actionRow({{"Snap selection",function()
    local roots=selectedRoots(); if #roots==0 then say("Select objects first."); return end
    edit("Snap objects",function()
        for _,r in ipairs(roots) do local cf=r:GetPivot();local p=cf.Position
            r:PivotTo(CFrame.new(snap(p.X),snap(p.Y),snap(p.Z))*cf.Rotation) end
    end)
end},{"Show dimensions",function()
    local parts=partsOf(selectedRoots()); if #parts==0 then say("Select objects first.");return end
    local cf,size=bounds(parts)
    readout(cf.Position+Vector3.new(0,size.Y/2,0),string.format("X %.1f  Y %.1f  Z %.1f",size.X,size.Y,size.Z))
    say(string.format("%.2f × %.2f × %.2f studs. X / Y / Z.",size.X,size.Y,size.Z))
end}},"Arrange")
actionRow({{"Anchor selection",function()
    local parts=partsOf(selectedRoots());if #parts==0 then say("Select objects first.");return end
    edit("Anchor objects",function() for _,p in ipairs(parts) do p.Anchored=true end end)
end}},"Arrange")
section("QUICK GUIDE","Help")
hint("Draw tools: click the first point, move the mouse, then click again. The preview shows dimensions before you build.",58,"Help")
hint("Walls and corridors continue from the last point. Start new chain begins somewhere else. Stop tool returns to normal Studio selection.",62,"Help")
hint("Height buttons − / + work immediately. You can also press [ or ] while drawing. Hold Shift to keep a straight direction.",58,"Help")
hint("Arch frame: draw the inside span across the ground. Arched doorway: click an existing plain wall to cut a curved opening. Increase More options → Arch smoothness for a finer curve.",90,"Help")
hint("Pastel colors is a reversible whole-map toggle. It changes actual colors, visible to your team; switch it OFF before publishing. Originals survive a saved crash.",78,"Help")
hint("Surface grid is a local, world-aligned overlay on nearby rectangular Parts and WedgeParts. Spacing stays fixed as objects scale. Meshes, spheres, and cylinders are skipped. Up to 180 nearby Parts are shown at once.",98,"Help")
hint("Grid and previews are editor-only and disappear on restart. Pastel backups use the old Greybox Colors keys so saved colors can still be restored. Remove that standalone plugin when using this integrated toggle.",94,"Help")
hint("Door and arch openings replace a childless rectangular wall with separate Parts. Existing code references to that wall need updating. Undo restores the original.",74,"Help")
hint("All completed builds support Studio Undo/Redo. Save your project normally. The plugin contains no runtime scripts for your game.",62,"Help")
toggle.Click:Connect(function() widget.Enabled=not widget.Enabled end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
    toggle:SetActive(widget.Enabled)
    if not widget.Enabled then stop() end
end)
toggle:SetActive(widget.Enabled)
uiRefresh(); configRefresh()
connections[#connections+1]=plugin.Unloading:Connect(function()
    stop();save()
    for _,c in ipairs(connections) do c:Disconnect() end
    if Run:IsEdit() and paletteOn then
        -- Normal unloading restores display colors; crash recovery uses saved attributes.
        local id=History:TryBeginRecording("VluxRestoreColors","Restore original colors")
        if id then
            local ok=pcall(function()
                for _,p in ipairs(game:GetDescendants()) do if p:IsA("BasePart") then restorePastel(p) end end
                workspace:SetAttribute(ACTIVE,nil)
            end)
            History:FinishRecording(id,ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
        end
    end
    ghostFolder:Destroy();gridFolder:Destroy();hud:Destroy()
end)

