-- SkeetCCUI Library
-- Converted from mangosense by assistant
-- Upload this to your GitHub repo as SkeetCCUI.lua

local SkeetCCUI = {}
SkeetCCUI.__index = SkeetCCUI

-- ============================================================
-- SERVICES & LOCALS
-- ============================================================
local uis     = game:GetService("UserInputService")
local tws     = game:GetService("TweenService")
local plrs    = game:GetService("Players")
local ts      = game:GetService("TextService")
local hs      = game:GetService("HttpService")
local rs      = game:GetService("RunService")
local cg      = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")

local lplr    = plrs.LocalPlayer
local mouse   = lplr:GetMouse()
local camera  = workspace.CurrentCamera

local clamp       = math.clamp
local floor       = math.floor
local udim2new    = UDim2.new
local vector2new  = Vector2.new
local colorfromrgb= Color3.fromRGB
local newtweeninfo= TweenInfo.new
local abs         = math.abs
local round_fn    = function(n,d) local m=10^(d or 0) return floor(n*m+0.5)/m end
local spawn_fn    = task.spawn
local delay_fn    = task.delay
local wait_fn     = task.wait

-- ============================================================
-- FONT SETUP
-- ============================================================
local menu_font, menu_font_bold
do
    local ok = pcall(function()
        local path = hs:GenerateGUID(false)..".txt"
        -- (trimmed font data for brevity - uses SourceSansPro as fallback)
    end)
    menu_font      = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    menu_font_bold = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold,    Enum.FontStyle.Normal)
end

-- ============================================================
-- SIGNAL CLASS
-- ============================================================
local Signal = {}
Signal.__index = Signal
function Signal.new()
    return setmetatable({_cbs={}}, Signal)
end
function Signal:Fire(...)
    for _,cb in self._cbs do spawn_fn(cb,...) end
end
function Signal:Connect(cb)
    local idx = #self._cbs+1
    self._cbs[idx] = cb
    return {Disconnect=function()
        table.remove(self._cbs, idx)
    end}
end

-- ============================================================
-- UTILITY
-- ============================================================
local utility = {connections={}, is_dragging_blocked=false}

function utility.newObject(class, props)
    local obj = Instance.new(class)
    for k,v in props do obj[k]=v end
    obj.Name = props.Name or ""
    return obj
end

function utility.newConnection(signal, cb)
    local conn = signal:Connect(cb)
    utility.connections[#utility.connections+1] = conn
    return conn
end

function utility.tween(obj, info, props)
    tws:Create(obj, info, props):Play()
end

function utility.setDraggable(object)
    local drag_conn, stop_conn
    utility.newConnection(object.InputBegan, function(input, gpe)
        if gpe then return end
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or
            input.UserInputType == Enum.UserInputType.Touch) and
            not utility.is_dragging_blocked then
            local sx = object.Position.X.Scale
            local sy = object.Position.Y.Scale
            local ms = uis:GetMouseLocation() / camera.ViewportSize
            local mx, my = ms.X, ms.Y
            drag_conn = utility.newConnection(mouse.Move, function()
                local mp = uis:GetMouseLocation() / camera.ViewportSize
                object.Position = UDim2.new(sx-(mx-mp.X),0, sy-(my-mp.Y),0)
            end)
            stop_conn = utility.newConnection(uis.InputEnded, function(inp,_)
                if inp.UserInputType==Enum.UserInputType.MouseButton1 or
                   inp.UserInputType==Enum.UserInputType.Touch then
                    stop_conn:Disconnect()
                    drag_conn:Disconnect()
                end
            end)
        end
    end)
end

function utility.isInFrame(obj, pos)
    local ap = obj.AbsolutePosition
    local as = obj.AbsoluteSize
    return ap.Y<=pos.Y and pos.Y<=ap.Y+as.Y and ap.X<=pos.X and pos.X<=ap.X+as.X
end

local tween_info = newtweeninfo(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

-- ============================================================
-- MENU STATE
-- ============================================================
local menu = {
    flags           = {},
    is_open         = true,
    busy            = false,
    accent_color    = colorfromrgb(153, 196, 39),
    animation_speed = 0.15,
    toggle          = "DELETE",
    keybinds        = {},
    active_colorpicker = nil,
    active_keybind     = nil,
    on_closing      = Signal.new(),
    on_opening      = Signal.new(),
    on_load         = Signal.new(),
    on_accent_change= Signal.new(),
}
local flags = menu.flags

-- ============================================================
-- CONFIG HELPERS
-- ============================================================
local config_location = "SkeetCCUI"

local function ensureFolders()
    for _, f in {config_location, config_location.."/configs", config_location.."/addons"} do
        if not isfolder(f) then makefolder(f) end
    end
end
pcall(ensureFolders)

function SkeetCCUI.saveConfig(name)
    local copy = {}
    for k,v in pairs(flags) do
        if typeof(v)=="Color3" then
            copy[k]={round_fn(v.R*255),round_fn(v.G*255),round_fn(v.B*255)}
        elseif typeof(v)=="table" and v.key then
            local c2={}
            for kk,vv in pairs(v) do c2[kk]=vv end
            c2.key = v.key.Name
            copy[k]=c2
        else
            copy[k]=v
        end
    end
    writefile(config_location.."/configs/"..name..".cfg", hs:JSONEncode(copy))
end

function SkeetCCUI.loadConfig(name)
    if not isfile(config_location.."/configs/"..name..".cfg") then return end
    local raw = readfile(config_location.."/configs/"..name..".cfg")
    local cfg = hs:JSONDecode(raw)
    if not cfg then return end
    for k,v in pairs(cfg) do
        if typeof(v)=="table" then
            if typeof(v[1])=="number" and v[3] then
                cfg[k]=colorfromrgb(v[1],v[2],v[3])
            elseif v.key then
                cfg[k].key = v.key:find("Mouse") and Enum.UserInputType[v.key] or Enum.KeyCode[v.key]
            end
        end
        flags[k]=cfg[k]
    end
    menu.on_load:Fire()
end

function SkeetCCUI.getConfigList()
    local list={}
    for _,f in listfiles(config_location.."/configs/") do
        list[#list+1]=string.sub(f,#(config_location.."/configs/")+1,#f-4)
    end
    return list
end

-- ============================================================
-- SCREEN GUI
-- ============================================================
local _screenGui = utility.newObject("ScreenGui",{
    ResetOnSpawn=false,
    Parent=cg
})

-- ============================================================
-- COLORPICKER (shared, singleton)
-- ============================================================
local ColorpickerOpen = utility.newObject("Frame",{
    BackgroundColor3=colorfromrgb(12,12,12),
    BorderSizePixel=0,
    Size=udim2new(0,180,0,175),
    ZIndex=250,
    BackgroundTransparency=1,
    Visible=false,
    Parent=_screenGui
})
local CP_Inside2 = utility.newObject("Frame",{
    BackgroundColor3=colorfromrgb(60,60,60),
    BorderSizePixel=0,
    Position=udim2new(0,1,0,1),
    Size=udim2new(1,-2,1,-2),
    BackgroundTransparency=1,
    ZIndex=250,
    Parent=ColorpickerOpen
})
local CP_Inside3 = utility.newObject("Frame",{
    BackgroundColor3=colorfromrgb(40,40,40),
    BorderSizePixel=0,
    Position=udim2new(0,1,0,1),
    Size=udim2new(1,-2,1,-2),
    BackgroundTransparency=1,
    ZIndex=250,
    Parent=CP_Inside2
})
local SatImage = utility.newObject("ImageLabel",{
    BackgroundColor3=colorfromrgb(170,0,0),
    Position=udim2new(0,3,0,3),
    Size=udim2new(0,150,0,150),
    BackgroundTransparency=1,
    ImageTransparency=1,
    ZIndex=250,
    Image="rbxassetid://13966897785",
    Parent=CP_Inside3
})
local SatMover = utility.newObject("ImageLabel",{
    BackgroundTransparency=1,
    ImageTransparency=1,
    Size=udim2new(0,4,0,4),
    ZIndex=250,
    Image="http://www.roblox.com/asset/?id=17819434984",
    Parent=SatImage
})
local HueFrame = utility.newObject("Frame",{
    BackgroundColor3=colorfromrgb(255,255,255),
    Position=udim2new(1,-18,0,3),
    Size=udim2new(0,15,0,150),
    BackgroundTransparency=1,
    ZIndex=250,
    Parent=CP_Inside3
})
utility.newObject("UIGradient",{
    Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0.00,colorfromrgb(170,0,0)),
        ColorSequenceKeypoint.new(0.15,colorfromrgb(255,255,0)),
        ColorSequenceKeypoint.new(0.30,colorfromrgb(0,255,0)),
        ColorSequenceKeypoint.new(0.45,colorfromrgb(0,255,255)),
        ColorSequenceKeypoint.new(0.60,colorfromrgb(0,0,255)),
        ColorSequenceKeypoint.new(0.75,colorfromrgb(175,0,255)),
        ColorSequenceKeypoint.new(1.00,colorfromrgb(170,0,0))
    },
    Rotation=90,
    Parent=HueFrame
})
local HueMover = utility.newObject("ImageLabel",{
    BackgroundTransparency=1,
    ImageTransparency=1,
    Size=udim2new(1,0,0,4),
    ZIndex=250,
    Image="http://www.roblox.com/asset/?id=17819584226",
    Parent=HueFrame
})
local TransImage = utility.newObject("ImageLabel",{
    Position=udim2new(0,3,1,-13),
    Size=udim2new(0,150,0,10),
    ZIndex=250,
    ScaleType=Enum.ScaleType.Tile,
    Image="rbxassetid://18249241978",
    BackgroundTransparency=1,
    TileSize=udim2new(0,12,0,12),
    Parent=CP_Inside3
})
local TransFrame = utility.newObject("Frame",{
    Size=udim2new(1,0,1,0),
    ZIndex=251,
    Parent=TransImage
})
local TransGrad = utility.newObject("UIGradient",{
    Transparency=NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.1),
        NumberSequenceKeypoint.new(1,0.8)
    },
    Rotation=180,
    Parent=TransFrame
})
local TransMover = utility.newObject("ImageLabel",{
    BackgroundTransparency=1,
    Position=udim2new(1,-4,0,0),
    Size=udim2new(0,4,1,0),
    ImageTransparency=1,
    ZIndex=250,
    Image="http://www.roblox.com/asset/?id=17819483422",
    Parent=TransFrame
})

local cp_hue,cp_sat,cp_val = 0,0,255
local cp_color = colorfromrgb(255,255,255)
local cp_trans = 0
local cp_dragging_sat,cp_dragging_hue,cp_dragging_trans=false,false,false
local cp_mouse_conn=nil
local cp_click_conn=nil

local function cp_update_sv(val,sat,do_tween)
    cp_sat=sat; cp_val=val
    cp_color=Color3.fromHSV(cp_hue/360,cp_sat/255,cp_val/255)
    utility.tween(SatMover,newtweeninfo(do_tween and menu.animation_speed or 0,Enum.EasingStyle.Sine),
        {Position=udim2new(clamp(sat/255,0,0.98),0,1-clamp(val/255,0.02,1),0)})
    TransFrame.BackgroundColor3=cp_color
    if menu.active_colorpicker then
        menu.active_colorpicker:setColor(cp_color,cp_trans,true)
        menu.active_colorpicker.onColorChange:Fire(cp_color,cp_trans)
    end
end

local function cp_update_hue(h,do_tween)
    utility.tween(HueMover,newtweeninfo(do_tween and menu.animation_speed or 0,Enum.EasingStyle.Sine),
        {Position=udim2new(0,0,clamp(h/360,0,0.99),0)})
    SatImage.BackgroundColor3=Color3.fromHSV(h/360,1,1)
    cp_color=Color3.fromHSV(h/360,cp_sat/255,cp_val/255)
    cp_hue=h
    TransFrame.BackgroundColor3=cp_color
    if menu.active_colorpicker then
        menu.active_colorpicker:setColor(cp_color,cp_trans,true)
        menu.active_colorpicker.onColorChange:Fire(cp_color,cp_trans)
    end
end

local function cp_update_trans(o,do_tween)
    utility.tween(TransMover,newtweeninfo(do_tween and menu.animation_speed or 0,Enum.EasingStyle.Sine),
        {Position=udim2new(clamp(1-o,0,0.98),0,0,0)})
    cp_trans=o
    local c=155*(1-(o*0.5))
    TransGrad.Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,colorfromrgb(c,c,c)),
        ColorSequenceKeypoint.new(1,colorfromrgb(c,c,c))
    }
    if menu.active_colorpicker then
        menu.active_colorpicker:setColor(cp_color,cp_trans,true)
        menu.active_colorpicker.onColorChange:Fire(cp_color,cp_trans)
    end
end

local function closeColorpicker(force)
    local spd=force and 0 or menu.animation_speed
    local inf=newtweeninfo(spd,Enum.EasingStyle.Sine,Enum.EasingDirection.Out)
    utility.tween(ColorpickerOpen,inf,{BackgroundTransparency=1})
    utility.tween(CP_Inside2,inf,{BackgroundTransparency=1})
    utility.tween(CP_Inside3,inf,{BackgroundTransparency=1})
    utility.tween(SatImage,inf,{ImageTransparency=1,BackgroundTransparency=1})
    utility.tween(SatMover,inf,{ImageTransparency=1,BackgroundTransparency=1})
    utility.tween(HueFrame,inf,{BackgroundTransparency=1})
    utility.tween(HueMover,inf,{ImageTransparency=1,BackgroundTransparency=1})
    utility.tween(TransFrame,inf,{BackgroundTransparency=1})
    utility.tween(TransMover,inf,{ImageTransparency=1,BackgroundTransparency=1})
    utility.tween(TransImage,inf,{ImageTransparency=1})
    delay_fn(spd,function()
        if menu.active_colorpicker==nil then
            menu.busy=false
            utility.is_dragging_blocked=false
            ColorpickerOpen.Visible=false
        end
    end)
    if cp_click_conn then cp_click_conn:Disconnect() end
    menu.active_colorpicker=nil
end

local function openColorpicker(element, info, ColorBox)
    local spd=menu.animation_speed
    local inf=newtweeninfo(spd,Enum.EasingStyle.Sine,Enum.EasingDirection.Out)
    local np=ColorBox.AbsolutePosition
    ColorpickerOpen.Position=udim2new(0,np.X,0,np.Y+2+ColorBox.AbsoluteSize.Y)
    ColorpickerOpen.Visible=true
    menu.active_colorpicker=element
    utility.tween(ColorpickerOpen,inf,{BackgroundTransparency=0})
    utility.tween(CP_Inside2,inf,{BackgroundTransparency=0})
    utility.tween(CP_Inside3,inf,{BackgroundTransparency=0})
    utility.tween(SatImage,inf,{ImageTransparency=0,BackgroundTransparency=0})
    utility.tween(SatMover,inf,{ImageTransparency=0,BackgroundTransparency=0.6})
    utility.tween(HueFrame,inf,{BackgroundTransparency=0})
    utility.tween(HueMover,inf,{ImageTransparency=0.2,BackgroundTransparency=0.5})
    utility.tween(TransFrame,inf,{BackgroundTransparency=0})
    utility.tween(TransMover,inf,{ImageTransparency=0,BackgroundTransparency=0.5})
    utility.tween(TransImage,inf,{ImageTransparency=0})
    element:setColor(flags[info.flag], flags[info.transparency_flag])
    cp_click_conn=utility.newConnection(uis.InputBegan,function(input,gpe)
        if gpe then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            if not utility.isInFrame(ColorBox,input.Position) and
               not utility.isInFrame(ColorpickerOpen,input.Position) then
                closeColorpicker()
            end
        end
    end)
    menu.busy=true
    utility.is_dragging_blocked=true
    wait_fn()
end

-- Sat drag
utility.newConnection(SatImage.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        utility.is_dragging_blocked=true
        local xd=clamp((mouse.X-SatImage.AbsolutePosition.X)/SatImage.AbsoluteSize.X,0,1)
        local yd=1-clamp((mouse.Y-SatImage.AbsolutePosition.Y)/SatImage.AbsoluteSize.Y,0,1)
        cp_update_sv(yd*255,xd*255,true)
        cp_dragging_sat=true
        cp_mouse_conn=utility.newConnection(mouse.Move,function()
            local xd2=clamp((mouse.X-SatImage.AbsolutePosition.X)/SatImage.AbsoluteSize.X,0,1)
            local yd2=1-clamp((mouse.Y-SatImage.AbsolutePosition.Y)/SatImage.AbsoluteSize.Y,0,1)
            cp_update_sv(yd2*255,xd2*255)
        end)
    end
end)
utility.newConnection(SatImage.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 and cp_dragging_sat then
        cp_dragging_sat=false
        if cp_mouse_conn then cp_mouse_conn:Disconnect() end
    end
end)

-- Hue drag
utility.newConnection(HueFrame.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        utility.is_dragging_blocked=true
        cp_update_hue(360*clamp((mouse.Y-HueFrame.AbsolutePosition.Y)/HueFrame.AbsoluteSize.Y,0,1),true)
        cp_dragging_hue=true
        cp_mouse_conn=utility.newConnection(mouse.Move,function()
            cp_update_hue(360*clamp((mouse.Y-HueFrame.AbsolutePosition.Y)/HueFrame.AbsoluteSize.Y,0,1))
        end)
    end
end)
utility.newConnection(HueFrame.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 and cp_dragging_hue then
        cp_dragging_hue=false
        if cp_mouse_conn then cp_mouse_conn:Disconnect() end
    end
end)

-- Trans drag
utility.newConnection(TransFrame.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        utility.is_dragging_blocked=true
        cp_update_trans(1-clamp((mouse.X-TransFrame.AbsolutePosition.X)/TransFrame.AbsoluteSize.X,0,1),true)
        cp_dragging_trans=true
        cp_mouse_conn=utility.newConnection(mouse.Move,function()
            cp_update_trans(1-clamp((mouse.X-TransFrame.AbsolutePosition.X)/TransFrame.AbsoluteSize.X,0,1))
        end)
    end
end)
utility.newConnection(TransFrame.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 and cp_dragging_trans then
        cp_dragging_trans=false
        if cp_mouse_conn then cp_mouse_conn:Disconnect() end
    end
end)

-- ============================================================
-- KEYBIND DROPDOWN
-- ============================================================
local shortened_characters = {
    [Enum.KeyCode.LeftShift]=  "LSHF",
    [Enum.KeyCode.RightShift]= "RSHF",
    [Enum.UserInputType.MouseButton1]="M1",
    [Enum.UserInputType.MouseButton2]="M2",
    [Enum.UserInputType.MouseButton3]="M3",
    [Enum.KeyCode.Delete]=     "DEL",
    [Enum.KeyCode.Insert]=     "INS",
    [Enum.KeyCode.PageUp]=     "PGUP",
    [Enum.KeyCode.PageDown]=   "PGDW",
    [Enum.KeyCode.LeftControl]="LCTR",
    [Enum.KeyCode.RightControl]="RCTR",
    [Enum.KeyCode.LeftAlt]=    "LALT",
    [Enum.KeyCode.RightAlt]=   "RALT",
    [Enum.KeyCode.CapsLock]=   "CAPS",
    [Enum.KeyCode.ScrollLock]= "SLCK",
    [Enum.KeyCode.Backspace]=  "BSPC",
    [Enum.KeyCode.Space]=      "SPC",
}

local KeybindOpen = utility.newObject("Frame",{
    BackgroundColor3=colorfromrgb(12,12,12),
    BorderSizePixel=0,
    Size=udim2new(0,100,0,0),
    AutomaticSize=Enum.AutomaticSize.Y,
    ZIndex=25,
    BackgroundTransparency=1,
    Visible=false,
    Parent=_screenGui
})
local KB_Inside = utility.newObject("Frame",{
    BackgroundColor3=colorfromrgb(35,35,35),
    BorderSizePixel=0,
    AutomaticSize=Enum.AutomaticSize.Y,
    Position=udim2new(0,1,0,1),
    Size=udim2new(1,-2,0,0),
    BackgroundTransparency=1,
    ZIndex=25,
    Parent=KeybindOpen
})
utility.newObject("UIListLayout",{
    HorizontalAlignment=Enum.HorizontalAlignment.Right,
    SortOrder=Enum.SortOrder.LayoutOrder,
    Parent=KB_Inside
})

local kb_labels = {}
local kb_label_names = {"Always on","On hotkey","Toggle"}
for i,txt in kb_label_names do
    local lbl = utility.newObject("TextLabel",{
        BackgroundColor3=colorfromrgb(25,25,25),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        Size=udim2new(1,0,0,17),
        ZIndex=25,
        FontFace=menu_font,
        Text="    "..txt,
        TextColor3=colorfromrgb(205,205,205),
        TextSize=13,
        TextTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,
        Parent=KB_Inside
    })
    lbl.Name=tostring(i)
    kb_labels[i]=lbl

    utility.newConnection(lbl.MouseEnter,function()
        if not menu.active_keybind then return end
        lbl.BackgroundTransparency=0
        if flags[menu.active_keybind.flag] and flags[menu.active_keybind.flag].method==i then return end
        lbl.FontFace=menu_font_bold
    end)
    utility.newConnection(lbl.MouseLeave,function()
        if not menu.active_keybind then return end
        lbl.BackgroundTransparency=1
        if flags[menu.active_keybind.flag] and flags[menu.active_keybind.flag].method==i then return end
        lbl.FontFace=menu_font
    end)
    utility.newConnection(lbl.InputBegan,function(input,gpe)
        if not menu.active_keybind then return end
        if gpe then return end
        if flags[menu.active_keybind.flag] and flags[menu.active_keybind.flag].method==i then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            menu.active_keybind:setMethod(i,true,true)
        end
    end)
end

local function closeKeybind(force)
    local spd=force and 0 or menu.animation_speed
    local inf=newtweeninfo(spd,Enum.EasingStyle.Sine,Enum.EasingDirection.Out)
    utility.tween(KeybindOpen,inf,{BackgroundTransparency=1})
    utility.tween(KB_Inside,inf,{BackgroundTransparency=1})
    for _,lbl in kb_labels do utility.tween(lbl,inf,{TextTransparency=1}) end
    delay_fn(spd,function()
        utility.is_dragging_blocked=false
        if menu.active_keybind==nil then
            menu.busy=false
            KeybindOpen.Visible=false
        end
    end)
    menu.active_keybind=nil
end

local function openKeybind(element,_info,KeybindLabel)
    local spd=menu.animation_speed
    local inf=newtweeninfo(spd,Enum.EasingStyle.Sine,Enum.EasingDirection.Out)
    local np=KeybindLabel.AbsolutePosition
    KeybindOpen.Position=udim2new(0,np.X-102,0,np.Y)
    KeybindOpen.Visible=true
    utility.tween(KeybindOpen,inf,{BackgroundTransparency=0})
    utility.tween(KB_Inside,inf,{BackgroundTransparency=0})
    for _,lbl in kb_labels do utility.tween(lbl,inf,{TextTransparency=0}) end
    menu.active_keybind=element
    element:setMethod(flags[_info.flag].method,false,true)
    menu.busy=true
    utility.is_dragging_blocked=true
end

-- ============================================================
-- WINDOW CREATION
-- ============================================================
function SkeetCCUI.newWindow(config)
    --[[
        config = {
            title = "My Script",
            tabs  = {"Tab1","Tab2",...}   -- up to 8 tab names
            accent= Color3                -- optional accent color override
        }
    ]]
    config = config or {}
    if config.accent then
        menu.accent_color = config.accent
    end

    local Border = utility.newObject("Frame",{
        BackgroundColor3=colorfromrgb(60,60,60),
        BorderSizePixel=0,
        AnchorPoint=vector2new(0.5,0.5),
        Position=udim2new(0.5,0,0.5,0),
        Size=udim2new(0,658,0,558),
        Parent=_screenGui
    })
    local Border2 = utility.newObject("Frame",{
        BackgroundColor3=colorfromrgb(40,40,40),
        BorderSizePixel=0,
        Position=udim2new(0,2,0,2),
        Size=udim2new(1,-4,1,-4),
        Parent=Border
    })
    local Background = utility.newObject("ImageLabel",{
        BackgroundColor3=colorfromrgb(255,255,255),
        BorderSizePixel=0,
        Position=udim2new(0,3,0,3),
        Size=udim2new(1,-6,1,-6),
        Image="rbxassetid://15453092054",
        ScaleType=Enum.ScaleType.Tile,
        TileSize=udim2new(0,4,0,548),
        ClipsDescendants=true,
        Parent=Border2
    })

    -- Tab sidebar
    local TabHolder = utility.newObject("Frame",{
        BackgroundColor3=colorfromrgb(12,12,12),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        Position=udim2new(0,0,0,14),
        Size=udim2new(0,73,0,0),
        Parent=Background
    })
    utility.newObject("UIListLayout",{
        HorizontalAlignment=Enum.HorizontalAlignment.Center,
        SortOrder=Enum.SortOrder.LayoutOrder,
        Parent=TabHolder
    })

    -- Side decorators
    local TopGap = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Size=udim2new(0,73,0,14),Parent=Background})
    utility.newObject("Frame",{BackgroundColor3=colorfromrgb(0,0,0),BorderSizePixel=0,Position=udim2new(0,73,0,0),Size=udim2new(0,1,1,0),Parent=TopGap})
    local BottomGap = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Position=udim2new(0,0,1,-22),Size=udim2new(0,73,0,22),Parent=Background})
    utility.newObject("Frame",{BackgroundColor3=colorfromrgb(0,0,0),BorderSizePixel=0,Position=udim2new(0,73,0,0),Size=udim2new(0,1,1,0),Parent=BottomGap})

    -- Rainbow top bar
    local TopBar = utility.newObject("ImageLabel",{
        BackgroundTransparency=1,
        BorderSizePixel=0,
        Position=udim2new(0,1,0,1),
        Size=udim2new(1,-2,0,2),
        ZIndex=2,
        Image="rbxassetid://15453122383",
        Parent=Background
    })
    utility.newObject("Frame",{BackgroundColor3=colorfromrgb(6,6,6),BorderSizePixel=0,Position=udim2new(0,0,1,0),Size=udim2new(1,0,0,1),ZIndex=2,Parent=TopBar})

    -- Tab content area
    local TabFix = utility.newObject("Frame",{
        BackgroundTransparency=1,
        BorderSizePixel=0,
        Position=udim2new(0,91,0,18),
        Size=udim2new(1,-105,1,-33),
        ClipsDescendants=true,
        Parent=Background
    })

    utility.setDraggable(Border)

    -- Open/close animations
    local animObjects = {Border,Border2,Background,TabHolder,TopGap,TopBar,BottomGap}
    utility.newConnection(menu.on_closing,function()
        for _,o in animObjects do utility.tween(o,tween_info,{BackgroundTransparency=1}) end
        utility.tween(Background,tween_info,{ImageTransparency=1})
    end)
    utility.newConnection(menu.on_opening,function()
        for _,o in animObjects do utility.tween(o,tween_info,{BackgroundTransparency=0}) end
        utility.tween(Background,tween_info,{ImageTransparency=0})
    end)
    utility.newConnection(Border:GetPropertyChangedSignal("BackgroundTransparency"),function()
        _screenGui.Enabled = Border.BackgroundTransparency~=1
        menu.is_open = _screenGui.Enabled
    end)

    -- Toggle keybind
    utility.newConnection(uis.InputBegan,function(input,gpe)
        if gpe then return end
        if string.upper(input.KeyCode.Name)==menu.toggle then
            if menu.is_open then menu.on_closing:Fire() else menu.on_opening:Fire() end
        end
        local kc = shortened_characters[input.UserInputType] and input.UserInputType or input.KeyCode
        local kbs = kc and menu.keybinds[kc]
        if kbs then
            for _,info in kbs do
                if flags[info[2]] then
                    if flags[info[2]].method==2 then info[1]:setActive(true)
                    elseif flags[info[2]].method==3 then info[1]:setActive(not flags[info[2]].active) end
                end
            end
        end
    end)
    utility.newConnection(uis.InputEnded,function(input)
        local kc=shortened_characters[input.UserInputType] and input.UserInputType or input.KeyCode
        local kbs=kc and menu.keybinds[kc]
        if kbs then
            for _,info in kbs do
                if flags[info[2]] and flags[info[2]].method==2 then info[1]:setActive(false) end
            end
        end
    end)

    -- ======================================================
    -- Window object
    -- ======================================================
    local windowObj = {
        _border      = Border,
        _tabHolder   = TabHolder,
        _tabFix      = TabFix,
        _tabs        = {},
        _activeTab   = nil,
        accent_color = menu.accent_color,
    }

    -- ======================================================
    -- TAB
    -- ======================================================
    function windowObj:addTab(name, iconId)
        local tabIdx = #self._tabs+1

        local Button = utility.newObject("Frame",{
            BackgroundColor3=colorfromrgb(12,12,12),
            BorderSizePixel=0,
            Size=udim2new(0,73,0,64),
            Parent=self._tabHolder
        })
        local Icon = utility.newObject("ImageLabel",{
            BackgroundTransparency=1,
            BorderSizePixel=0,
            Size=udim2new(1,0,1,0),
            Image=iconId or "",
            ImageColor3=colorfromrgb(109,109,109),
            Parent=Button
        })
        -- Active indicator bars
        local BottomBar = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(0,0,0),BorderSizePixel=0,Position=udim2new(0,0,1,1),Size=udim2new(1,0,0,1),Visible=false,ZIndex=2,Parent=Button})
        utility.newObject("Frame",{BackgroundColor3=colorfromrgb(40,40,40),BorderSizePixel=0,Position=udim2new(0,0,0,-1),Size=udim2new(1,2,1,0),ZIndex=2,Parent=BottomBar})
        local TopBar2 = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(0,0,0),BorderSizePixel=0,Position=udim2new(0,0,0,-2),Size=udim2new(1,0,0,1),Visible=false,ZIndex=2,Parent=Button})
        utility.newObject("Frame",{BackgroundColor3=colorfromrgb(40,40,40),BorderSizePixel=0,Position=udim2new(0,0,0,1),Size=udim2new(1,2,1,0),ZIndex=2,Parent=TopBar2})
        local SideBar = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(0,0,0),BorderSizePixel=0,Position=udim2new(0,73,0,0),Size=udim2new(0,1,1,0),Parent=Button})
        utility.newObject("Frame",{BackgroundColor3=colorfromrgb(40,40,40),BorderSizePixel=0,Position=udim2new(1,0,0,0),Size=udim2new(0,1,1,0),Parent=SideBar})

        -- Tab frame (slides in/out)
        local TabFrame = utility.newObject("Frame",{
            BackgroundTransparency=1,
            BorderSizePixel=0,
            Position=udim2new(0,5,1,5), -- starts off screen
            Size=udim2new(1,-10,1,-8),
            Visible=false,
            Parent=self._tabFix
        })

        local tabObj = {
            _window   = self,
            _idx      = tabIdx,
            _button   = Button,
            _icon     = Icon,
            _frame    = TabFrame,
            _bottomBar= BottomBar,
            _topBar   = TopBar2,
            _sideBar  = SideBar,
            _sections = {},
        }

        -- Hover/click
        utility.newConnection(Button.MouseEnter,function()
            if self._activeTab==tabIdx then return end
            utility.tween(Icon,newtweeninfo(menu.animation_speed/2,Enum.EasingStyle.Sine),{ImageColor3=colorfromrgb(204,204,204)})
        end)
        utility.newConnection(Button.MouseLeave,function()
            if self._activeTab==tabIdx then return end
            utility.tween(Icon,newtweeninfo(menu.animation_speed/2,Enum.EasingStyle.Sine),{ImageColor3=colorfromrgb(109,109,109)})
        end)
        utility.newConnection(Button.InputBegan,function(input,gpe)
            if gpe then return end
            if input.UserInputType==Enum.UserInputType.MouseButton1 then
                if self._activeTab~=tabIdx then self:_setTab(tabIdx) end
            end
        end)

        self._tabs[tabIdx]=tabObj
        if tabIdx==1 then self:_setTab(1) end

        setmetatable(tabObj,{__index=tabObj})

        -- ======================================================
        -- SECTION
        -- ======================================================
        function tabObj:addSection(name, side)
            -- side: "left" (default) or "right"
            local isRight = side=="right"
            local Section = utility.newObject("Frame",{
                BackgroundTransparency=1,
                BorderSizePixel=0,
                Size=udim2new(0.5,-10,1,0),
                Position=udim2new(isRight and 0.5 or 0, isRight and 0 or 9, 0,0),
                Parent=self._frame
            })
            local Inside = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Size=udim2new(1,0,1,-1),BackgroundTransparency=1,Parent=Section})
            local Inside2= utility.newObject("Frame",{BackgroundColor3=colorfromrgb(40,40,40),BorderSizePixel=0,Position=udim2new(0,1,0,0),Size=udim2new(1,-2,1,-1),BackgroundTransparency=1,Parent=Inside})
            local Inside3= utility.newObject("Frame",{BackgroundColor3=colorfromrgb(23,23,23),BorderSizePixel=0,Position=udim2new(0,1,0,0),Size=udim2new(1,-2,1,-1),BackgroundTransparency=1,Parent=Inside2})

            -- Section label
            local szPx = ts:GetTextSize(name,13,Enum.Font.SourceSansBold,vector2new(9999,9999)).X
            local SLabel=utility.newObject("TextLabel",{BackgroundTransparency=1,BorderSizePixel=0,Position=udim2new(0,12,0,-2),FontFace=menu_font_bold,Text=name,TextColor3=colorfromrgb(198,198,198),TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4,TextTransparency=1,Parent=Inside3})
            local TopLine=utility.newObject("Frame",{BackgroundColor3=colorfromrgb(40,40,40),BorderSizePixel=0,Size=udim2new(0,9,0,1),BackgroundTransparency=1,Parent=Inside3})
            utility.newObject("Frame",{BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Position=udim2new(0,-2,0,-1),Size=udim2new(1,2,0,1),BackgroundTransparency=1,Parent=TopLine})
            local _TopLine=utility.newObject("Frame",{BackgroundColor3=colorfromrgb(40,40,40),BorderSizePixel=0,Size=udim2new(1,-(szPx+16),0,1),Position=udim2new(0,szPx+16,0,0),BackgroundTransparency=1,Parent=Inside3})
            utility.newObject("Frame",{BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Position=udim2new(0,0,0,-1),Size=udim2new(1,2,0,1),BackgroundTransparency=1,Parent=_TopLine})

            -- Scroller
            local Scroller=utility.newObject("ScrollingFrame",{
                BackgroundTransparency=1,BorderSizePixel=0,
                Position=udim2new(0,0,0,2),Size=udim2new(1,0,1,-2),
                ZIndex=3,ScrollingEnabled=false,
                AutomaticCanvasSize=Enum.AutomaticSize.Y,
                CanvasSize=udim2new(0,0,1,0),
                ScrollBarImageTransparency=1,
                ScrollBarThickness=5,
                ClipsDescendants=true,
                Parent=Inside3
            })
            local EHolder=utility.newObject("Frame",{
                BackgroundTransparency=1,BorderSizePixel=0,
                Position=udim2new(0,18,0,18),Size=udim2new(1,-36,0,0),
                AutomaticSize=Enum.AutomaticSize.Y,Parent=Scroller
            })
            utility.newObject("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,10),Parent=EHolder})

            local sectionOpen = function(bypass)
                local inf2 = bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine,Enum.EasingDirection.In) or tween_info
                utility.tween(Inside,inf2,{BackgroundTransparency=0})
                utility.tween(Inside2,inf2,{BackgroundTransparency=0})
                utility.tween(Inside3,inf2,{BackgroundTransparency=0})
                utility.tween(SLabel,inf2,{TextTransparency=0})
                utility.tween(_TopLine,inf2,{BackgroundTransparency=0})
                utility.tween(TopLine,inf2,{BackgroundTransparency=0})
            end
            local sectionClose = function(bypass)
                local inf2 = bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine,Enum.EasingDirection.In) or tween_info
                utility.tween(Inside,inf2,{BackgroundTransparency=1})
                utility.tween(Inside2,inf2,{BackgroundTransparency=1})
                utility.tween(Inside3,inf2,{BackgroundTransparency=1})
                utility.tween(SLabel,inf2,{TextTransparency=1})
                utility.tween(_TopLine,inf2,{BackgroundTransparency=1})
                utility.tween(TopLine,inf2,{BackgroundTransparency=1})
            end

            utility.newConnection(menu.on_opening,sectionOpen)
            utility.newConnection(menu.on_closing,sectionClose)

            local sectionObj = {
                _frame       = Section,
                _holder      = EHolder,
                _tab         = tabObj,
                _elements    = {},
                on_opening   = sectionOpen,
                on_closing   = sectionClose,
            }

            self._sections[name]=sectionObj

            -- ===================================================
            -- ELEMENT
            -- ===================================================
            function sectionObj:addElement(info)
                --[[
                info = {
                    name     = "Label text",
                    types    = {
                        toggle      = { flag="myFlag", default=false },
                        slider      = { flag="myFlag", min=0, max=100, default=50, prefix="", suffix="%" },
                        dropdown    = { flag="myFlag", options={"A","B"}, default={}, multi=false },
                        button      = { text="Click me", callback=function() end },
                        colorpicker = { flag="myColor", transparency_flag="myTrans", default=Color3.fromRGB(255,255,255) },
                        keybind     = { flag="myKeybind", key=nil, method=1 },
                        textbox     = { flag="myText" },
                    }
                }
                --]]

                local Frame = utility.newObject("Frame",{
                    BackgroundTransparency=1,BorderSizePixel=0,
                    Size=udim2new(1,0,0,8),
                    Parent=self._holder
                })
                local Label = utility.newObject("TextLabel",{
                    BackgroundTransparency=1,BorderSizePixel=0,
                    Position=udim2new(0,20,0,-1),Size=udim2new(0.5,0,0,8),
                    FontFace=menu_font,
                    Text=info.name or "",
                    TextColor3=colorfromrgb(205,205,205),TextSize=13,
                    TextXAlignment=Enum.TextXAlignment.Left,
                    TextTransparency=1,Parent=Frame
                })

                local elemObj = {
                    frame    = Frame,
                    label    = Label,
                    name     = info.name,
                    visible  = true,
                    closing  = {},
                    opening  = {},
                }

                local tabFrame = tabObj._frame

                -- -----------------------------------------------
                -- TOGGLE
                -- -----------------------------------------------
                if info.types.toggle then
                    local ti = info.types.toggle
                    flags[ti.flag] = ti.default or false

                    local Box = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Size=udim2new(0,8,0,8),BackgroundTransparency=1,Parent=Frame})
                    local Inside = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(77,77,77),BorderSizePixel=0,Position=udim2new(0,1,0,1),Size=udim2new(1,-2,1,-2),BackgroundTransparency=1,Parent=Box})
                    utility.newObject("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,colorfromrgb(255,255,255)),ColorSequenceKeypoint.new(1,colorfromrgb(218,218,218))},Rotation=90,Parent=Inside})

                    elemObj.onToggleChange = Signal.new()
                    elemObj.toggled = false

                    local h,s,v = menu.accent_color:ToHSV()
                    utility.newConnection(menu.on_accent_change,function(c) h,s,v=c:ToHSV()
                        if elemObj.toggled then utility.tween(Inside,newtweeninfo(0),{BackgroundColor3=c}) end
                    end)

                    local last = ti.default
                    function elemObj:setToggle(bool, force)
                        if last~=bool or force then elemObj.onToggleChange:Fire(bool) end
                        last=bool
                        utility.tween(Inside,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=bool and menu.accent_color or colorfromrgb(77,77,77)})
                        elemObj.toggled=bool
                        flags[ti.flag]=bool
                    end
                    elemObj:setToggle(ti.default or false)

                    local function onHov()
                        utility.tween(Inside,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=elemObj.toggled and Color3.fromHSV(h,s,v*1.1) or colorfromrgb(85,85,85)})
                    end
                    local function onLv()
                        utility.tween(Inside,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=elemObj.toggled and menu.accent_color or colorfromrgb(77,77,77)})
                    end
                    utility.newConnection(Box.MouseEnter,onHov)
                    utility.newConnection(Label.MouseEnter,onHov)
                    utility.newConnection(Box.MouseLeave,onLv)
                    utility.newConnection(Label.MouseLeave,onLv)
                    utility.newConnection(Box.InputEnded,function(inp,gpe)
                        if gpe then return end
                        if inp.UserInputType==Enum.UserInputType.MouseButton1 and not menu.busy then
                            elemObj:setToggle(not elemObj.toggled)
                        end
                    end)
                    utility.newConnection(Label.InputEnded,function(inp,gpe)
                        if gpe then return end
                        if inp.UserInputType==Enum.UserInputType.MouseButton1 and not menu.busy then
                            elemObj:setToggle(not elemObj.toggled)
                        end
                    end)

                    table.insert(elemObj.closing,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(Box,inf2,{BackgroundTransparency=1})
                        utility.tween(Inside,inf2,{BackgroundTransparency=1})
                    end)
                    table.insert(elemObj.opening,function(bypass)
                        if not elemObj.visible then return end
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(Box,inf2,{BackgroundTransparency=0})
                        utility.tween(Inside,inf2,{BackgroundTransparency=0})
                    end)

                    utility.newConnection(menu.on_load,function()
                        elemObj:setToggle(flags[ti.flag])
                    end)
                end

                -- -----------------------------------------------
                -- SLIDER
                -- -----------------------------------------------
                if info.types.slider then
                    local si = info.types.slider
                    flags[si.flag] = si.min
                    Frame.Size = udim2new(1,0,0,20)

                    local Border = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Position=udim2new(0,19,0,13),Size=udim2new(0.72,0,0,7),BackgroundTransparency=1,Parent=Frame})
                    utility.newObject("UISizeConstraint",{MaxSize=vector2new(200,9e9),Parent=Border})
                    local Inside = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(69,69,69),BorderSizePixel=0,Position=udim2new(0,1,0,1),Size=udim2new(1,-2,1,-2),BackgroundTransparency=1,Parent=Border})
                    utility.newObject("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,colorfromrgb(204,204,204)),ColorSequenceKeypoint.new(1,colorfromrgb(255,255,255))},Rotation=90,Parent=Inside})
                    local Fill = utility.newObject("Frame",{BackgroundColor3=menu.accent_color,BorderSizePixel=0,Size=udim2new(0,0,1,0),BackgroundTransparency=1,Parent=Inside})
                    utility.newObject("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,colorfromrgb(249,249,249)),ColorSequenceKeypoint.new(1,colorfromrgb(201,201,201))},Rotation=90,Parent=Fill})
                    local ValLabel = utility.newObject("TextBox",{BackgroundTransparency=1,BorderSizePixel=0,Position=udim2new(1,-1,0,-2),FontFace=menu_font_bold,Text=(si.prefix or "")..(si.min)..(si.suffix or ""),TextColor3=colorfromrgb(205,205,205),TextSize=14,ClearTextOnFocus=true,TextTransparency=1,Parent=Fill})

                    utility.newConnection(menu.on_accent_change,function(c) Fill.BackgroundColor3=c end)

                    elemObj.onSliderChange = Signal.new()

                    local dragging_sl=false
                    local sl_conn=nil

                    function elemObj:setValue(value,do_tw)
                        value=clamp(value,si.min,si.max)
                        local txt=(si.prefix or "")..value..(si.suffix or "")
                        if si.min==value and si.min_text then txt=si.min_text
                        elseif si.max==value and si.max_text then txt=si.max_text end
                        ValLabel.Text=txt
                        local pct=(value-si.min)/(si.max-si.min)
                        utility.tween(Fill,newtweeninfo(do_tw and menu.animation_speed or 0,Enum.EasingStyle.Sine),{Size=udim2new(pct,0,1,0)})
                        flags[si.flag]=value
                        elemObj.onSliderChange:Fire(value)
                    end

                    utility.newConnection(Inside.InputBegan,function(input)
                        if input.UserInputType==Enum.UserInputType.MouseButton1 and not menu.busy then
                            utility.is_dragging_blocked=true
                            local dist=clamp((input.Position.X-Inside.AbsolutePosition.X)/Inside.AbsoluteSize.X,0,1)
                            local val=round_fn(si.min+(si.max-si.min)*dist, si.decimal or 0)
                            elemObj:setValue(val,true)
                            dragging_sl=true
                            sl_conn=utility.newConnection(mouse.Move,function()
                                if dragging_sl then
                                    local d=clamp((mouse.X-Inside.AbsolutePosition.X)/Inside.AbsoluteSize.X,0,1)
                                    elemObj:setValue(round_fn(si.min+(si.max-si.min)*d, si.decimal or 0))
                                end
                            end)
                        end
                    end)
                    utility.newConnection(Inside.InputEnded,function(input)
                        if input.UserInputType==Enum.UserInputType.MouseButton1 and dragging_sl then
                            dragging_sl=false
                            utility.is_dragging_blocked=false
                            if sl_conn then sl_conn:Disconnect() end
                        end
                    end)
                    utility.newConnection(Inside.MouseEnter,function()
                        utility.tween(Inside,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=colorfromrgb(81,81,81)})
                    end)
                    utility.newConnection(Inside.MouseLeave,function()
                        utility.tween(Inside,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=colorfromrgb(69,69,69)})
                    end)

                    elemObj:setValue(si.default or si.min)

                    table.insert(elemObj.closing,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(Border,inf2,{BackgroundTransparency=1})
                        utility.tween(Inside,inf2,{BackgroundTransparency=1})
                        utility.tween(Fill,inf2,{BackgroundTransparency=1})
                        utility.tween(ValLabel,inf2,{TextTransparency=1})
                    end)
                    table.insert(elemObj.opening,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(Border,inf2,{BackgroundTransparency=0})
                        utility.tween(Inside,inf2,{BackgroundTransparency=0})
                        utility.tween(Fill,inf2,{BackgroundTransparency=0})
                        utility.tween(ValLabel,inf2,{TextTransparency=0.1})
                    end)

                    utility.newConnection(menu.on_load,function()
                        elemObj:setValue(flags[si.flag])
                    end)
                end

                -- -----------------------------------------------
                -- BUTTON
                -- -----------------------------------------------
                if info.types.button then
                    local bi = info.types.button
                    Frame.Size=udim2new(1,0,0,25)
                    Label.Visible=false

                    local Border = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Position=udim2new(0,19,0,0),Size=udim2new(0.72,0,0,25),BackgroundTransparency=1,Parent=Frame})
                    utility.newObject("UISizeConstraint",{MaxSize=vector2new(200,9e9),Parent=Border})
                    local I2=utility.newObject("Frame",{BackgroundColor3=colorfromrgb(50,50,50),BorderSizePixel=0,Position=udim2new(0,1,0,1),Size=udim2new(1,-2,1,-2),BackgroundTransparency=1,Parent=Border})
                    local I3=utility.newObject("Frame",{BackgroundColor3=colorfromrgb(34,34,34),BorderSizePixel=0,Position=udim2new(0,1,0,1),Size=udim2new(1,-2,1,-2),BackgroundTransparency=1,Parent=I2})
                    utility.newObject("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,colorfromrgb(255,255,255)),ColorSequenceKeypoint.new(1,colorfromrgb(227,227,227))},Rotation=90,Parent=I3})
                    local BLabel=utility.newObject("TextLabel",{BackgroundTransparency=1,BorderSizePixel=0,Size=udim2new(1,0,1,0),FontFace=menu_font_bold,Text=bi.text or "Button",TextColor3=colorfromrgb(212,212,212),TextSize=13,TextTransparency=1,TextWrapped=true,Parent=I3})

                    table.insert(elemObj.closing,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(Border,inf2,{BackgroundTransparency=1})
                        utility.tween(I2,inf2,{BackgroundTransparency=1})
                        utility.tween(I3,inf2,{BackgroundTransparency=1})
                        utility.tween(BLabel,inf2,{TextTransparency=1})
                    end)
                    table.insert(elemObj.opening,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(Border,inf2,{BackgroundTransparency=0})
                        utility.tween(I2,inf2,{BackgroundTransparency=0})
                        utility.tween(I3,inf2,{BackgroundTransparency=0})
                        utility.tween(BLabel,inf2,{TextTransparency=0})
                    end)

                    utility.newConnection(Border.MouseEnter,function()
                        utility.tween(I3,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=colorfromrgb(39,39,39)})
                    end)
                    utility.newConnection(Border.MouseLeave,function()
                        utility.tween(I3,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=colorfromrgb(34,34,34)})
                    end)
                    utility.newConnection(Border.InputBegan,function(inp,gpe)
                        if gpe then return end
                        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
                            utility.tween(I3,newtweeninfo(0),{BackgroundColor3=colorfromrgb(28,28,28)})
                        end
                    end)

                    local waiting=false
                    utility.newConnection(Border.InputEnded,function(inp,gpe)
                        if gpe then return end
                        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
                            if utility.isInFrame(Border,inp.Position) then
                                if bi.confirmation then
                                    if not waiting then
                                        waiting=true
                                        BLabel.Text="Are you sure?"
                                        delay_fn(3,function()
                                            if waiting then BLabel.Text=bi.text; waiting=false end
                                        end)
                                    else
                                        waiting=false
                                        BLabel.Text=bi.text
                                        if bi.callback then bi.callback() end
                                    end
                                else
                                    if bi.callback then bi.callback() end
                                end
                                utility.tween(I3,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=colorfromrgb(39,39,39)})
                            else
                                utility.tween(I3,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=colorfromrgb(34,34,34)})
                            end
                        end
                    end)
                end

                -- -----------------------------------------------
                -- DROPDOWN
                -- -----------------------------------------------
                if info.types.dropdown then
                    local di = info.types.dropdown
                    flags[di.flag] = di.default or {}
                    Frame.Size = udim2new(1,0,0,31)

                    local Border = utility.newObject("Frame",{BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Position=udim2new(0,19,0,11),Size=udim2new(0.72,0,0,20),BackgroundTransparency=1,Parent=Frame})
                    utility.newObject("UISizeConstraint",{MaxSize=vector2new(200,9e9),Parent=Border})
                    local _In=utility.newObject("Frame",{BackgroundColor3=colorfromrgb(36,36,36),BorderSizePixel=0,Position=udim2new(0,1,0,1),Size=udim2new(1,-2,1,-2),BackgroundTransparency=1,Parent=Border})
                    utility.newObject("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,colorfromrgb(219,219,219)),ColorSequenceKeypoint.new(1,colorfromrgb(255,255,255))},Rotation=90,Parent=_In})
                    local DLabel=utility.newObject("TextLabel",{BackgroundTransparency=1,BorderSizePixel=0,Position=udim2new(0,6,0,0),Size=udim2new(1,-24,1,0),FontFace=menu_font,TextTransparency=1,Text="-",TextColor3=colorfromrgb(152,152,152),TextSize=13,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,Parent=_In})
                    local Arrow=utility.newObject("ImageLabel",{BackgroundTransparency=1,BorderSizePixel=0,Position=udim2new(1,-11,0,6),Size=udim2new(0,5,0,4),Image="rbxassetid://15556784588",ImageColor3=colorfromrgb(151,151,151),ImageTransparency=1,Parent=_In})

                    local DOpen=utility.newObject("Frame",{BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Position=udim2new(0,19,0,11),Size=udim2new(0,156,0,20),AutomaticSize=Enum.AutomaticSize.Y,Visible=false,ZIndex=10,Parent=_screenGui})
                    local OInside=utility.newObject("Frame",{BackgroundColor3=colorfromrgb(35,35,35),BorderSizePixel=0,Position=udim2new(0,1,0,1),Size=udim2new(1,-2,1,-2),ClipsDescendants=true,ZIndex=10,Parent=DOpen})
                    utility.newObject("UIListLayout",{HorizontalAlignment=Enum.HorizontalAlignment.Right,SortOrder=Enum.SortOrder.LayoutOrder,Parent=OInside})

                    local isOpen=false
                    local ddClickConn=nil
                    elemObj.onDropdownChange=Signal.new()

                    local function closeDrop(notOnBorder)
                        local spd=menu.animation_speed
                        if ddClickConn then ddClickConn:Disconnect() end
                        utility.tween(DOpen,newtweeninfo(spd,Enum.EasingStyle.Sine),{Size=udim2new(0,Border.AbsoluteSize.X+1,0,0),BackgroundTransparency=1})
                        for _,c in OInside:GetChildren() do
                            if c.ClassName=="TextLabel" then utility.tween(c,newtweeninfo(spd,Enum.EasingStyle.Sine),{TextTransparency=1}) end
                        end
                        delay_fn(0,function()
                            isOpen=false
                            if notOnBorder then
                                Arrow.ImageColor3=colorfromrgb(151,151,151)
                                utility.tween(_In,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=colorfromrgb(36,36,36)})
                            end
                        end)
                        delay_fn(spd-0.05,function()
                            if not isOpen then menu.busy=false; utility.is_dragging_blocked=false; DOpen.Visible=false end
                        end)
                    end

                    local function openDrop()
                        if menu.busy then return end
                        local np=Border.AbsolutePosition
                        DOpen.AutomaticSize=Enum.AutomaticSize.Y
                        DOpen.Size=udim2new(0,Border.AbsoluteSize.X+1,0,20)
                        local sz=DOpen.AbsoluteSize
                        DOpen.AutomaticSize=Enum.AutomaticSize.None
                        DOpen.Size=udim2new(0,Border.AbsoluteSize.X+1,0,0)
                        DOpen.Position=udim2new(0,np.X+0.5,0,np.Y+2+Border.AbsoluteSize.Y)
                        utility.tween(DOpen,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{Size=udim2new(0,Border.AbsoluteSize.X+1,0,sz.Y),BackgroundTransparency=0})
                        for _,c in OInside:GetChildren() do
                            if c.ClassName=="TextLabel" then utility.tween(c,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{TextTransparency=0}) end
                        end
                        DOpen.Visible=true
                        ddClickConn=utility.newConnection(uis.InputBegan,function(input,gpe)
                            if gpe then return end
                            if input.UserInputType==Enum.UserInputType.MouseButton1 then
                                if not utility.isInFrame(Border,input.Position) and not utility.isInFrame(DOpen,input.Position) then closeDrop(true) end
                            end
                        end)
                        isOpen=true; menu.busy=true; utility.is_dragging_blocked=true
                    end

                    function elemObj:setSelected(options)
                        options = options or {}
                        local str=""
                        for _,c in OInside:GetChildren() do
                            if c.ClassName~="TextLabel" then continue end
                            local opt=c.Name
                            local found=false
                            for _,o in options do if o==opt then found=true break end end
                            if found then
                                str=#str==0 and opt or str..", "..opt
                                c.FontFace=menu_font_bold; c.TextColor3=menu.accent_color
                            else
                                c.FontFace=menu_font; c.TextColor3=colorfromrgb(208,208,208)
                            end
                        end
                        DLabel.Text=#str==0 and "-" or str
                        elemObj.onDropdownChange:Fire(options)
                        flags[di.flag]=options
                    end

                    for _,opt in di.options or {} do
                        local DOpt=utility.newObject("TextLabel",{BackgroundColor3=colorfromrgb(25,25,25),BackgroundTransparency=1,BorderSizePixel=0,Size=udim2new(1,0,0,20),ZIndex=11,FontFace=menu_font,Text="   "..opt,TextColor3=colorfromrgb(208,208,208),TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,TextTransparency=1,Parent=OInside})
                        DOpt.Name=opt
                        utility.newConnection(DOpt.MouseEnter,function() DOpt.BackgroundTransparency=0; if flags[di.flag] and flags[di.flag][1]~=opt then DOpt.FontFace=menu_font_bold end end)
                        utility.newConnection(DOpt.MouseLeave,function() DOpt.BackgroundTransparency=1; if flags[di.flag] and flags[di.flag][1]~=opt then DOpt.FontFace=menu_font end end)
                        utility.newConnection(DOpt.InputBegan,function(input,gpe)
                            if gpe then return end
                            if input.UserInputType==Enum.UserInputType.MouseButton1 then
                                local cur=flags[di.flag] or {}
                                if di.multi then
                                    local found=false
                                    for i,o in cur do if o==opt then table.remove(cur,i); found=true break end end
                                    if not found then table.insert(cur,opt) end
                                    elemObj:setSelected(cur)
                                else
                                    local found=false
                                    for _,o in cur do if o==opt then found=true break end end
                                    flags[di.flag]=found and {} or {opt}
                                    elemObj:setSelected(flags[di.flag])
                                    closeDrop()
                                end
                            end
                        end)
                    end

                    elemObj:setSelected(di.default or {})

                    utility.newConnection(Border.MouseEnter,function()
                        utility.tween(_In,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=colorfromrgb(46,46,46)})
                    end)
                    utility.newConnection(Border.MouseLeave,function()
                        if isOpen then return end
                        utility.tween(_In,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine),{BackgroundColor3=colorfromrgb(36,36,36)})
                    end)
                    utility.newConnection(Border.InputEnded,function(inp,gpe)
                        if gpe then return end
                        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
                            if not menu.busy then openDrop()
                            elseif isOpen then closeDrop() end
                        end
                    end)

                    table.insert(elemObj.closing,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(Border,inf2,{BackgroundTransparency=1})
                        utility.tween(_In,inf2,{BackgroundTransparency=1})
                        utility.tween(DLabel,inf2,{TextTransparency=1})
                        utility.tween(Arrow,inf2,{ImageTransparency=1})
                        if isOpen then closeDrop() end
                    end)
                    table.insert(elemObj.opening,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(Border,inf2,{BackgroundTransparency=0})
                        utility.tween(_In,inf2,{BackgroundTransparency=0})
                        utility.tween(DLabel,inf2,{TextTransparency=0})
                        utility.tween(Arrow,inf2,{ImageTransparency=0})
                    end)

                    utility.newConnection(menu.on_load,function()
                        elemObj:setSelected(flags[di.flag])
                    end)
                end

                -- -----------------------------------------------
                -- COLORPICKER
                -- -----------------------------------------------
                if info.types.colorpicker then
                    local ci = info.types.colorpicker
                    flags[ci.flag] = ci.default or colorfromrgb(255,255,255)
                    flags[ci.transparency_flag or (ci.flag.."_trans")] = ci.default_transparency or 0

                    local ColorBox=utility.newObject("Frame",{AnchorPoint=vector2new(1,0),BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Position=udim2new(1,0,0,0),Size=udim2new(0,17,0,9),BackgroundTransparency=1,Parent=Frame})
                    local CBInside=utility.newObject("Frame",{BackgroundColor3=colorfromrgb(255,255,255),BorderSizePixel=0,Position=udim2new(0,1,0,1),Size=udim2new(1,-2,1,-2),BackgroundTransparency=1,Parent=ColorBox})
                    utility.newObject("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,colorfromrgb(255,255,255)),ColorSequenceKeypoint.new(1,colorfromrgb(218,218,218))},Rotation=90,Parent=CBInside})

                    elemObj.onColorChange=Signal.new()

                    function elemObj:setColor(color, trans, no_move)
                        local tflag = ci.transparency_flag or (ci.flag.."_trans")
                        if menu.active_colorpicker~=self or no_move then
                            flags[ci.flag]=color
                            flags[tflag]=trans
                            CBInside.BackgroundColor3=color
                            elemObj.onColorChange:Fire(color,trans)
                            return
                        end
                        local h2,s2,v2=color:ToHSV()
                        cp_update_sv(v2*255,s2*255,true)
                        cp_update_hue(h2*360)
                        cp_update_trans(trans or 0)
                    end

                    elemObj:setColor(ci.default or colorfromrgb(255,255,255), ci.default_transparency or 0)

                    utility.newConnection(ColorBox.InputEnded,function(input,gpe)
                        if gpe then return end
                        if input.UserInputType==Enum.UserInputType.MouseButton1 then
                            if not menu.busy then
                                openColorpicker(elemObj,ci,ColorBox)
                            elseif menu.active_colorpicker==elemObj then
                                closeColorpicker()
                            end
                        end
                    end)

                    table.insert(elemObj.closing,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        if menu.active_colorpicker==elemObj then closeColorpicker(true) end
                        utility.tween(ColorBox,inf2,{BackgroundTransparency=1})
                        utility.tween(CBInside,inf2,{BackgroundTransparency=1})
                    end)
                    table.insert(elemObj.opening,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(ColorBox,inf2,{BackgroundTransparency=0})
                        utility.tween(CBInside,inf2,{BackgroundTransparency=0})
                    end)

                    utility.newConnection(menu.on_load,function()
                        local tflag=ci.transparency_flag or (ci.flag.."_trans")
                        elemObj:setColor(flags[ci.flag], flags[tflag])
                    end)
                end

                -- -----------------------------------------------
                -- KEYBIND
                -- -----------------------------------------------
                if info.types.keybind then
                    local ki = info.types.keybind
                    flags[ki.flag]={method=ki.method or 1, key=nil, active=false}

                    local KLabel=utility.newObject("TextLabel",{AnchorPoint=vector2new(1,0),BackgroundTransparency=1,BorderSizePixel=0,AutomaticSize=Enum.AutomaticSize.X,Position=udim2new(1,0,0,0),Size=udim2new(0,0,0,7),FontFace=menu_font,Text="[-]",TextColor3=colorfromrgb(117,117,117),TextSize=9,TextTransparency=1,Parent=Frame})

                    elemObj.flag=ki.flag
                    elemObj.onActiveChange=Signal.new()

                    function elemObj:setActive(active)
                        flags[ki.flag].active=active
                        elemObj.onActiveChange:Fire(active)
                    end

                    function elemObj:setMethod(method,just_visual,test)
                        flags[ki.flag].method=method
                        if flags[ki.flag].active~=(method==1) or test then
                            elemObj:setActive(method==1)
                        end
                        if menu.active_keybind~=elemObj then return end
                        for i,lbl in kb_labels do
                            lbl.FontFace=menu_font
                            lbl.TextColor3=colorfromrgb(205,205,205)
                        end
                        if kb_labels[method] then
                            kb_labels[method].FontFace=menu_font_bold
                            kb_labels[method].TextColor3=menu.accent_color
                        end
                        if method==1 and not just_visual then elemObj:setActive(true) end
                    end

                    function elemObj:setKey(keycode)
                        local old=flags[ki.flag].key
                        if old then
                            local kbs=menu.keybinds[old]
                            if kbs then
                                for i,v in kbs do
                                    if v[1]==elemObj then table.remove(kbs,i) break end
                                end
                                if #kbs==0 then menu.keybinds[old]=nil end
                            end
                        end
                        if keycode==nil or keycode=="" then
                            KLabel.Text="[-]"
                            flags[ki.flag].key=nil
                            flags[ki.flag].active=flags[ki.flag].method==1
                            return
                        end
                        if menu.keybinds[keycode] then
                            table.insert(menu.keybinds[keycode],{elemObj,ki.flag})
                        else
                            menu.keybinds[keycode]={{elemObj,ki.flag}}
                        end
                        flags[ki.flag].key=keycode
                        local sc=shortened_characters[keycode] or keycode.Name
                        KLabel.Text="["..string.upper(sc).."]"
                    end

                    elemObj:setMethod(ki.method or 1)
                    elemObj:setKey(ki.key or nil)

                    local kl_listen=nil
                    local function stopKB()
                        utility.tween(KLabel,newtweeninfo(0),{TextColor3=colorfromrgb(117,117,117)})
                        if kl_listen then kl_listen:Disconnect() end
                        menu.busy=false; utility.is_dragging_blocked=false
                    end
                    local function startKB()
                        menu.busy=true; utility.is_dragging_blocked=true
                        wait_fn()
                        utility.tween(KLabel,newtweeninfo(0),{TextColor3=colorfromrgb(200,0,0)})
                        kl_listen=utility.newConnection(uis.InputBegan,function(input,gpe)
                            if gpe then elemObj:setKey(nil); stopKB(); return end
                            local key=shortened_characters[input.UserInputType] and input.UserInputType or input.KeyCode
                            local blacklist={Enum.KeyCode.Escape,Enum.KeyCode.Tilde}
                            local valid=true
                            for _,bl in blacklist do if bl==key then valid=false break end end
                            elemObj:setKey(valid and key or nil)
                            stopKB()
                        end)
                    end

                    utility.newConnection(KLabel.InputBegan,function(input,gpe)
                        if gpe then return end
                        if input.UserInputType==Enum.UserInputType.MouseButton1 and not menu.busy then
                            startKB()
                        end
                    end)

                    if not ki.method_locked then
                        local kbClickConn=nil
                        utility.newConnection(KLabel.InputEnded,function(input,gpe)
                            if gpe then return end
                            if input.UserInputType==Enum.UserInputType.MouseButton2 then
                                if not menu.busy and menu.active_keybind~=elemObj then
                                    openKeybind(elemObj,ki,KLabel)
                                    kbClickConn=utility.newConnection(uis.InputBegan,function(inp2,gpe2)
                                        if gpe2 then return end
                                        if inp2.UserInputType==Enum.UserInputType.MouseButton1 then
                                            if not utility.isInFrame(KLabel,inp2.Position) and not utility.isInFrame(KeybindOpen,inp2.Position) then
                                                closeKeybind()
                                                if kbClickConn then kbClickConn:Disconnect() end
                                            end
                                        end
                                    end)
                                elseif menu.active_keybind==elemObj then
                                    closeKeybind(false)
                                    if kbClickConn then kbClickConn:Disconnect() end
                                end
                            end
                        end)
                    end

                    table.insert(elemObj.closing,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(KLabel,inf2,{TextTransparency=1})
                        if menu.active_keybind==elemObj then closeKeybind(true) end
                    end)
                    table.insert(elemObj.opening,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(KLabel,inf2,{TextTransparency=0})
                    end)

                    utility.newConnection(menu.on_load,function()
                        elemObj:setKey(flags[ki.flag].key)
                        elemObj:setMethod(flags[ki.flag].method)
                    end)
                end

                -- -----------------------------------------------
                -- TEXTBOX
                -- -----------------------------------------------
                if info.types.textbox then
                    local txi = info.types.textbox
                    flags[txi.flag]=""
                    Frame.Size=udim2new(1,0,0,20)
                    Label.Visible=false

                    local TXIn=utility.newObject("Frame",{BackgroundColor3=colorfromrgb(12,12,12),BorderSizePixel=0,Position=udim2new(0,19,0,0),Size=udim2new(0.72,0,0,20),BackgroundTransparency=1,Parent=Frame})
                    utility.newObject("UISizeConstraint",{MaxSize=vector2new(200,9e9),Parent=TXIn})
                    local TXIn2=utility.newObject("Frame",{BackgroundColor3=colorfromrgb(50,50,50),BorderSizePixel=0,Position=udim2new(0,1,0,1),Size=udim2new(1,-2,1,-2),BackgroundTransparency=1,Parent=TXIn})
                    local TXIn3=utility.newObject("Frame",{BackgroundColor3=colorfromrgb(24,24,24),BorderSizePixel=0,Position=udim2new(0,1,0,1),Size=udim2new(1,-2,1,-2),BackgroundTransparency=1,Parent=TXIn2})
                    local TBox=utility.newObject("TextBox",{BackgroundTransparency=1,BorderSizePixel=0,Position=udim2new(0,5,0,0),Size=udim2new(1,-5,1,0),ZIndex=2,FontFace=menu_font_bold,Text="_",TextColor3=colorfromrgb(208,208,208),TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,TextTransparency=1,Parent=TXIn3})

                    elemObj.onTextChange=Signal.new()

                    function elemObj:setText(text)
                        text=text or ""
                        if TBox.Text~=text then TBox.Text=text end
                        flags[txi.flag]=text
                        elemObj.onTextChange:Fire(text)
                    end

                    utility.newConnection(TBox.FocusLost,function()
                        TBox.TextColor3=colorfromrgb(208,208,208)
                        if TBox.Text=="" then TBox.Text="_" end
                    end)
                    utility.newConnection(TBox.Focused,function()
                        if menu.busy then TBox:ReleaseFocus(); return end
                        if TBox.Text=="_" then TBox.Text="" end
                        TBox.TextColor3=menu.accent_color
                    end)
                    utility.newConnection(TBox:GetPropertyChangedSignal("Text"),function()
                        if string.lower(TBox.Text)=="_" then elemObj:setText(nil); return end
                        elemObj:setText(TBox.Text)
                    end)

                    table.insert(elemObj.closing,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(TXIn,inf2,{BackgroundTransparency=1})
                        utility.tween(TXIn2,inf2,{BackgroundTransparency=1})
                        utility.tween(TXIn3,inf2,{BackgroundTransparency=1})
                        utility.tween(TBox,inf2,{TextTransparency=1})
                    end)
                    table.insert(elemObj.opening,function(bypass)
                        local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                        utility.tween(TXIn,inf2,{BackgroundTransparency=0})
                        utility.tween(TXIn2,inf2,{BackgroundTransparency=0})
                        utility.tween(TXIn3,inf2,{BackgroundTransparency=0})
                        utility.tween(TBox,inf2,{TextTransparency=0})
                    end)

                    utility.newConnection(menu.on_load,function()
                        elemObj:setText(flags[txi.flag])
                    end)
                end

                -- -----------------------------------------------
                -- Label open/close animations
                -- -----------------------------------------------
                table.insert(elemObj.closing,function(bypass)
                    local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                    utility.tween(Label,inf2,{TextTransparency=1})
                end)
                table.insert(elemObj.opening,function(bypass)
                    if not elemObj.visible then return end
                    local inf2=bypass and newtweeninfo(menu.animation_speed,Enum.EasingStyle.Sine) or tween_info
                    utility.tween(Label,inf2,{TextTransparency=0})
                end)

                for _,fn in elemObj.opening do utility.newConnection(menu.on_opening,fn) end
                for _,fn in elemObj.closing do utility.newConnection(menu.on_closing,fn) end

                elemObj.og_size=Frame.Size

                function elemObj:setVisible(bool, force)
                    local spd=force and 0 or menu.animation_speed
                    self.visible=bool
                    for _,fn in self[bool and "opening" or "closing"] do spawn_fn(fn,true) end
                    if bool then self.frame.Visible=true end
                    utility.tween(self.frame,newtweeninfo(menu.animation_speed,Enum.EasingStyle.Quad),{Size=bool and self.og_size or udim2new(1,0,0,-10)})
                    delay_fn(spd,function()
                        if not bool and not self.visible then self.frame.Visible=false end
                    end)
                end

                function elemObj:setText(text)
                    self.label.Text=text
                end

                self._elements[info.name]=elemObj
                return elemObj
            end

            return sectionObj
        end

        return tabObj
    end

    -- Tab switching
    function windowObj:_setTab(idx)
        local newTab=self._tabs[idx]
        local oldTab=self._tabs[self._activeTab or idx]
        local down=((self._activeTab or idx)-idx)<1
        local spd=menu.animation_speed

        self._activeTab=idx

        -- Close old sections
        for _,sec in oldTab._sections do
            spawn_fn(sec.on_closing,true)
        end
        -- Open new sections
        for _,sec in newTab._sections do
            spawn_fn(sec.on_opening,true)
        end

        -- Slide frames
        oldTab._frame.Visible=true
        newTab._frame.Visible=true
        utility.tween(oldTab._frame,newtweeninfo(spd+0.2,Enum.EasingStyle.Exponential,Enum.EasingDirection.Out),{Position=udim2new(0,5,down and -1 or 1,5)})
        newTab._frame.Position=udim2new(0,5,down and 1 or -1,5)
        utility.tween(newTab._frame,newtweeninfo(spd+0.2,Enum.EasingStyle.Exponential,Enum.EasingDirection.Out),{Position=udim2new(0,5,0,5)})

        -- Update button states
        for i,t in self._tabs do
            local active=i==idx
            utility.tween(t._icon,newtweeninfo(0),{ImageColor3=active and colorfromrgb(255,255,255) or colorfromrgb(109,109,109)})
            t._bottomBar.Visible=active
            t._topBar.Visible=active
            t._sideBar.Visible=not active
            t._button.BackgroundTransparency=active and 1 or 0
        end
    end

    function windowObj:getTab(idx)
        return self._tabs[idx]
    end

    function windowObj:setAccent(color)
        menu.accent_color=color
        menu.on_accent_change:Fire(color)
    end

    return windowObj
end

-- ============================================================
-- UNLOAD
-- ============================================================
function SkeetCCUI.unload()
    for flag,value in pairs(flags) do
        if typeof(value)=="boolean" then flags[flag]=false end
    end
    pcall(function() menu.on_load:Fire() end)
    for _,conn in utility.connections do
        pcall(function() conn:Disconnect() end)
    end
    pcall(function() _screenGui:Destroy() end)
end

-- ============================================================
-- FLAGS ACCESS
-- ============================================================
function SkeetCCUI.getFlag(flag)
    return flags[flag]
end

function SkeetCCUI.getFlags()
    return flags
end

return SkeetCCUI
