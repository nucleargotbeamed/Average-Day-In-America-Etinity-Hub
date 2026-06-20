if not LPH_OBFUSCATED then
	getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end
	getfenv().LPH_JIT_MAX = function(...) return ... end
	getfenv().LPH_JIT = function(...) return ... end
	getfenv().LPH_ENCSTR = function(...) return ... end
end

if getgenv().unload_mangosense then
	getgenv().unload_mangosense()
	task.wait(1)
end

local is_solara = hookmetamethod == nil or getgenv().Xeno

LPH_NO_VIRTUALIZE(function()
	local exec = identifyexecutor()
	if is_solara then
		getfenv().gethiddenproperty = function() return false end
		getfenv().setfflag = function() end
		getfenv().cloneref = function(v) return v end
	else
		if string.find(exec, "macsploit") or string.find(exec, "Rebel") then
			local old = getconnections
			local old_connections = {}
			getgenv().getconnections = function(...)
				local old = old(...)
				local new = {}
				for i = 1, #old do
					local connection = old[i]
					local func = connection.Function
					if not old_connections[func] then
						new[#new+1] = connection
						old_connections[func] = 1
					end
				end
				return new
			end
		else
			loadstring(game:HttpGet(string.find(exec, "Syn") and "https://raw.githubusercontent.com/jujudotlol/jujudotlol.github.io/main/solara_drawing.lua" or "https://raw.githubusercontent.com/jujudotlol/jujudotlol.github.io/main/wave_drawing.lua"))()
		end
	end
end)()

local signal = {}
signal.__index = signal

function signal.new()
	return setmetatable({connections = {}}, signal)
end

function signal:Fire(...)
	for _, callback in self.connections do
		spawn(callback, ...)
	end
end

function signal:Connect(callback)
	local connection = {}
	local connections = self.connections
	local index = #connections + 1
	connections[index] = callback
	function connection:Disconnect()
		connections[index] = nil
		setmetatable(connection, nil)
	end
	return connection
end

local uis = cloneref(game:GetService("UserInputService"))
local getMouseLocation = uis.GetMouseLocation
local tws = cloneref(game:GetService("TweenService"))
local plrs = cloneref(game:GetService("Players"))
local ts = cloneref(game:GetService("TextService"))
local hs = cloneref(game:GetService("HttpService"))
local cg = gethui and gethui() or cloneref(game:GetService("CoreGui"))
local rs = cloneref(game:GetService("RunService"))
local lighting = game:GetService("Lighting")
local tps = cloneref(game:GetService("TeleportService"))
local reps = cloneref(game:GetService("ReplicatedStorage"))
local is = cloneref(game:GetService("InsertService"))
local workspace = workspace

local clamp = math.clamp
local floor = math.floor
local udim2new = UDim2.new
local vector2new = Vector2.new
local colorfromrgb = Color3.fromRGB
local newtweeninfo = TweenInfo.new
local wait = task.wait
local spawn = task.spawn
local lower = string.lower
local delay = task.delay
local destroy = workspace.Destroy
local findfirstchild = workspace.FindFirstChild

local getconnections = is_solara and function(...) return {} end or getconnections
getgenv().hookmetamethod = is_solara and function(...) return {} end or hookmetamethod

local lplr = plrs.LocalPlayer
local mouse = lplr:GetMouse()
local camera = workspace.CurrentCamera

local utility = {connections = {}, is_dragging_blocked = false}

do
	local newInstance = Instance.new
	local keybindBlacklist = {Enum.KeyCode.Escape, Enum.KeyCode.Tilde}

	utility.lerp = LPH_NO_VIRTUALIZE(function(initial, new, elapsed)
		return initial + (new - initial) * elapsed
	end)

	utility.newConnection = function(signal, callback)
		local connection = signal:Connect(callback)
		utility.connections[#utility.connections+1] = connection
		return connection
	end

	utility.copyTable = function(original)
		local copy = {}
		for _, v in pairs(original) do
			if type(v) == "table" then
				v = utility.copyTable(v)
			end
			copy[_] = v
		end
		return copy
	end

	utility.round = LPH_NO_VIRTUALIZE(function(num, decimals)
		local mult = 10^(decimals or 0)
		return floor(num * mult + 0.5) / mult
	end)

	utility.find = LPH_NO_VIRTUALIZE(function(array, find)
		for _, obj in array do
			if find == obj then return _ end
		end
	end)

	utility.insert = LPH_NO_VIRTUALIZE(function(array, _)
		local new = #array+1
		array[new] = _
		return new
	end)

	utility.isValidKey = function(keycode)
		if utility.find(keybindBlacklist, keycode) then
			return false
		end
		return true
	end

	utility.remove = function(array, _, z)
		local pos = utility.find(array, _) or z
		if not pos then return end
		for i = pos, #array - 1 do
			array[i] = array[i + 1]
		end
		array[#array] = nil
	end

	local createTween = tws.Create
	utility.tween = LPH_NO_VIRTUALIZE(function(...)
		createTween(tws, ...):Play()
	end)

	utility.setDraggable = LPH_NO_VIRTUALIZE(function(object)
		local drag_connection = nil
		local drag_stop_connection = nil
		utility.newConnection(object.InputBegan, function(input, gpe)
			if gpe then return end
			if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not utility.is_dragging_blocked then
				local window_start_x_position = object.Position.X.Scale
				local window_start_y_position = object.Position.Y.Scale
				local mouse_start_position = (getMouseLocation(uis)/camera.ViewportSize)
				local mouse_start_x_position = mouse_start_position.X
				local mouse_start_y_position = mouse_start_position.Y
				drag_connection = utility.newConnection(mouse.Move, function()
					local mouse_position = (getMouseLocation(uis)/camera.ViewportSize)
					object.Position = UDim2.new(window_start_x_position - (mouse_start_x_position - mouse_position.X), 0, window_start_y_position - (mouse_start_y_position - mouse_position.Y), 0)
				end)
				drag_stop_connection = utility.newConnection(uis.InputEnded, function(input, gpe)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						drag_stop_connection:Disconnect()
						drag_connection:Disconnect()
					end
				end)
			end
		end)
	end)

	utility.isInFrame = function(object, pos)
		local abs_pos = object.AbsolutePosition
		local abs_size = object.AbsoluteSize
		local x = abs_pos.Y <= pos.Y and pos.Y <= abs_pos.Y + abs_size.Y
		local y = abs_pos.X <= pos.X and pos.X <= abs_pos.X + abs_size.X
		return (x and y)
	end

	utility.newObject = function(class, properties)
		local object = newInstance(class)
		for property, value in properties do
			object[property] = value
		end
		object.Name = properties.Name or ""
		return object
	end
end

local config_location = "mangosense"
if not isfolder("mangosense") then makefolder("mangosense") end
if not isfolder("mangosense/configs") then makefolder("mangosense/configs") end
if not isfolder("mangosense/addons") then makefolder("mangosense/addons") end
if not isfolder("mangosense/assets") then makefolder("mangosense/assets") end

local menu = {
	on_closing = signal.new(),
	on_opening = signal.new(),
	on_tab_switch = signal.new(),
	on_load = signal.new(),
	toggle = "DELETE",
	busy = false,
	is_open = true,
	flags = {loaded_scripts = {}},
	active_keybind = nil,
	active_colorpicker = nil,
	accent_color = colorfromrgb(153, 196, 39),
	on_accent_change = signal.new(),
	blocked = false,
	animation_speed = 0.15,
	keybinds = {}
}

local _screenGui = nil
local flags = menu.flags
local isInFrame = utility.isInFrame
local newObject = utility.newObject
local find = utility.find
local insert = utility.insert
local remove = utility.remove
local round = utility.round
local tween = utility.tween
local tween_info = newtweeninfo(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

do 
	local window = {}
	window.__index = window
	local tab = {}
	tab.__index = tab
	local section = {}
	section.__index = section
	local element = {}
	element.__index = element

	utility.saveConfig = LPH_NO_VIRTUALIZE(function(name)
		local new_flags = utility.copyTable(flags)
		for flag, info in new_flags do
			if typeof(info) == "Color3" then
				new_flags[flag] = {utility.round(info.R*255, 0), utility.round(info.G*255, 0), utility.round(info.B*255, 0)}
			elseif typeof(info) == "table" and info.key then
				new_flags[flag].key = info.key.Name
			end
		end
		writefile(config_location.."/configs/"..name..".cfg", hs:JSONEncode(new_flags))
	end)

	utility.convertConfig = LPH_NO_VIRTUALIZE(function(name)
		local config = isfile(config_location.."/configs/"..name..".cfg")
		if not config then return end
		config = readfile(config_location.."/configs/"..name..".cfg")
		local config = hs:JSONDecode(config)
		if config then
			for flag, info in config do
				if typeof(info) == "table" then
					if typeof(info[1]) == "number" then
						if info[3] then
							config[flag] = colorfromrgb(info[1], info[2], info[3])
						else
							config[flag] = info
						end
					elseif info.key then
						config[flag].key = info.key:find("Mouse") and Enum.UserInputType[info.key] or Enum.KeyCode[info.key]
					end
				end
			end
		end
		return config
	end)

	utility.loadConfig = LPH_NO_VIRTUALIZE(function(config)
		if not config then return end
		for flag, info in config do
			menu.flags[flag] = config[flag]
		end
		return config
	end)

	utility.getConfigList = LPH_NO_VIRTUALIZE(function()
		local list = {}
		for _, config in listfiles(config_location.."/configs/") do
			utility.insert(list, string.sub(config, #(config_location.."/configs/")+1, #config-4))
		end
		return list
	end)

	utility.getScriptList = LPH_NO_VIRTUALIZE(function()
		local list = {}
		for _, config in listfiles(config_location.."/addons/") do
			utility.insert(list, string.sub(config, #(config_location.."/addons/")+1, #config-4))
		end
		return list
	end)

	local menu_font = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	local menu_font_bold = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

	local shortened_characters = {
		[Enum.KeyCode.LeftShift] = "LSHF",
		[Enum.KeyCode.RightShift] = "RSHF",
		[Enum.UserInputType.MouseButton1] = "M1",
		[Enum.UserInputType.MouseButton2] = "M2",
		[Enum.UserInputType.MouseButton3] = "M3",
		[Enum.KeyCode.Delete] = "DEL",
		[Enum.KeyCode.Insert] = "INS",
		[Enum.KeyCode.PageUp] = "PGUP",
		[Enum.KeyCode.PageDown] = "PGDW",
		[Enum.KeyCode.LeftControl] = "LCTR",
		[Enum.KeyCode.RightControl] = "RCTR",
		[Enum.KeyCode.LeftAlt] = "LALT",
		[Enum.KeyCode.RightAlt] = "RALT",
		[Enum.KeyCode.CapsLock] = "CAPS",
		[Enum.KeyCode.Space] = "SPC",
		[Enum.KeyCode.Backspace] = "BSPC",
		[Enum.KeyCode.ScrollLock] = "SLCK",
	}

	_screenGui = newObject("ScreenGui", {ResetOnSpawn = false, Parent = cg})

	local loaderContainer = Instance.new("Frame")
	loaderContainer.BackgroundTransparency = 1
	loaderContainer.Size = udim2new(1,0,1,0)
	loaderContainer.ZIndex = 497
	loaderContainer.Parent = _screenGui

	newObject("Frame", {BackgroundColor3 = colorfromrgb(0,0,0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Size = udim2new(1,0,1,0), ZIndex = 498, Parent = loaderContainer})

	newObject("ImageLabel", {AnchorPoint = vector2new(0.5,0.5), BackgroundTransparency = 1, BorderSizePixel = 0, ImageColor3 = colorfromrgb(0,0,0), ImageTransparency = 0.5, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(21,21,79,79), Image = "rbxassetid://18245826428", Position = udim2new(0.5,0,0.5,0), Size = udim2new(0,640,0,450), ZIndex = 499, Parent = loaderContainer})

	local loaderBorder = newObject("Frame", {AnchorPoint = vector2new(0.5,0.5), BackgroundColor3 = colorfromrgb(60,60,60), BorderSizePixel = 0, Position = udim2new(0.5,0,0.5,0), Size = udim2new(0,570,0,400), ZIndex = 500, Parent = loaderContainer})
	local loaderBorder2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderSizePixel = 0, Position = udim2new(0,2,0,2), Size = udim2new(1,-4,1,-4), ZIndex = 501, Parent = loaderBorder})
	local loaderBg = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), Image = "rbxassetid://15453092054", ScaleType = Enum.ScaleType.Tile, TileSize = udim2new(0,4,0,548), ClipsDescendants = true, ZIndex = 502, Parent = loaderBorder2})
	local loaderAccent = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,0,2), ZIndex = 503, Image = "rbxassetid://15453122383", Parent = loaderBg})
	newObject("Frame", {BackgroundColor3 = colorfromrgb(6,6,6), BorderSizePixel = 0, Position = udim2new(0,0,1,0), Size = udim2new(1,0,0,1), ZIndex = 504, Parent = loaderAccent})

	local gamePanel = newObject("Frame", {BackgroundColor3 = colorfromrgb(22,22,22), BorderSizePixel = 0, Position = udim2new(0,10,0,14), Size = udim2new(0,318,0,168), ZIndex = 503, Parent = loaderBg})
	newObject("Frame", {BackgroundColor3 = colorfromrgb(28,28,28), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), ZIndex = 503, Parent = gamePanel})

	local gameIconOuter = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderSizePixel = 0, Position = udim2new(0,8,0,8), Size = udim2new(0,60,0,60), ZIndex = 504, Parent = gamePanel})
	local gameIconImg = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(153,196,39), BackgroundTransparency = 0, BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), Image = "rbxthumb://type=GameIcon&id="..tostring(game.GameId).."&w=150&h=150", ZIndex = 505, Parent = gameIconOuter})
	newObject("TextLabel", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = udim2new(1,0,1,0), FontFace = menu_font_bold, Text = string.upper(string.sub(game.Name,1,2)), TextColor3 = colorfromrgb(12,12,12), TextSize = 20, ZIndex = 504, Parent = gameIconOuter})

	newObject("TextLabel", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(0,78,0,12), Size = udim2new(1,-86,0,20), FontFace = menu_font_bold, Text = game.Name, TextColor3 = colorfromrgb(153,196,39), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 504, Parent = gamePanel})
	newObject("TextLabel", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(0,78,0,34), Size = udim2new(1,-86,0,16), FontFace = menu_font, Text = "Updated " .. os.date("%Y/%m/%d %H:%M"), TextColor3 = colorfromrgb(140,140,140), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 504, Parent = gamePanel})

	newObject("TextLabel", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(0,338,0,14), Size = udim2new(1,-348,0,18), FontFace = menu_font_bold, Text = "Options", TextColor3 = colorfromrgb(198,198,198), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 503, Parent = loaderBg})

	local function makeBtn(yPos, label)
		local border = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderSizePixel = 0, Position = udim2new(0,338,0,yPos), Size = udim2new(1,-348,0,36), ZIndex = 503, Parent = loaderBg})
		local i2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(50,50,50), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), ZIndex = 504, Parent = border})
		local i3 = newObject("Frame", {BackgroundColor3 = colorfromrgb(34,34,34), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), ZIndex = 505, Parent = i2})
		newObject("UIGradient", {Color = ColorSequence.new{ColorSequenceKeypoint.new(0,colorfromrgb(255,255,255)), ColorSequenceKeypoint.new(1,colorfromrgb(227,227,227))}, Rotation = 90, Parent = i3})
		newObject("TextLabel", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = udim2new(1,0,1,0), FontFace = menu_font_bold, Text = label, TextColor3 = colorfromrgb(212,212,212), TextSize = 13, ZIndex = 506, Parent = i3})
		return border, i3
	end

	local loadBorder, loadI3 = makeBtn(38, "Load")
	local exitBorder, exitI3 = makeBtn(84, "Exit")

	newObject("Frame", {BackgroundColor3 = colorfromrgb(30,30,30), BorderSizePixel = 0, Position = udim2new(0,10,0,192), Size = udim2new(1,-20,0,1), ZIndex = 503, Parent = loaderBg})
	newObject("TextLabel", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(0,10,0,198), Size = udim2new(1,-20,0,18), FontFace = menu_font_bold, Text = "Status", TextColor3 = colorfromrgb(198,198,198), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 503, Parent = loaderBg})

	local statusBox = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderSizePixel = 0, Position = udim2new(0,10,0,220), Size = udim2new(1,-20,0,158), ZIndex = 503, Parent = loaderBg})
	local statusInner = newObject("Frame", {BackgroundColor3 = colorfromrgb(20,20,20), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), ZIndex = 504, Parent = statusBox})

	local function statusLine(y, text, color)
		newObject("TextLabel", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(0,6,0,y), Size = udim2new(1,-12,0,16), FontFace = menu_font, Text = text, TextColor3 = color or colorfromrgb(198,198,198), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 505, Parent = statusInner})
	end

	statusLine(6, "Connected")
	statusLine(22, "Welcome back,")
	statusLine(38, "Added " .. game.Name .. " (30 days remaining)")

	local function bHover(i) tws:Create(i, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {BackgroundColor3 = colorfromrgb(39,39,39)}):Play() end
	local function bLeave(i) tws:Create(i, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {BackgroundColor3 = colorfromrgb(34,34,34)}):Play() end
	local function bPress(i) tws:Create(i, TweenInfo.new(0, Enum.EasingStyle.Sine), {BackgroundColor3 = colorfromrgb(28,28,28)}):Play() end

	loadBorder.MouseEnter:Connect(function() bHover(loadI3) end)
	loadBorder.MouseLeave:Connect(function() bLeave(loadI3) end)
	loadBorder.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then bPress(loadI3) end end)
	loadBorder.InputEnded:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		bLeave(loadI3)
		loaderContainer:Destroy()
	end)

	exitBorder.MouseEnter:Connect(function() bHover(exitI3) end)
	exitBorder.MouseLeave:Connect(function() bLeave(exitI3) end)
	exitBorder.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then bPress(exitI3) end end)
	exitBorder.InputEnded:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		_screenGui:Destroy()
	end)

	repeat task.wait(0.05) until loaderContainer.Parent == nil

	local KeybindOpen = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,0,0), Size = udim2new(0,100,0,0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 25, BackgroundTransparency = 1, Visible = false, Parent = _screenGui})
	local KeybindOpenInside2 = newObject("Frame", {Parent = KeybindOpen, BackgroundColor3 = colorfromrgb(35,35,35), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,0,0), BackgroundTransparency = 1, ZIndex = 25})
	local UIListLayout = newObject("UIListLayout", {HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = KeybindOpenInside2})
	local AlwaysOn = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(25,25,25), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,0,17), ZIndex = 25, FontFace = menu_font, Text = "    Always on", TextColor3 = colorfromrgb(205,205,205), TextSize = 13, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Parent = KeybindOpenInside2})
	local OnHotkeyLabel = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(25,25,25), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,0,17), ZIndex = 25, FontFace = menu_font, Text = "    On hotkey", TextColor3 = colorfromrgb(205,205,205), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, Parent = KeybindOpenInside2})
	local ToggleLabel = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(25,25,25), BackgroundTransparency = 1, TextTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,0,17), ZIndex = 25, FontFace = menu_font, Text = "    Toggle", TextColor3 = colorfromrgb(205,205,205), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = KeybindOpenInside2})

	local counter = 0
	for _, object in KeybindOpenInside2:GetChildren() do
		if object:IsA("TextLabel") then
			counter+=1
			local count = counter
			object.Name = count
			utility.newConnection(object.MouseEnter, function()
				if not menu.active_keybind then return end
				object.BackgroundTransparency = 0
				if flags[menu.active_keybind.flag].method == count then return end
				object.FontFace = menu_font_bold
			end)
			utility.newConnection(object.MouseLeave, function()
				if not menu.active_keybind then return end
				object.BackgroundTransparency = 1
				if flags[menu.active_keybind.flag].method == count then return end
				object.FontFace = menu_font
			end)
			utility.newConnection(object.InputBegan, function(input, gpe)
				if not menu.active_keybind then return end
				if gpe then return end
				if flags[menu.active_keybind.flag].method == count then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					menu.active_keybind:setMethod(count, true, true)
				end
			end)
		end
	end

	local ColorCopy = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(0,100,0,60), ZIndex = 250, BackgroundTransparency = 1, ClipsDescendants = true, Visible = false, Parent = _screenGui})
	local ColorCopyInside = newObject("Frame", {BackgroundColor3 = colorfromrgb(35,35,35), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(0,98,0,58), Position = udim2new(0,1,0,1), ZIndex = 251, BackgroundTransparency = 1, Parent = ColorCopy})
	newObject("UIListLayout", {HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = ColorCopyInside})
	local CopyLabel = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(25,25,25), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,0,20), ZIndex = 252, FontFace = menu_font, Text = "   Copy", TextColor3 = colorfromrgb(208,208,208), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, Parent = ColorCopyInside})
	local PasteLabel = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(25,25,25), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,0,20), ZIndex = 252, FontFace = menu_font, Text = "   Paste", TextColor3 = colorfromrgb(208,208,208), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, Parent = ColorCopyInside})
	local ResetLabel = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(25,25,25), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,0,20), ZIndex = 252, FontFace = menu_font, Text = "   Reset", TextColor3 = colorfromrgb(208,208,208), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, Parent = ColorCopyInside})

	local clickOutConnection2 = nil

	local function closeColorCopy(force)
		local speed = force and 0 or menu.animation_speed
		local info = newtweeninfo(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		tween(ColorCopy, info, {BackgroundTransparency = 1})
		tween(ColorCopyInside, info, {BackgroundTransparency = 1})
		tween(CopyLabel, info, {TextTransparency = 1, BackgroundTransparency = 1})
		tween(PasteLabel, info, {TextTransparency = 1, BackgroundTransparency = 1})
		tween(ResetLabel, info, {TextTransparency = 1, BackgroundTransparency = 1})
		for _, label in ColorCopyInside:GetChildren() do
			if label.ClassName == "UIListLayout" then continue end
			label.FontFace = menu_font
		end
		delay(speed, function()
			if menu.active_colorcopy == nil then
				menu.busy = false
				utility.is_dragging_blocked = false
				ColorCopy.Visible = false
			end
		end)
		clickOutConnection2:Disconnect()
		menu.active_colorcopy = nil
	end

	local function openColorCopy(new_element, _info, ColorBox)
		local speed = menu.animation_speed
		local info = newtweeninfo(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local newPosition = ColorBox.AbsolutePosition
		ColorCopy.Position = udim2new(0, newPosition.X - 101, 0, newPosition.Y - 1)
		ColorCopy.Visible = true
		menu.active_colorcopy = new_element
		tween(ColorCopy, info, {BackgroundTransparency = 0})
		tween(ColorCopyInside, info, {BackgroundTransparency = 0})
		tween(CopyLabel, info, {TextTransparency = 0, BackgroundTransparency = 1})
		tween(PasteLabel, info, {TextTransparency = 0, BackgroundTransparency = 1})
		tween(ResetLabel, info, {TextTransparency = 0, BackgroundTransparency = 1})
		clickOutConnection2 = utility.newConnection(uis.InputBegan, LPH_NO_VIRTUALIZE(function(input, gpe)
			if gpe then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local pos = input.Position
				if not isInFrame(ColorCopy, pos) then closeColorCopy() end
			end
		end), true)
		menu.busy = true
		utility.is_dragging_blocked = true
		task.wait()
	end

	utility.newConnection(CopyLabel.InputBegan, function(input, gpe)
		if gpe then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local colorpicker = menu.active_colorcopy.colorpicker
			menu.copied_transparency = flags[colorpicker.transparency_flag]
			menu.copied_color = flags[colorpicker.flag]
			closeColorCopy()
		end
	end)

	utility.newConnection(ResetLabel.InputBegan, function(input, gpe)
		if gpe then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local colorpicker = menu.active_colorcopy.colorpicker
			menu.active_colorcopy:setColor(colorpicker.default or colorfromrgb(255,255,255), colorpicker.default_transparency or 0, true)
			closeColorCopy()
		end
	end)

	utility.newConnection(PasteLabel.InputBegan, function(input, gpe)
		if gpe then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if menu.copied_color == nil then return end
			menu.active_colorcopy:setColor(menu.copied_color, menu.copied_transparency, true)
			closeColorCopy()
		end
	end)

	for _, label in ColorCopyInside:GetChildren() do
		if label.ClassName == "UIListLayout" then continue end
		utility.newConnection(label.MouseEnter, function()
			label.BackgroundTransparency = 0
			label.FontFace = menu_font_bold
		end)
		utility.newConnection(label.MouseLeave, function()
			label.BackgroundTransparency = 1
			label.FontFace = menu_font
		end)
	end

	local ColorpickerOpen = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(0,180,0,175), ZIndex = 250, BackgroundTransparency = 1, Visible = false, Parent = _screenGui})
	local Inside2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(60,60,60), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), BackgroundTransparency = 1, ZIndex = 250, Parent = ColorpickerOpen})
	local Inside3 = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), BackgroundTransparency = 1, Size = udim2new(1,-2,1,-2), ZIndex = 250, Parent = Inside2})
	local SaturationImage = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(170,0,0), BorderColor3 = colorfromrgb(13,13,13), Position = udim2new(0,3,0,3), Size = udim2new(0,150,0,150), BackgroundTransparency = 1, ImageTransparency = 1, ZIndex = 250, Image = "rbxassetid://13966897785", Parent = Inside3})
	local SaturationMover = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, BackgroundTransparency = 1, ImageTransparency = 1, Size = udim2new(0,4,0,4), ZIndex = 250, Image = "http://www.roblox.com/asset/?id=17819434984", Parent = SaturationImage})
	local HueFrame = newObject("Frame", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(13,13,13), Position = udim2new(1,-18,0,3), Size = udim2new(0,15,0,150), BackgroundTransparency = 1, ZIndex = 250, Parent = Inside3})
	local UIGradient = newObject("UIGradient", {Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, colorfromrgb(170,0,0)), ColorSequenceKeypoint.new(0.15, colorfromrgb(255,255,0)), ColorSequenceKeypoint.new(0.30, colorfromrgb(0,255,0)), ColorSequenceKeypoint.new(0.45, colorfromrgb(0,255,255)), ColorSequenceKeypoint.new(0.60, colorfromrgb(0,0,255)), ColorSequenceKeypoint.new(0.75, colorfromrgb(175,0,255)), ColorSequenceKeypoint.new(1.00, colorfromrgb(170,0,0))}, Rotation = 90, Parent = HueFrame})
	local HueMover = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, BackgroundTransparency = 1, ImageTransparency = 1, Size = udim2new(1,0,0,4), ZIndex = 250, Image = "http://www.roblox.com/asset/?id=17819584226", Parent = HueFrame})
	local TransparencyImage = newObject("ImageLabel", {BorderColor3 = colorfromrgb(13,13,13), Position = udim2new(0,3,1,-13), Size = udim2new(0,150,0,10), ImageTransparency = 0, ZIndex = 250, ScaleType = Enum.ScaleType.Tile, Image = "rbxassetid://18249241978", BackgroundTransparency = 1, TileSize = udim2new(0,12,0,12), Parent = Inside3})
	local TransparencyFrame = newObject("Frame", {Position = udim2new(0,0,0,0), Size = udim2new(1,0,1,0), ZIndex = 251, Parent = TransparencyImage})
	local UIGradient2 = newObject("UIGradient", {Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0,0.1), NumberSequenceKeypoint.new(1,0.8)}, Rotation = 180, Parent = TransparencyFrame})
	local TransparencyMover = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,-4,0,0), Size = udim2new(0,4,1,0), ImageTransparency = 1, ZIndex = 250, Image = "http://www.roblox.com/asset/?id=17819483422", Parent = TransparencyFrame})

	local hue, saturation, value = 0, 0, 255
	local color = colorfromrgb(255,255,255)
	local transparency = 0
	local dragging_sat, dragging_hue, dragging_trans = false, false, false
	local mouse_connection = nil

	local function update_sv(val, sat, do_tween)
		saturation = sat
		value = val 
		color = Color3.fromHSV(hue/360, saturation/255, value/255)
		tween(SaturationMover, newtweeninfo(do_tween and menu.animation_speed or 0, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Position = udim2new(clamp(sat/255,0,0.98),0,1 - clamp(val/255,0.02,1),0)})
		TransparencyFrame.BackgroundColor3 = color
		menu.active_colorpicker:setColor(color, transparency, true)
		menu.active_colorpicker.onColorChange:Fire(color, transparency)
	end

	local function update_hue(hue2, do_tween)
		tween(HueMover, newtweeninfo(do_tween and menu.animation_speed or 0, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Position = udim2new(0,0,clamp(hue2/360,0,0.99),0)})
		SaturationImage.BackgroundColor3 = Color3.fromHSV(hue2/360,1,1)
		color = Color3.fromHSV(hue2/360, saturation/255, value/255)
		hue = hue2
		TransparencyFrame.BackgroundColor3 = color
		menu.active_colorpicker:setColor(color, transparency, true)
		menu.active_colorpicker.onColorChange:Fire(color, transparency)
	end

	local function update_transparency(o, do_tween)
		tween(TransparencyMover, newtweeninfo(do_tween and menu.animation_speed or 0, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Position = udim2new(clamp(1 - o,0,0.98),0,0,0)})
		transparency = o
		local color2 = 155 * (1-(transparency*0.5))
		UIGradient2.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, colorfromrgb(color2,color2,color2)), ColorSequenceKeypoint.new(1.00, colorfromrgb(color2,color2,color2))}
		menu.active_colorpicker:setColor(color, transparency, true)
		menu.active_colorpicker.onColorChange:Fire(color, transparency)
	end

	utility.newConnection(SaturationImage.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			utility.is_dragging_blocked = true
			local xdistance = clamp((mouse.X - SaturationImage.AbsolutePosition.X)/SaturationImage.AbsoluteSize.X, 0, 1)
			local ydistance = 1 - clamp((mouse.Y - SaturationImage.AbsolutePosition.Y)/SaturationImage.AbsoluteSize.Y, 0, 1)
			local sat = 255 * xdistance
			local val = 255 * ydistance
			update_sv(val, sat, true)
			dragging_sat = true
			mouse_connection = utility.newConnection(mouse.Move, LPH_NO_VIRTUALIZE(function()
				local xdistance = clamp((mouse.X - SaturationImage.AbsolutePosition.X)/SaturationImage.AbsoluteSize.X, 0, 1)
				local ydistance = 1 - clamp((mouse.Y - SaturationImage.AbsolutePosition.Y)/SaturationImage.AbsoluteSize.Y, 0, 1)
				local sat = 255 * xdistance
				local val = 255 * ydistance
				update_sv(val, sat)
			end), true)
		end
	end)

	utility.newConnection(SaturationImage.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging_sat then
			dragging_sat = false
			mouse_connection:Disconnect()
		end
	end)

	utility.newConnection(HueFrame.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			utility.is_dragging_blocked = true
			local xdistance = clamp((mouse.Y - HueFrame.AbsolutePosition.Y)/HueFrame.AbsoluteSize.Y, 0, 1)
			local hue = 360 * xdistance
			update_hue(hue, true)
			dragging_hue = true
			mouse_connection = utility.newConnection(mouse.Move, LPH_NO_VIRTUALIZE(function()
				local xdistance = clamp((mouse.Y - HueFrame.AbsolutePosition.Y)/HueFrame.AbsoluteSize.Y, 0, 1)
				local hue = 360 * xdistance
				update_hue(hue)
			end), true)
		end
	end)

	utility.newConnection(HueFrame.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging_hue then
			dragging_hue = false
			mouse_connection:Disconnect()
		end
	end)

	utility.newConnection(TransparencyFrame.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			utility.is_dragging_blocked = true
			local xdistance = clamp((mouse.X - TransparencyFrame.AbsolutePosition.X)/TransparencyFrame.AbsoluteSize.X, 0, 1)
			update_transparency(1 - 1 * xdistance, true)
			dragging_trans = true
			mouse_connection = utility.newConnection(mouse.Move, function()
				local xdistance = clamp((mouse.X - TransparencyFrame.AbsolutePosition.X)/TransparencyFrame.AbsoluteSize.X, 0, 1)
				update_transparency(1 - 1 * xdistance)
			end, true)
		end
	end)

	utility.newConnection(TransparencyFrame.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging_trans then
			dragging_trans = false
			mouse_connection:Disconnect()
		end
	end)

	local clickOutConnection = nil

	local function closeColorpicker(force)
		local speed = force and 0 or menu.animation_speed
		local info = newtweeninfo(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		tween(ColorpickerOpen, info, {BackgroundTransparency = 1})
		tween(Inside2, info, {BackgroundTransparency = 1})
		tween(Inside3, info, {BackgroundTransparency = 1})
		tween(SaturationImage, info, {ImageTransparency = 1, BackgroundTransparency = 1})
		tween(SaturationMover, info, {ImageTransparency = 1, BackgroundTransparency = 1})
		tween(HueFrame, info, {BackgroundTransparency = 1})
		tween(HueMover, info, {ImageTransparency = 1, BackgroundTransparency = 1})
		tween(TransparencyFrame, info, {BackgroundTransparency = 1})
		tween(TransparencyMover, info, {ImageTransparency = 1, BackgroundTransparency = 1})
		tween(TransparencyImage, info, {ImageTransparency = 1})
		delay(speed, function()
			if menu.active_colorpicker == nil then
				menu.busy = false
				utility.is_dragging_blocked = false
				ColorpickerOpen.Visible = false
			end
		end)
		clickOutConnection:Disconnect()
		menu.active_colorpicker = nil
	end

	local function openColorpicker(new_element, _info, ColorBox)
		local speed = menu.animation_speed
		local info = newtweeninfo(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local newPosition = ColorBox.AbsolutePosition
		ColorpickerOpen.Position = udim2new(0, newPosition.X, 0, newPosition.Y + 2 + ColorBox.AbsoluteSize.Y)
		ColorpickerOpen.Visible = true
		menu.active_colorpicker = new_element
		tween(ColorpickerOpen, info, {BackgroundTransparency = 0})
		tween(Inside2, info, {BackgroundTransparency = 0})
		tween(Inside3, info, {BackgroundTransparency = 0})
		tween(SaturationImage, info, {ImageTransparency = 0, BackgroundTransparency = 0})
		tween(SaturationMover, info, {ImageTransparency = 0, BackgroundTransparency = 0.6})
		tween(HueFrame, info, {BackgroundTransparency = 0})
		tween(HueMover, info, {ImageTransparency = 0.2, BackgroundTransparency = 0.5})
		tween(TransparencyFrame, info, {BackgroundTransparency = 0})
		tween(TransparencyMover, info, {ImageTransparency = 0, BackgroundTransparency = 0.5})
		tween(TransparencyImage, info, {ImageTransparency = 0})
		new_element:setColor(flags[_info.flag], flags[_info.transparency_flag])
		clickOutConnection = utility.newConnection(uis.InputBegan, LPH_NO_VIRTUALIZE(function(input, gpe)
			if gpe then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local pos = input.Position
				if not isInFrame(ColorBox, pos) and not isInFrame(ColorpickerOpen, pos) then closeColorpicker() end
			end
		end), true)
		menu.busy = true
		utility.is_dragging_blocked = true
		task.wait()
	end

	local function closeKeybind(force)
		local speed = force and 0 or menu.animation_speed
		local info = newtweeninfo(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		tween(KeybindOpen, info, {BackgroundTransparency = 1})
		tween(KeybindOpenInside2, info, {BackgroundTransparency = 1})
		tween(ToggleLabel, info, {TextTransparency = 1})
		tween(AlwaysOn, info, {TextTransparency = 1})
		tween(OnHotkeyLabel, info, {TextTransparency = 1})
		delay(speed, function()
			utility.is_dragging_blocked = false
			if menu.active_keybind == nil then
				menu.busy = false
				KeybindOpen.Visible = false
			end
		end)
		menu.active_keybind = nil
	end

	local function openKeybind(new_element, _info, KeybindLabel)
		local speed = menu.animation_speed
		local info = newtweeninfo(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local newPosition = KeybindLabel.AbsolutePosition
		KeybindOpen.Position = udim2new(0, newPosition.X - 102, 0, newPosition.Y)
		KeybindOpen.Visible = true
		tween(KeybindOpen, info, {BackgroundTransparency = 0})
		tween(KeybindOpenInside2, info, {BackgroundTransparency = 0})
		tween(ToggleLabel, info, {TextTransparency = 0})
		tween(AlwaysOn, info, {TextTransparency = 0})
		tween(OnHotkeyLabel, info, {TextTransparency = 0})
		menu.active_keybind = new_element
		new_element:setMethod(flags[_info.flag].method, false, true)
		menu.busy = true
		utility.is_dragging_blocked = true
	end

	function menu:set_accent_color(color)
		menu.accent_color = color
		menu.on_accent_change:Fire(color)
	end

	function menu:init(tabs, selected_tab)
		local Border = newObject("Frame", {BackgroundColor3 = colorfromrgb(60,60,60), BorderColor3 = colorfromrgb(12,12,12), AnchorPoint = Vector2.new(0.5,0.5), Position = udim2new(0.5,0,0.5,0), Size = udim2new(0,658,0,558), Parent = _screenGui})
		local Border2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(40,40,40), Position = udim2new(0,2,0,2), Size = udim2new(1,-4,1,-4), Parent = Border})
		local Background = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(60,60,60), Position = udim2new(0,3,0,3), Size = udim2new(1,-6,1,-6), Image = "rbxassetid://15453092054", ScaleType = Enum.ScaleType.Tile, TileSize = udim2new(0,4,0,548), ClipsDescendants = true, Parent = Border2})
		local TabFix = newObject("Frame", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,91,0,18), Size = udim2new(1,-105,1,-33), Visible = true, ClipsDescendants = true, Parent = Background})
		local TabHolder = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,0,14), Size = udim2new(0,73,0,0), Parent = Background})
		local TabLayout = newObject("UIListLayout", {HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = TabHolder})
		local TopGap = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(0,73,0,14), Parent = Background})
		local TopSideFix = newObject("Frame", {BackgroundColor3 = colorfromrgb(0,0,0), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,73,0,0), Size = udim2new(0,1,1,0), Parent = TopGap})
		local TopSideFix2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,0,0,0), Size = udim2new(0,1,1,0), Parent = TopSideFix})
		local BottomGap = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,1,-22), Size = udim2new(0,73,0,22), Parent = Background})
		local BottomSideFix = newObject("Frame", {BackgroundColor3 = colorfromrgb(0,0,0), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,73,0,0), Size = udim2new(0,1,1,0), Parent = BottomGap})
		local BottomSideFix2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,0,0,0), Size = udim2new(0,1,1,0), Parent = BottomSideFix})
		local TopBar_2 = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(12,12,12), Position = udim2new(0,1,0,1), BackgroundTransparency = 1, Size = udim2new(1,-2,0,2), ZIndex = 2, Image = "rbxassetid://15453122383", Parent = Background})
		local BlackBar = newObject("Frame", {BackgroundColor3 = colorfromrgb(6,6,6), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,1,0), Size = udim2new(1,0,0,1), ZIndex = 2, Parent = TopBar_2})
		local Dragger = newObject("Frame", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,-6,1,-6), Size = udim2new(0,6,0,6), BackgroundTransparency = 1, Visible = true, Parent = Border})

		local isDragging = false

		utility.newConnection(Dragger.InputEnded, function(input, gpe)
			if gpe then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if isDragging then isDragging = false; utility.is_dragging_blocked = false end
			end
		end)

		utility.setDraggable(Border)

		local new_window = {tab_holder = TabHolder, active_tab = nil, background = Background, tab_fix = TabFix, tabs = {}}

		utility.newConnection(Dragger.InputBegan, function(input, gpe)
			if gpe then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not menu.busy then
				local oldSize = Border.Size
				isDragging = true
				utility.is_dragging_blocked = true
				spawn(function()
					while isDragging do
						local change = getMouseLocation(uis)-(Border.AbsolutePosition + Border.AbsoluteSize + vector2new(0,36))
						Border.Size = udim2new(0, clamp(oldSize.X.Offset + change.X, 658, 5000), 0, clamp(oldSize.Y.Offset + change.Y, 558, 5000))
						new_window.tabs[9].button.Visible = Border.Size.Y.Offset >= 628
						oldSize = Border.Size
						BottomGap.Size = udim2new(0, 73, 0, 22 + Border.Size.Y.Offset-(Border.Size.Y.Offset >= 628 and 622 or 558))
						BottomGap.Position = udim2new(0, 0, 1, -BottomGap.Size.Y.Offset)
						wait()
					end
				end)
			end
		end)

		utility.newConnection(Border:GetPropertyChangedSignal("BackgroundTransparency"), function()
			if not menu.blocked then
				_screenGui.Enabled = Border.BackgroundTransparency ~= 1
				menu.is_open = _screenGui.Enabled
			end
		end)

		utility.newConnection(menu.on_closing, function()
			tween(Border, tween_info, {BackgroundTransparency = 1})
			tween(Border2, tween_info, {BackgroundTransparency = 1})
			tween(Background, tween_info, {ImageTransparency = 1})
			tween(TabHolder, tween_info, {BackgroundTransparency = 1})
			tween(TopGap, tween_info, {BackgroundTransparency = 1})
			tween(TopSideFix, tween_info, {BackgroundTransparency = 1})
			tween(TopSideFix2, tween_info, {BackgroundTransparency = 1})
			tween(BottomGap, tween_info, {BackgroundTransparency = 1})
			tween(BottomSideFix, tween_info, {BackgroundTransparency = 1})
			tween(BottomSideFix2, tween_info, {BackgroundTransparency = 1})
			tween(TopBar_2, tween_info, {ImageTransparency = 1})
			tween(BlackBar, tween_info, {BackgroundTransparency = 1})
		end, true)

		utility.newConnection(menu.on_opening, function()
			tween(Border, tween_info, {BackgroundTransparency = 0})
			tween(Border2, tween_info, {BackgroundTransparency = 0})
			tween(Background, tween_info, {ImageTransparency = 0})
			tween(TabHolder, tween_info, {BackgroundTransparency = 0})
			tween(TopGap, tween_info, {BackgroundTransparency = 0})
			tween(TopSideFix, tween_info, {BackgroundTransparency = 0})
			tween(TopSideFix2, tween_info, {BackgroundTransparency = 0})
			tween(BottomGap, tween_info, {BackgroundTransparency = 0})
			tween(BottomSideFix, tween_info, {BackgroundTransparency = 0})
			tween(BottomSideFix2, tween_info, {BackgroundTransparency = 0})
			tween(TopBar_2, tween_info, {ImageTransparency = 0})
			tween(BlackBar, tween_info, {BackgroundTransparency = 0})
		end, true)

		utility.newConnection(Background:GetPropertyChangedSignal("ImageTransparency"), function()
			Background.BackgroundTransparency = Background.ImageTransparency == 0 and 0 or 1
		end)

		setmetatable(new_window, window)

		for int = 1, 9 do
			new_window:_registerTab(int, tabs[int], int == selected_tab)
		end

		return new_window
	end

	function window:_registerTab(int, info, is_first_tab)
		local new_tab = {sections = {}, is_open = false}

		local Button = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(0,73,0,64), Parent = self.tab_holder})
		local BottomBar = newObject("Frame", {BackgroundColor3 = colorfromrgb(0,0,0), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,1,1), Size = udim2new(1,0,0,1), Visible = false, ZIndex = 2, Parent = Button})
		local BottomBar2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,0,-1), Size = udim2new(1,2,1,0), ZIndex = 2, Parent = BottomBar})
		local Icon = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,1,0), Image = info.icon, ImageColor3 = colorfromrgb(109,109,109), Parent = Button})
		local TopBar = newObject("Frame", {BackgroundColor3 = colorfromrgb(0,0,0), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,0,-2), Size = udim2new(1,0,0,1), Visible = false, ZIndex = 2, Parent = Button})
		local TopBar2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,0,1), Size = udim2new(1,2,1,0), ZIndex = 2, Parent = TopBar})
		local SideBar = newObject("Frame", {BackgroundColor3 = colorfromrgb(0,0,0), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,73,0,0), Size = udim2new(0,1,1,0), Parent = Button})
		local SideBar2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,0,0,0), Size = udim2new(0,1,1,0), Parent = SideBar})

		if int == 9 then Button.Visible = false end

		local _Tab = newObject("Frame", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,5,0,5), Size = udim2new(1,-10,1,-8), Visible = false, Parent = self.tab_fix})

		utility.newConnection(menu.on_closing, function()
			tween(Button, tween_info, {BackgroundTransparency = 1})
			tween(BottomBar, tween_info, {BackgroundTransparency = 1})
			tween(BottomBar2, tween_info, {BackgroundTransparency = 1})
			tween(SideBar2, tween_info, {BackgroundTransparency = 1})
			tween(SideBar, tween_info, {BackgroundTransparency = 1})
			tween(TopBar2, tween_info, {BackgroundTransparency = 1})
			tween(TopBar, tween_info, {BackgroundTransparency = 1})
			tween(Icon, tween_info, {ImageTransparency = 1})
		end, true)

		utility.newConnection(menu.on_opening, function()
			tween(Button, tween_info, {BackgroundTransparency = self.active_tab == int and 1 or 0})
			tween(BottomBar, tween_info, {BackgroundTransparency = 0})
			tween(BottomBar2, tween_info, {BackgroundTransparency = 0})
			tween(SideBar2, tween_info, {BackgroundTransparency = 0})
			tween(SideBar, tween_info, {BackgroundTransparency = 0})
			tween(TopBar2, tween_info, {BackgroundTransparency = 0})
			tween(TopBar, tween_info, {BackgroundTransparency = 0})
			tween(Icon, tween_info, {ImageTransparency = 0})
		end, true)

		utility.newConnection(Button.InputBegan, function(input, gpe)
			if gpe then return end
			local inputType = input.UserInputType
			if inputType == Enum.UserInputType.MouseButton1 then
				if self.active_tab == int then return end
				self:_setActiveTab(int)
			end
		end)

		utility.newConnection(Button.MouseEnter, function()
			if self.active_tab == int then return end
			tween(Icon, newtweeninfo(menu.animation_speed/2, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {ImageColor3 = colorfromrgb(204,204,204)})
		end)

		utility.newConnection(Button.MouseLeave, function()
			if self.active_tab == int then return end
			tween(Icon, newtweeninfo(menu.animation_speed/2, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {ImageColor3 = colorfromrgb(109,109,109)})
		end)

		utility.newConnection(_Tab:GetPropertyChangedSignal("Position"), LPH_NO_VIRTUALIZE(function()
			local scale = _Tab.Position.Y.Scale
			_Tab.Visible = not (scale == 1 or scale == -1)
		end))

		new_tab.button = Button
		new_tab.icon = Icon
		new_tab.bottom_bar = BottomBar
		new_tab.top_bar = TopBar
		new_tab.side_bar = SideBar
		new_tab.frame = _Tab

		setmetatable(new_tab, tab)

		self.tabs[int] = new_tab

		if info.subtabs then
			new_tab.subtabs = {}
			local Section = newObject("Frame", {BackgroundColor3 = colorfromrgb(0,0,0), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,-1,0,61), Position = udim2new(0,0,0,0), BackgroundTransparency = 1, Parent = _Tab})
			local Inside = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,1,-1), BackgroundTransparency = 1, Parent = Section})
			local Inside2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,0), Size = udim2new(1,-2,1,-1), BackgroundTransparency = 1, Parent = Inside})
			local Inside3 = newObject("Frame", {BackgroundColor3 = colorfromrgb(23,23,23), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,0), Size = udim2new(1,-2,1,-1), BackgroundTransparency = 1, Parent = Inside2})
			local OptionHolder = newObject("Frame", {BackgroundTransparency = 1, Position = udim2new(0,10,0,0), Size = udim2new(1,-20,1,0), Parent = Inside3})
			newObject("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = OptionHolder})
			local SectionLabel = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,12,0,-2), FontFace = menu_font_bold, Text = info.name or "Category", TextColor3 = colorfromrgb(198,198,198), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, TextTransparency = 1, Parent = Inside3})
			local TopLine = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(0,9,0,1), BackgroundTransparency = 1, Parent = Inside3})
			local TopLine2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,-2,0,-1), Size = udim2new(1,2,0,1), BackgroundTransparency = 1, Parent = TopLine})
			local size = ts:GetTextSize(info.name or "Category", 13, Enum.Font.SourceSansBold, vector2new(9999,9999)).x
			local _TopLine = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1, -(size + 16), 0, 1), Position = udim2new(0, size + 16, 0, 0), BackgroundTransparency = 1, Parent = Inside3})
			local _TopLine2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,0,-1), Size = udim2new(1,2,0,1), BackgroundTransparency = 1, Parent = _TopLine})

			new_tab.on_opening = function(bypass)
				if not _Tab.Visible and not bypass then return end
				local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
				tween(_TopLine2, info, {BackgroundTransparency = 0})
				tween(_TopLine, info, {BackgroundTransparency = 0})
				tween(TopLine2, info, {BackgroundTransparency = 0})
				tween(TopLine, info, {BackgroundTransparency = 0})
				tween(Inside, info, {BackgroundTransparency = 0})
				tween(Inside2, info, {BackgroundTransparency = 0})
				tween(Inside3, info, {BackgroundTransparency = 0})
				tween(SectionLabel, info, {TextTransparency = 0})
				local children = OptionHolder:GetChildren()
				for i = 1, #children do
					local image = children[i]
					if image.ClassName == "ImageLabel" then
						tween(image, info, {ImageTransparency = 0})
					end
				end
			end
			new_tab.on_closing = function(bypass)
				if not _Tab.Visible and not bypass then return end
				local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
				tween(_TopLine2, info, {BackgroundTransparency = 1})
				tween(_TopLine, info, {BackgroundTransparency = 1})
				tween(TopLine2, info, {BackgroundTransparency = 1})
				tween(TopLine, info, {BackgroundTransparency = 1})
				tween(Inside, info, {BackgroundTransparency = 1})
				tween(Inside2, info, {BackgroundTransparency = 1})
				tween(Inside3, info, {BackgroundTransparency = 1})
				tween(SectionLabel, info, {TextTransparency = 1})
				local children = OptionHolder:GetChildren()
				for i = 1, #children do
					local image = children[i]
					if image.ClassName == "ImageLabel" then
						tween(image, info, {ImageTransparency = 1})
					end
				end
			end

			new_tab.subtabs = {}

			local total = 0
			for _, option in info.subtabs.options do
				total+=1
				new_tab.subtabs[total] = new_tab:_registerSubtab(option)
				local int = total
				local Image = newObject("ImageLabel", {BackgroundTransparency = 1, Image = option.image, ImageColor3 = total == 1 and colorfromrgb(205,205,205) or colorfromrgb(96,96,96), Size = udim2new(0,75,0,57), ImageTransparency = 1, Parent = OptionHolder})

				utility.newConnection(Image.MouseEnter, function()
					if new_tab.active_subtab == int then return end
					Image.ImageColor3 = colorfromrgb(135,135,135)
				end)

				utility.newConnection(Image.MouseLeave, function()
					if new_tab.active_subtab == int then return end
					Image.ImageColor3 = colorfromrgb(96,96,96)
				end)

				utility.newConnection(Image.InputBegan, function(input, gpe)
					if new_tab.active_subtab == int then return end
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						local children = OptionHolder:GetChildren()
						for i = 1, #children do
							local child = children[i]
							if child.ClassName == "ImageLabel" then
								child.ImageColor3 = colorfromrgb(96,96,96)
							end
						end
						Image.ImageColor3 = colorfromrgb(205,205,205)
						new_tab:_setActiveSubtab(int)
					end
				end)
			end
			utility.newConnection(menu.on_closing, new_tab.on_closing)
			utility.newConnection(menu.on_opening, new_tab.on_opening)
		end

		if is_first_tab then self:_setActiveTab(int) end

		return new_tab
	end

	function window:_setActiveTab(int)
		local tabs = self.tabs
		local new_tab = tabs[int]
		local last_tab = tabs[self.active_tab or int]
		local down = ((self.active_tab or int)-int) < 1
		local speed = menu.animation_speed

		self.active_tab = int

		for _, section in last_tab.sections do
			spawn(section.on_closing, true)
			for _, element in section.elements do
				for _, func in element.closing do
					spawn(func, true)
				end
			end
		end
		if new_tab.on_opening then spawn(new_tab.on_opening, true) end
		if last_tab.on_closing then spawn(last_tab.on_closing, true) end
		tween(last_tab.frame, newtweeninfo(speed+0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = udim2new(0,5,down and -1 or 1,5)})
		new_tab.frame.Position = udim2new(0,5,down and 1 or -1,5)
		tween(new_tab.frame, newtweeninfo(speed+0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = udim2new(0,5,0,5)})
		for _, section in new_tab.sections do
			spawn(section.on_opening, true)
			for _, element in section.elements do
				for _, func in element.opening do
					spawn(func, true)
				end
			end
		end

		local tabs = self.tabs
		for _int = 1, 9 do
			local tab = tabs[_int]
			if not tab then continue end
			local is_active_tab = int == _int
			tween(tab.icon, newtweeninfo(0, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {ImageColor3 = is_active_tab and colorfromrgb(255,255,255) or colorfromrgb(109,109,109)})
			tab.bottom_bar.Visible = is_active_tab
			tab.top_bar.Visible = is_active_tab
			tab.side_bar.Visible = not is_active_tab
			tab.button.BackgroundTransparency = is_active_tab and 1 or 0
		end
	end

	function tab:_registerSubtab()
		local new_subtab = {has_selector = true, sections = {}, frame = newObject("Frame", {BackgroundColor3 = colorfromrgb(0,0,0), BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(1,10,0,80), Size = udim2new(1,0,1,-80), Visible = false, Parent = self.frame})}
		setmetatable(new_subtab, tab)
		return new_subtab
	end

	function tab:_setActiveSubtab(int)
		local tabs = self.subtabs
		local new_tab = tabs[int]
		local old = self.active_subtab
		local last_tab = tabs[self.active_subtab or int]
		local down = ((old or int)-int) < 1
		local speed = menu.animation_speed

		new_tab.frame.Visible = true
		self.active_subtab = int

		for _, section in last_tab.sections do
			spawn(section.on_closing, true)
			for _, element in section.elements do
				for _, func in element.closing do
					spawn(func, true)
				end
			end
		end
		delay(speed+0.2, function()
			if self.active_subtab ~= old and last_tab ~= new_tab then
				last_tab.frame.Visible = false
			end
		end)
		tween(last_tab.frame, newtweeninfo(speed+0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = udim2new(down and -1 or 1,0,0,80)})
		new_tab.frame.Position = udim2new(down and 1 or -1,0,0,80)
		tween(new_tab.frame, newtweeninfo(speed+0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = udim2new(0,0,0,80)})
		for _, section in new_tab.sections do
			spawn(section.on_opening, true)
			for _, element in section.elements do
				for _, func in element.opening do
					spawn(func, true)
				end
			end
		end
	end

	function tab:getSubtab(int)
		return self.subtabs[int]
	end

	function window:getTab(int)
		return self.tabs[int]
	end

	function tab:newSection(info)
		local Section = newObject("Frame", {BackgroundColor3 = colorfromrgb(0,0,0), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(0.5, -10, info.scale, info.y and -19), Position = udim2new(info.x, info.x and 9 or 0, info.y, info.y and 19 or 0), BackgroundTransparency = 1, Parent = self.frame})
		local Inside = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,1,-1), BackgroundTransparency = 1, Parent = Section})
		local Inside2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,0), Size = udim2new(1,-2,1,-1), BackgroundTransparency = 1, Parent = Inside})
		local Inside3 = newObject("Frame", {BackgroundColor3 = colorfromrgb(23,23,23), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,0), Size = udim2new(1,-2,1,-1), BackgroundTransparency = 1, Parent = Inside2})
		local SectionLabel = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,12,0,-2), FontFace = menu_font_bold, Text = info.name, TextColor3 = colorfromrgb(198,198,198), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, TextTransparency = 1, Parent = Inside3})
		local TopLine = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(0,9,0,1), BackgroundTransparency = 1, Parent = Inside3})
		local TopLine2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,-2,0,-1), Size = udim2new(1,2,0,1), BackgroundTransparency = 1, Parent = TopLine})
		local ArrowUp = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,-16,0,5), Size = udim2new(0,5,0,4), Image = "rbxassetid://15540851994", ImageTransparency = 1, ZIndex = 3, Visible = false, Parent = Inside3})
		local ArrowDown = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,-16,1,-9), Size = udim2new(0,5,0,4), Visible = false, ZIndex = 3, Image = "rbxassetid://15540867448", ImageTransparency = 1, Parent = Inside3})
		local BottomShadow = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,1,-20), Size = udim2new(1,-2,0,20), Image = "rbxassetid://15541064478", ImageColor3 = colorfromrgb(23,23,23), ZIndex = 2, ImageTransparency = 1, Parent = Inside3})
		local TopShadow = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Rotation = 180, Position = udim2new(0,1,0,2), Size = udim2new(1,-2,0,20), Image = "rbxassetid://15541064478", ImageColor3 = colorfromrgb(23,23,23), ImageTransparency = 1, ZIndex = 2, Parent = Inside3})
		local ScrollBackground = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(1,-6,0,0), Size = udim2new(0,6,1,0), Visible = false, ZIndex = 2, Parent = Inside3})
		local Scroller = newObject("ScrollingFrame", {Active = false, BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,0,2), Selectable = false, ScrollingEnabled = false, Size = udim2new(1,0,1,-2), ZIndex = 3, BottomImage = "rbxassetid://15540816491", CanvasPosition = vector2new(0,0), CanvasSize = udim2new(0,0,1,0), MidImage = "rbxassetid://15540816491", ScrollBarImageTransparency = 1, AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarImageColor3 = colorfromrgb(65,65,65), ScrollBarThickness = 5, TopImage = "rbxassetid://15540816491", ClipsDescendants = true, Parent = Inside3})
		local ElementHolder = newObject("Frame", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,18,0,18), Size = udim2new(1,-36,0,0), AutomaticSize = Enum.AutomaticSize.Y, Parent = Scroller})
		local UIListLayout = newObject("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,10), Parent = ElementHolder})

		local size = ts:GetTextSize(info.name, 13, Enum.Font.SourceSansBold, vector2new(9999,9999)).x
		local _TopLine = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1, -(size + 16), 0, 1), Position = udim2new(0, size + 16, 0, 0), BackgroundTransparency = 1, Parent = Inside3})
		local _TopLine2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,0,-1), Size = udim2new(1,2,0,1), BackgroundTransparency = 1, Parent = _TopLine})
		local _Frame = newObject("Frame", {Parent = nil, Size = udim2new(1,0,0,4), Visible = true, BackgroundTransparency = 1})

		local function updateSize()
			local wholeSectionSize = Section.AbsoluteSize - vector2new(0,40)
			if ElementHolder.AbsoluteSize.Y > wholeSectionSize.Y then
				Scroller.CanvasSize = udim2new(0,0,1,0)
				Scroller.ScrollingEnabled = true
				Scroller.ScrollBarImageTransparency = 0
				ScrollBackground.Visible = true
				ArrowUp.Visible = true
				ArrowDown.Visible = true
				BottomShadow.Visible = true
				TopShadow.Visible = true
				_Frame.Parent = ElementHolder
			else
				_Frame.Parent = nil
				Scroller.ScrollingEnabled = false
				Scroller.ScrollBarImageTransparency = 1
				ScrollBackground.Visible = false
				ArrowUp.Visible = false
				ArrowDown.Visible = false
				BottomShadow.Visible = false
				TopShadow.Visible = false
			end
		end

		utility.newConnection(ArrowUp.InputBegan, function(input, gpe)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				Scroller.CanvasPosition = vector2new(0,0)
			end
		end)

		utility.newConnection(ArrowDown.InputBegan, function(input, gpe)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				Scroller.CanvasPosition = vector2new(0,Scroller.AbsoluteCanvasSize.Y)
			end
		end)

		utility.newConnection(_TopLine:GetPropertyChangedSignal("AbsoluteSize"), function()
			_TopLine.Visible = _TopLine.AbsoluteSize.X > 0 and true or false
		end)

		utility.newConnection(Scroller:GetPropertyChangedSignal("CanvasPosition"), function()
			if Scroller.CanvasPosition.Y/Scroller.AbsoluteCanvasSize.Y < 0.5 then
				ArrowUp.ImageTransparency = 0
				ArrowDown.ImageTransparency = 1
			else
				ArrowUp.ImageTransparency = 1
				ArrowDown.ImageTransparency = 0
			end
		end)

		local new_section = {tab_frame = self.frame, element_holder = ElementHolder, elements = {}, frame = Section,
			on_closing = function(bypass)
				if not self.frame.Visible and not bypass then return end
				local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
				tween(_TopLine2, info, {BackgroundTransparency = 1})
				tween(_TopLine, info, {BackgroundTransparency = 1})
				tween(ScrollBackground, info, {BackgroundTransparency = 1})
				tween(Scroller, info, {ScrollBarImageTransparency = 1})
				tween(TopShadow, info, {ImageTransparency = 1})
				tween(BottomShadow, info, {ImageTransparency = 1})
				tween(ArrowUp, info, {ImageTransparency = 1})
				tween(ArrowDown, info, {ImageTransparency = 1})
				tween(TopLine2, info, {BackgroundTransparency = 1})
				tween(TopLine, info, {BackgroundTransparency = 1})
				tween(Inside, info, {BackgroundTransparency = 1})
				tween(Inside2, info, {BackgroundTransparency = 1})
				tween(Inside3, info, {BackgroundTransparency = 1})
				tween(SectionLabel, info, {TextTransparency = 1})
			end,
			on_opening = function(bypass)
				if not self.frame.Visible and not bypass then return end
				local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
				tween(_TopLine2, info, {BackgroundTransparency = 0})
				tween(_TopLine, info, {BackgroundTransparency = 0})
				tween(Scroller, info, {ScrollBarImageTransparency = Scroller.ScrollingEnabled and 0 or 1})
				tween(TopShadow, info, {ImageTransparency = 0})
				tween(BottomShadow, info, {ImageTransparency = 0})
				if Scroller.CanvasPosition.Y/Scroller.AbsoluteCanvasSize.Y < 0.5 then
					tween(ArrowUp, info, {ImageTransparency = 0})
				else
					tween(ArrowDown, info, {ImageTransparency = 0})
				end
				tween(TopLine2, info, {BackgroundTransparency = 0})
				tween(TopLine, info, {BackgroundTransparency = 0})
				tween(Inside, info, {BackgroundTransparency = 0})
				tween(Inside2, info, {BackgroundTransparency = 0})
				tween(Inside3, info, {BackgroundTransparency = 0})
				tween(SectionLabel, info, {TextTransparency = 0})
			end
		}

		utility.newConnection(menu.on_closing, new_section.on_closing)
		utility.newConnection(menu.on_opening, new_section.on_opening)

		setmetatable(new_section, section)

		utility.newConnection(Section:GetPropertyChangedSignal("Size"), updateSize)
		utility.newConnection(ElementHolder:GetPropertyChangedSignal("AbsoluteSize"), updateSize)

		self.sections[info.name] = new_section

		return new_section
	end

	function section:newElement(info)
		local Frame = newObject("Frame", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,0,8), Parent = self.element_holder})
		local Label = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,20,0,-1), Size = udim2new(0.5,0,0,8), FontFace = menu_font, Text = info.name, TextColor3 = info.highlighted == true and colorfromrgb(182,182,101) or colorfromrgb(205,205,205), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, Parent = Frame})

		local new_element = {frame = Frame, closing = {}, visible = true, name = info.name, label = Label, opening = {}}
		local tab_frame = self.tab_frame
		local total = 0
		setmetatable(new_element, element)

		for _element, _info in info.types do
			new_element[_element] = _info
			if lower(_element) == "toggle" then
				total+=1
				local Box = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(0,8,0,8), BackgroundTransparency = 1, Parent = Frame})
				local Inside = newObject("Frame", {BackgroundColor3 = colorfromrgb(77,77,77), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), BackgroundTransparency = 1, Parent = Box})
				newObject("UIGradient", {Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, colorfromrgb(255,255,255)), ColorSequenceKeypoint.new(1.00, colorfromrgb(218,218,218))}, Rotation = 90, Parent = Inside})

				insert(new_element.closing, function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(Box, info, {BackgroundTransparency = 1})
					tween(Inside, info, {BackgroundTransparency = 1})
				end, true)

				insert(new_element.opening, function(bypass)
					if not new_element.visible then return end
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(Box, info, {BackgroundTransparency = 0})
					tween(Inside, info, {BackgroundTransparency = 0})
				end, true)

				local h,s,v = menu.accent_color:ToHSV()
				new_element.onToggleChange = signal.new()
				new_element.toggled = false
				flags[_info.flag] = false

				utility.newConnection(menu.on_accent_change, function(color)
					h,s,v = color:ToHSV()
					if new_element.toggled then
						tween(Inside, newtweeninfo(0, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {BackgroundColor3 = color})
					end
				end)

				local function onHover()
					tween(Inside, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = new_element.toggled == true and Color3.fromHSV(h,s,v*1.1) or colorfromrgb(85,85,85)})
				end

				local function onLeave()
					tween(Inside, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = new_element.toggled == true and menu.accent_color or colorfromrgb(77,77,77)})
				end

				local function onClick(input, gpe)
					if gpe then return end
					if input.UserInputType == Enum.UserInputType.MouseButton1 and not menu.busy then
						new_element:setToggle(not new_element.toggled)
					end
				end

				local last_bool = _info.default

				function new_element:setToggle(bool, dont)
					if last_bool ~= bool or dont then
						new_element.onToggleChange:Fire(bool)
					end
					last_bool = bool
					tween(Inside, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = bool and menu.accent_color or colorfromrgb(77,77,77)})
					new_element.toggled = bool
					flags[_info.flag] = bool
				end

				new_element:setToggle(_info.default or false)

				utility.newConnection(Label.InputEnded, onClick)
				utility.newConnection(Box.InputEnded, onClick)
				utility.newConnection(Box.MouseEnter, onHover)
				utility.newConnection(Label.MouseEnter, onHover)
				utility.newConnection(Box.MouseLeave, onLeave)
				utility.newConnection(Label.MouseLeave, onLeave)

				if not _info.no_load then
					utility.newConnection(menu.on_load, function()
						new_element:setToggle(flags[_info.flag])
					end)
				end
			elseif lower(_element) == "dropdown" then
				total+=1
				Frame.Size = udim2new(1,0,0,31)
				local Border = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,19,0,11), Size = udim2new(0.72,0,0,20), BackgroundTransparency = 1, Parent = Frame})
				local UISizeConstraint = newObject("UISizeConstraint", {MaxSize = vector2new(200,9e9), Parent = Border})
				local _Inside = newObject("Frame", {BackgroundColor3 = colorfromrgb(36,36,36), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), BackgroundTransparency = 1, Parent = Border})
				newObject("UIGradient", {Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, colorfromrgb(219,219,219)), ColorSequenceKeypoint.new(1.00, colorfromrgb(255,255,255))}, Rotation = 90, Parent = _Inside})
				local DropdownLabel = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,6,0,0), Size = udim2new(1,-24,1,0), FontFace = menu_font, TextTransparency = 1, Text = "-", TextColor3 = colorfromrgb(152,152,152), TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = _Inside})
				local Arrow = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,-11,0,6), Size = udim2new(0,5,0,4), Image = "rbxassetid://15556784588", ImageColor3 = colorfromrgb(151,151,151), ImageTransparency = 1, Parent = _Inside})
				local DropdownOpen = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,19,0,11), Size = udim2new(0,156,0,20), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 10, Parent = _screenGui})
				local OpenInside = newObject("Frame", {BackgroundColor3 = colorfromrgb(35,35,35), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), ClipsDescendants = true, ZIndex = 10, Parent = DropdownOpen})
				newObject("UIListLayout", {HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = OpenInside})

				local isOpen = false

				local function onHover()
					tween(_Inside, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = colorfromrgb(46,46,46)})
					Arrow.ImageColor3 = colorfromrgb(156,156,156)
				end

				local function onLeave()
					if isOpen then return end
					Arrow.ImageColor3 = colorfromrgb(151,151,151)
					tween(_Inside, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = colorfromrgb(36,36,36)})
				end

				local clickOutConnection = nil

				new_element.onDropdownChange = signal.new()

				local function closeDropdown(notOnBorder)
					local speed = tab_frame.Position.Y.Scale ~= 0 and 0 or menu.animation_speed
					clickOutConnection:Disconnect()
					tween(DropdownOpen, newtweeninfo(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = udim2new(0, Border.AbsoluteSize.X + 1, 0, 0), BackgroundTransparency = 1})
					local children = OpenInside:GetChildren()
					for i = 1, #children do
						local child = children[i]
						if child.ClassName == "TextLabel" then
							tween(child, newtweeninfo(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 1})
						end
					end
					delay(0, function()
						isOpen = false
						clickOutConnection:Disconnect()
						if notOnBorder then
							Arrow.ImageColor3 = colorfromrgb(151,151,151)
							tween(_Inside, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = colorfromrgb(36,36,36)})
						end
						if tab_frame.Position.Y.Scale ~= 0 then
							DropdownOpen.Visible = false
						end
					end)
					delay(speed-0.05, function()
						if not isOpen then
							menu.busy = false
							utility.is_dragging_blocked = false
							DropdownOpen.Visible = false
						end
					end)
				end

				new_element.dropdown_visible = true

				local function openDropdown()
					if not new_element.dropdown_visible or menu.busy then return end
					local newPosition = Border.AbsolutePosition
					DropdownOpen.AutomaticSize = Enum.AutomaticSize.Y
					DropdownOpen.Size = udim2new(0, Border.AbsoluteSize.X + 1, 0, 20)
					local size = DropdownOpen.AbsoluteSize
					DropdownOpen.AutomaticSize = Enum.AutomaticSize.None
					DropdownOpen.Size = udim2new(0, Border.AbsoluteSize.X + 1, 0, 0)
					DropdownOpen.Position = udim2new(0, newPosition.X + 0.5, 0, newPosition.Y + 2 + Border.AbsoluteSize.Y)
					tween(DropdownOpen, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = udim2new(0, Border.AbsoluteSize.X + 1, 0, size.Y), BackgroundTransparency = 0})
					local children = OpenInside:GetChildren()
					for i = 1, #children do
						local child = children[i]
						if child.ClassName == "TextLabel" then
							tween(child, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0})
						end
					end
					DropdownOpen.Visible = true
					clickOutConnection = utility.newConnection(uis.InputBegan, LPH_NO_VIRTUALIZE(function(input, gpe)
						if gpe then return end
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							local pos = input.Position
							if not isInFrame(Border, pos) and not isInFrame(DropdownOpen, pos) then closeDropdown(true) end
						end
					end), true)
					isOpen = true
					menu.busy = true
					utility.is_dragging_blocked = true
				end

				function new_element:setSelected(options)
					local string = ""
					local children = OpenInside:GetChildren()
					for i = 1, #children do
						local label = children[i]
						if label.ClassName ~= "TextLabel" then continue end
						local option = label.Name
						if find(options, option) then
							string = #string == 0 and option or string..", "..option
							label.FontFace = menu_font_bold
							label.TextColor3 = menu.accent_color
						else
							label.FontFace = menu_font
							label.TextColor3 = colorfromrgb(208,208,208)
						end
					end
					DropdownLabel.Text = string == "" and "-" or string
					new_element.onDropdownChange:Fire(options)
					flags[_info.flag] = options
				end

				utility.newConnection(menu.on_accent_change, function(color)
					local children = OpenInside:GetChildren()
					for i = 1, #children do
						local label = children[i]
						if label.ClassName ~= "TextLabel" then continue end
						local option = label.Name
						if find(flags[_info.flag], option) then
							label.TextColor3 = menu.accent_color
						end
					end
				end)

				flags[_info.flag] = {}

				do
					for _, option in _info.options do
						local DropdownOption = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(25,25,25), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,0,20), ZIndex = 11, FontFace = menu_font, Text = "   "..option, TextColor3 = colorfromrgb(208,208,208), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, Parent = OpenInside})
						DropdownOption.Name = option

						if _info.multi then
							utility.newConnection(DropdownOption.MouseEnter, function()
								DropdownOption.BackgroundTransparency = 0
							end)
							utility.newConnection(DropdownOption.MouseLeave, function()
								DropdownOption.BackgroundTransparency = 1
							end)
							utility.newConnection(DropdownOption.InputBegan, function(input, gpe)
								if gpe then return end
								if input.UserInputType == Enum.UserInputType.MouseButton1 then
									if not find(flags[_info.flag], option) then
										insert(flags[_info.flag], option)
									else
										if _info.no_none and length(flags[_info.flag]) == 1 then return end
										remove(flags[_info.flag], option)
									end
									new_element:setSelected(flags[_info.flag])
								end
							end)
						else
							utility.newConnection(DropdownOption.MouseEnter, function()
								DropdownOption.BackgroundTransparency = 0
								if flags[_info.flag][1] == option then return end
								DropdownOption.FontFace = menu_font_bold
							end)
							utility.newConnection(DropdownOption.MouseLeave, function()
								DropdownOption.BackgroundTransparency = 1
								if flags[_info.flag][1] == option then return end
								DropdownOption.FontFace = menu_font
							end)
							utility.newConnection(DropdownOption.InputBegan, function(input, gpe)
								if gpe then return end
								if input.UserInputType == Enum.UserInputType.MouseButton1 then
									if _info.no_none and find(flags[_info.flag], option) then return end
									flags[_info.flag] = find(flags[_info.flag], option) and nil or {option}
									new_element:setSelected(flags[_info.flag])
									closeDropdown()
								end
							end)
						end
					end
				end

				local closing = function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(Border, info, {BackgroundTransparency = 1})
					tween(_Inside, info, {BackgroundTransparency = 1})
					tween(DropdownLabel, info, {TextTransparency = 1})
					tween(Arrow, info, {ImageTransparency = 1})
					if isOpen then closeDropdown() end
				end

				local opening = function(bypass)
					if not new_element.dropdown_visible then return end
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(Border, info, {BackgroundTransparency = 0})
					tween(_Inside, info, {BackgroundTransparency = 0})
					tween(DropdownLabel, info, {TextTransparency = 0})
					tween(Arrow, info, {ImageTransparency = 0})
				end

				insert(new_element.closing, closing)
				insert(new_element.opening, opening)

				function new_element:setDropdownVisibility(bool, force)
					local speed = (tab_frame.Position.Y.Scale ~= 0 or force) and 0 or menu.animation_speed
					if bool then Border.Visible = true end
					new_element.dropdown_visible = bool
					spawn(bool and opening or closing, true)
					tween(Frame, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {Size = bool and self.og_size or udim2new(1,0,0,8)})
					delay(speed, function()
						if not bool and not new_element.dropdown_visible then
							Border.Visible = false
						end
					end)
				end

				utility.newConnection(Border.MouseEnter, onHover)
				utility.newConnection(Border.MouseLeave, onLeave)

				utility.newConnection(Border.InputEnded, function(input, gpe)
					if gpe then return end
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						if not menu.busy then
							openDropdown()
						elseif isOpen then
							closeDropdown()
						end
					end
				end)

				new_element:setSelected(_info.default ~= nil and _info.default or {})

				if not _info.no_load then
					utility.newConnection(menu.on_load, function()
						new_element:setSelected(flags[_info.flag])
					end, true)
				end
			elseif lower(_element) == "slider" then
				total+=1
				Frame.Size = udim2new(1,0,0,20)
				local Border = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,19,0,13), Size = udim2new(0.72,0,0,7), BackgroundTransparency = 1, Parent = Frame})
				local UISizeConstraint = newObject("UISizeConstraint", {MaxSize = vector2new(200,9e9), Parent = Border})
				local Inside = newObject("Frame", {BackgroundColor3 = colorfromrgb(69,69,69), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), BackgroundTransparency = 1, Parent = Border})
				newObject("UIGradient", {Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, colorfromrgb(204,204,204)), ColorSequenceKeypoint.new(1.00, colorfromrgb(255,255,255))}, Rotation = 90, Parent = Inside})
				local Fill = newObject("Frame", {BackgroundColor3 = menu.accent_color, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(0,0,1,0), BackgroundTransparency = 1, Parent = Inside})
				newObject("UIGradient", {Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, colorfromrgb(249,249,249)), ColorSequenceKeypoint.new(1.00, colorfromrgb(201,201,201))}, Rotation = 90, Parent = Fill})
				local ValueLabel = newObject("TextBox", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,-1,0,-2), FontFace = menu_font_bold, Text = _info.prefix.._info.min.._info.suffix, TextColor3 = colorfromrgb(205,205,205), TextSize = 14, ClearTextOnFocus = true, TextStrokeTransparency = 1, TextTransparency = 1, Parent = Fill})
				local Down = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,-7,0,2), ImageTransparency = 1, Size = udim2new(0,3,0,3), Image = "rbxassetid://15582036409", Visible = _info.changers and true or false, Parent = Border})
				local Up = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,4,0,2), Size = udim2new(0,3,0,3), ImageTransparency = 1, Image = "rbxassetid://15582024931", Visible = _info.changers and true or false, Parent = Border})

				utility.newConnection(ValueLabel.FocusLost, function()
					local value = tonumber(ValueLabel.Text) or _info.min
					new_element:setValue(value)
				end, true)

				utility.newConnection(menu.on_accent_change, function(color)
					Fill.BackgroundColor3 = color
				end)

				flags[_info.flag] = _info.min
				new_element.onSliderChange = signal.new()

				local mouseConnection = nil
				local dragging = false

				function new_element:setValue(value, do_tween)
					local value = clamp(value, _info.min, _info.max)
					ValueLabel.Text = _info.prefix..value.._info.suffix
					tween(Fill, newtweeninfo(do_tween and menu.animation_speed or 0, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = udim2new((value - _info.min)/(_info.max-_info.min),0,1,0)})
					tween(ValueLabel, newtweeninfo(do_tween and menu.animation_speed or 0, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = udim2new(0, ts:GetTextSize(tostring(value),13,Enum.Font.SourceSansBold,vector2new(9999,9999)).X, 0, 13), Position = udim2new(1, -ts:GetTextSize(tostring(value),13,Enum.Font.SourceSansBold,vector2new(9999,9999)).X/2, 0, -2)})
					if _info.min == value and _info.min_text then
						ValueLabel.Text = _info.min_text
					elseif _info.max == value and _info.max_text then
						ValueLabel.Text = _info.max_text
					end
					flags[_info.flag] = value
					if _info.changers then
						Down.Visible = value > _info.min
						Up.Visible = value < _info.max
					end
					new_element.onSliderChange:Fire(value)
				end

				if _info.changers then
					utility.newConnection(Down.InputBegan, function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							new_element:setValue(round(flags[_info.flag]-_info.changers, _info.decimal), true)
						end
					end)

					utility.newConnection(Up.InputBegan, function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							new_element:setValue(round(flags[_info.flag]+_info.changers, _info.decimal), true)
						end
					end)
				end

				local closing = function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(Border, info, {BackgroundTransparency = 1})
					tween(Fill, info, {BackgroundTransparency = 1})
					tween(Inside, info, {BackgroundTransparency = 1})
					tween(ValueLabel, info, {TextTransparency = 1, TextStrokeTransparency = 1})
					tween(Down, info, {ImageTransparency = 1})
					tween(Up, info, {ImageTransparency = 1})
					if dragging then
						utility.is_dragging_blocked = false
						dragging = false
					end
				end

				local opening = function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(Border, info, {BackgroundTransparency = 0})
					tween(Inside, info, {BackgroundTransparency = 0})
					tween(Fill, info, {BackgroundTransparency = 0})
					tween(ValueLabel, info, {TextTransparency = 0.1, TextStrokeTransparency = 0.5})
					tween(Down, info, {ImageTransparency = 0})
					tween(Up, info, {ImageTransparency = 0})
				end

				insert(new_element.opening, opening)
				insert(new_element.closing, closing)

				new_element.slider_visible = true

				function new_element:setSliderVisibility(bool, force)
					local speed = (tab_frame.Position.Y.Scale ~= 0 or force) and 0 or menu.animation_speed
					if bool then Border.Visible = true end
					new_element.slider_visible = bool
					spawn(bool and opening or closing, true)
					tween(Frame, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {Size = bool and self.og_size or udim2new(1,0,0,8)})
					delay(speed, function()
						if not bool and not new_element.slider_visible then
							Border.Visible = false
						end
					end)
				end

				utility.newConnection(Inside.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and not menu.busy then
						utility.is_dragging_blocked = true
						local distance = clamp((input.Position.X - Inside.AbsolutePosition.X)/Inside.AbsoluteSize.X, 0, 1)
						local value = round(_info.min + (_info.max - _info.min) * distance, _info.decimal and _info.decimal or 0)
						new_element:setValue(value, true)

						mouseConnection = utility.newConnection(mouse.Move, LPH_NO_VIRTUALIZE(function()
							if dragging then
								local distance = clamp((mouse.X - Inside.AbsolutePosition.X)/Inside.AbsoluteSize.X, 0, 1)
								local value = round(_info.min + (_info.max-_info.min) * distance, _info.decimal and _info.decimal or 0)
								new_element:setValue(value)
							else
								mouseConnection:Disconnect()
							end
						end))

						dragging = true
					end
				end)

				utility.newConnection(Inside.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
						utility.is_dragging_blocked = false
						dragging = false
					end
				end)

				utility.newConnection(Inside.MouseEnter, function()
					tween(Inside, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = colorfromrgb(81,81,81)})
				end)

				utility.newConnection(Inside.MouseLeave, function()
					tween(Inside, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = colorfromrgb(69,69,69)})
				end)

				new_element:setValue(_info.default or _info.min)

				utility.newConnection(menu.on_load, function()
					new_element:setValue(flags[_info.flag])
				end, true)
			elseif lower(_element) == "colorpicker" then
				local ColorBox = newObject("Frame", {AnchorPoint = vector2new(1,0), BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,0,0,0), Size = udim2new(0,17,0,9), BackgroundTransparency = 1, Parent = Frame})
				local Inside = newObject("Frame", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), BackgroundTransparency = 1, Parent = ColorBox})
				newObject("UIGradient", {Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, colorfromrgb(255,255,255)), ColorSequenceKeypoint.new(1.00, colorfromrgb(218,218,218))}, Rotation = 90, Parent = Inside})

				new_element.onColorChange = signal.new()

				function new_element:setColorpickerVisibility(bool)
					ColorBox.Visible = bool
				end

				utility.newConnection(ColorBox.InputEnded, function(input, gpe)
					if gpe then return end
					local input_type = input.UserInputType
					if input_type == Enum.UserInputType.MouseButton1 then
						if not menu.busy then
							openColorpicker(new_element, _info, ColorBox)
						elseif menu.active_colorpicker == new_element then
							closeColorpicker()
						end
					elseif input_type == Enum.UserInputType.MouseButton2 then
						if not menu.busy then
							openColorCopy(new_element, _info, ColorBox)
						elseif menu.active_colorcopy == new_element then
							closeColorCopy()
						end
					end
				end)

				insert(new_element.closing, function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					if menu.active_colorpicker == new_element then
						closeColorpicker(true)
					end
					tween(ColorBox, info, {BackgroundTransparency = 1})
					tween(Inside, info, {BackgroundTransparency = 1})
				end, true)

				insert(new_element.opening, function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(ColorBox, info, {BackgroundTransparency = 0})
					tween(Inside, info, {BackgroundTransparency = 0})
				end, true)

				function new_element:setColor(color, transparency, no_move)
					if menu.active_colorpicker ~= new_element or no_move then
						flags[_info.flag] = color
						flags[_info.transparency_flag] = transparency
						Inside.BackgroundColor3 = color
						new_element.onColorChange:Fire(color, transparency)
						return
					end
					local h,s,v = color:ToHSV()
					update_sv(v*255, s*255, true)
					update_hue(h*360)
					update_transparency(transparency)
				end

				new_element:setColor(_info.default or colorfromrgb(255,255,255), _info.default_transparency or 0)

				utility.newConnection(menu.on_load, function()
					new_element:setColor(flags[_info.flag], flags[_info.transparency_flag])
				end, true)
			elseif lower(_element) == "button" then
				Frame.Size = udim2new(1,0,0,25)
				total+=1
				Label.Visible = false
				local Border = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,19,0,0), Size = udim2new(0.72,0,0,25), BackgroundTransparency = 1, Parent = Frame})
				local Inside2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(50,50,50), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), BackgroundTransparency = 1, Parent = Border})
				local Inside3 = newObject("Frame", {BackgroundColor3 = colorfromrgb(34,34,34), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), BackgroundTransparency = 1, Parent = Inside2})
				newObject("UIGradient", {Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, colorfromrgb(255,255,255)), ColorSequenceKeypoint.new(1.00, colorfromrgb(227,227,227))}, Rotation = 90, Parent = Inside3})
				local ButtonLabel = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,1,0), FontFace = menu_font_bold, Text = _info.text, TextColor3 = colorfromrgb(212,212,212), TextSize = 13, TextTransparency = 1, TextWrapped = true, Parent = Inside3})
				newObject("UISizeConstraint", {Parent = Border, MaxSize = vector2new(200,9e9)})

				insert(new_element.closing, function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(Border, info, {BackgroundTransparency = 1})
					tween(Inside2, info, {BackgroundTransparency = 1})
					tween(Inside3, info, {BackgroundTransparency = 1})
					tween(ButtonLabel, info, {TextTransparency = 1})
				end, true)

				insert(new_element.opening, function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(Border, info, {BackgroundTransparency = 0})
					tween(Inside2, info, {BackgroundTransparency = 0})
					tween(Inside3, info, {BackgroundTransparency = 0})
					tween(ButtonLabel, info, {TextTransparency = 0})
				end, true)

				local function onHover(force)
					tween(Inside3, newtweeninfo(force == true and 0 or menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {BackgroundColor3 = colorfromrgb(39,39,39)})
				end

				local function onLeave()
					tween(Inside3, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {BackgroundColor3 = colorfromrgb(34,34,34)})
				end

				utility.newConnection(Border.InputBegan, function(input, gpe)
					if gpe then return end
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						tween(Inside3, newtweeninfo(0, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {BackgroundColor3 = colorfromrgb(28,28,28)})
					end
				end)

				local do_confirmation = _info.confirmation
				local waiting = false

				utility.newConnection(Border.InputEnded, function(input, gpe)
					if gpe then return end
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						if isInFrame(Border, input.Position) then
							if do_confirmation then
								if not waiting then
									waiting = true
									ButtonLabel.Text = "Are you sure?"
									delay(3, function()
										if waiting then
											ButtonLabel.Text = _info.text
											waiting = false
										end
									end)
								elseif waiting then
									waiting = false
									ButtonLabel.Text = _info.text
									_info.callback()
								end
							else
								_info.callback()
							end
							onHover(true)
						else
							tween(Inside3, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {BackgroundColor3 = colorfromrgb(34,34,34)})
						end
					end
				end)

				utility.newConnection(Border.MouseEnter, onHover)
				utility.newConnection(Border.MouseLeave, onLeave)
			elseif lower(_element) == "keybind" then
				local KeybindLabel = newObject("TextLabel", {AnchorPoint = vector2new(1,0), BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X, Position = udim2new(1,0,0,0), Size = udim2new(0,0,0,7), FontFace = menu_font, Text = "[-]", TextColor3 = colorfromrgb(117,117,117), TextSize = 9, TextStrokeTransparency = 0, TextWrapped = true, TextTransparency = 1, Parent = Frame})

				new_element.onActiveChange = signal.new()
				new_element.flag = _info.flag

				flags[_info.flag] = {method = 1, key = nil, active = false}

				function new_element:setActive(active)
					flags[_info.flag].active = active
					new_element.onActiveChange:Fire(active)
				end

				function new_element:setMethod(method, just_visual, test)
					flags[_info.flag].method = method
					if flags[_info.flag].active ~= method == 1 or test then
						new_element:setActive(method == 1)
					end
					if menu.active_keybind ~= new_element then return end
					local children = KeybindOpenInside2:GetChildren()
					for i = 1, #children do
						local object = children[i]
						if object:IsA("TextLabel") then
							object.FontFace = menu_font
							object.TextColor3 = colorfromrgb(205,205,205)
						end
					end
					local object = findfirstchild(KeybindOpenInside2, method)
					object.FontFace = menu_font_bold
					object.TextColor3 = menu.accent_color
					if method == 1 and not just_visual then
						new_element:setActive(true)
					end
				end

				function new_element:setKey(keycode, new)
					local old_keycode = flags[_info.flag].key
					if old_keycode and old_keycode ~= "" then
						local keybind = menu.keybinds[old_keycode]
						if keybind then
							if #keybind == 1 then
								for _, v in keybind do
									if v[2] == _info.flag then
										menu.keybinds[old_keycode] = nil
										break
									end
								end
							else
								for _, v in keybind do
									if v[1] == new_element then
										remove(menu.keybinds[old_keycode], v)
										break
									end
								end
							end
						end
					end
					if keycode == nil or keycode == "" then
						KeybindLabel.Text = "[-]"
						flags[_info.flag].key = nil
						flags[_info.flag].active = flags[_info.flag].method == 1
						return
					end
					if menu.keybinds[keycode] then
						insert(menu.keybinds[keycode], {new_element, _info.flag})
					elseif keycode then
						menu.keybinds[keycode] = {{new_element, _info.flag}}
					end
					flags[_info.flag].key = keycode
					local shortened = shortened_characters[keycode] and shortened_characters[keycode] or keycode.Name
					KeybindLabel.Text = "["..string.upper(shortened).."]"
				end

				new_element:setMethod(_info.method and _info.method or 1)
				new_element:setKey(_info.key and _info.key or nil)

				local function onHover()
					if menu.busy then return end
					tween(KeybindLabel, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = colorfromrgb(176,176,176)})
				end

				local function onLeave(force)
					if menu.busy and force ~= true then return end
					tween(KeybindLabel, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = colorfromrgb(117,117,117)})
				end

				local function stopKeybind()
					tween(KeybindLabel, newtweeninfo(0, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = colorfromrgb(117,117,117)})
					keyListenConnection:Disconnect()
					menu.busy = false
					utility.is_dragging_blocked = false
				end

				local function startKeybind()
					menu.busy = true
					utility.is_dragging_blocked = true
					wait()
					tween(KeybindLabel, newtweeninfo(0, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = colorfromrgb(200,0,0)})
					keyListenConnection = utility.newConnection(uis.InputBegan, LPH_NO_VIRTUALIZE(function(input, gpe)
						if gpe then
							new_element:setKey(nil)
							stopKeybind()
							return
						end
						local key = shortened_characters[input.UserInputType] and input.UserInputType or input.KeyCode
						local is_valid_key = utility.isValidKey(key)
						if is_valid_key then
							new_element:setKey(key)
						else
							new_element:setKey(nil)
						end
						stopKeybind()
					end), true)
				end

				if not _info.method_locked then
					local clickOutConnection1 = nil

					utility.newConnection(KeybindLabel.InputEnded, function(input, gpe)
						if gpe then return end
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							if not menu.busy and menu.active_keybind ~= new_element then
								openKeybind(new_element, _info, KeybindLabel)
								clickOutConnection1 = utility.newConnection(uis.InputBegan, LPH_NO_VIRTUALIZE(function(input, gpe)
									if gpe then return end
									if input.UserInputType == Enum.UserInputType.MouseButton1 then
										local pos = input.Position
										if not isInFrame(KeybindLabel, pos) and not isInFrame(KeybindOpen, pos) then
											closeKeybind()
											clickOutConnection1:Disconnect()
											onLeave(true)
										end
									end
								end), true)
							elseif menu.active_keybind == new_element then
								clickOutConnection1:Disconnect()
								closeKeybind(false)
							end
						end
					end)
				end

				utility.newConnection(KeybindLabel.InputBegan, function(input, gpe)
					if gpe then return end
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						if not menu.busy then
							startKeybind()
						end
					end
				end)

				insert(new_element.closing, function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(KeybindLabel, info, {TextTransparency = 1, TextStrokeTransparency = 1})
					if menu.active_keybind == new_element then
						closeKeybind(true)
						onLeave()
						if clickOutConnection then
							clickOutConnection:Disconnect()
						end
					end
				end, true)

				insert(new_element.opening, function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(KeybindLabel, info, {TextTransparency = 0, TextStrokeTransparency = 0})
				end, true)

				utility.newConnection(KeybindLabel.MouseEnter, onHover)
				utility.newConnection(KeybindLabel.MouseLeave, onLeave)

				utility.newConnection(menu.on_load, function()
					new_element:setKey(flags[_info.flag].key, true)
					new_element:setMethod(flags[_info.flag].method)
				end, true)
			elseif lower(_element) == "multibox" then
				total+=1
				Frame.Size = udim2new(1,0,0,_info.max*20)
				Label.Visible = false
				local Inside = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,19,0,1), Size = udim2new(0.72,0,1,0), ZIndex = 2, BackgroundTransparency = 1, Parent = Frame})
				local Inside2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(35,35,35), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), ZIndex = 2, BackgroundTransparency = 1, Parent = Inside})
				local Scroller = newObject("ScrollingFrame", {Active = true, BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, Size = udim2new(1,0,1,0), BottomImage = "rbxassetid://15540816491", ScrollBarImageColor3 = colorfromrgb(65,65,65), CanvasSize = udim2new(0,0,1,0), MidImage = "rbxassetid://15540816491", ScrollBarThickness = 5, ScrollingEnabled = false, TopImage = "rbxassetid://15540816491", ZIndex = 4, Parent = Inside2})
				local OptionHolder = newObject("Frame", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2, BackgroundTransparency = 1, Parent = Scroller})
				newObject("UIListLayout", {HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,0), Parent = OptionHolder})
				local ArrowDown = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,-16,1,-9), Size = udim2new(0,5,0,4), Visible = false, ImageTransparency = 1, Image = "rbxassetid://15540867448", ZIndex = 5, Parent = Inside2})
				local ArrowUp = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, ImageTransparency = 1, Position = udim2new(1,-16,0,5), Size = udim2new(0,5,0,4), Visible = false, Image = "rbxassetid://15547663604", ZIndex = 5, Parent = Inside2})
				local BottomShadow = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,0,1,-21), Size = udim2new(1,0,0,20), Image = "rbxassetid://15541064478", ImageColor3 = colorfromrgb(35,35,35), ZIndex = 2, ImageTransparency = 1, Parent = Inside2})
				local TopShadow = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Rotation = 180, Size = udim2new(1,0,0,20), Image = "rbxassetid://15541064478", ImageColor3 = colorfromrgb(35,35,35), ImageTransparency = 1, ZIndex = 2, Parent = Inside2})
				local ScrollBackground = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,-6,0,0), BackgroundTransparency = 1, Size = udim2new(0,6,1,0), Visible = false, ZIndex = 3, Parent = Inside2})
				newObject("UISizeConstraint", {Parent = Inside, MaxSize = vector2new(200,9e9)})
				local ScrollBackground = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(1,-6,0,0), BackgroundTransparency = 1, Size = udim2new(0,6,1,0), Visible = false, ZIndex = 2, Parent = Inside2})

				if _info.search then
					local Search = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,19,0,0), Size = udim2new(0.72,0,0,20), BackgroundTransparency = 1, Parent = Frame})
					local SearchInside = newObject("Frame", {BackgroundColor3 = colorfromrgb(50,50,50), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), BackgroundTransparency = 1, Parent = Search})
					local SearchInside2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(25,25,25), BorderColor3 = colorfromrgb(16,16,16), BorderSizePixel = 1, Position = udim2new(0,2,0,2), Size = udim2new(1,-4,1,-4), BackgroundTransparency = 1, Parent = SearchInside})
					local TextBox = newObject("TextBox", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,5,0,0), Size = udim2new(1,-5,1,0), TextTransparency = 1, ZIndex = 2, FontFace = menu_font_bold, Text = "_", TextColor3 = colorfromrgb(208,208,208), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = SearchInside2})
					newObject("UISizeConstraint", {Parent = Search, MaxSize = vector2new(200,9e9)})

					utility.newConnection(TextBox.FocusLost, function()
						TextBox.TextColor3 = colorfromrgb(208,208,208)
						if TextBox.Text == "" then
							TextBox.Text = "_"
						end
					end)

					utility.newConnection(TextBox.Focused, function()
						if menu.busy then
							TextBox:ReleaseFocus()
							return
						end
						if TextBox.Text == "_" then
							TextBox.Text = ""
						end
						TextBox.TextColor3 = menu.accent_color
					end)

					utility.newConnection(TextBox:GetPropertyChangedSignal("Text"), function()
						local text = lower(TextBox.Text)
						if text == "_" then return end
						local children = OptionHolder:GetChildren()
						for i = 1, #children do
							local object = children[i]
							if object:IsA("TextLabel") then
								if text == "" or lower(object.Name):find(text) then
									object.Visible = true
								else
									object.Visible = false
								end
							end
						end
					end)

					Frame.Size = udim2new(1,0,0,(20*_info.max) + 20)
					Inside.Size = udim2new(0.72,0,1,-20)
					Inside.Position = udim2new(0,19,0,19)

					insert(new_element.closing, function(bypass)
						if not tab_frame.Visible and not bypass then return end
						local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
						tween(Search, info, {BackgroundTransparency = 1})
						tween(SearchInside, info, {BackgroundTransparency = 1})
						tween(SearchInside2, info, {BackgroundTransparency = 1})
						tween(TextBox, info, {TextTransparency = 1})
						tween(ScrollBackground, info, {BackgroundTransparency = 1})
						tween(BottomShadow, info, {ImageTransparency = 1})
						tween(TopShadow, info, {ImageTransparency = 1})
						tween(ArrowDown, info, {ImageTransparency = 1})
						tween(ArrowUp, info, {ImageTransparency = 1})
						tween(Inside, info, {BackgroundTransparency = 1})
						tween(Inside2, info, {BackgroundTransparency = 1})
						tween(Scroller, info, {ScrollBarImageTransparency = 1})
						for _, object in OptionHolder:GetChildren() do
							if object:IsA("TextLabel") then
								tween(object, info, {TextTransparency = 1})
							end
						end
					end, true)

					insert(new_element.opening, function(bypass)
						if not tab_frame.Visible and not bypass then return end
						local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
						tween(Search, info, {BackgroundTransparency = 0})
						tween(SearchInside, info, {BackgroundTransparency = 0})
						tween(SearchInside2, info, {BackgroundTransparency = 0})
						tween(TextBox, info, {TextTransparency = 0})
						tween(ScrollBackground, info, {BackgroundTransparency = 0})
						tween(BottomShadow, info, {ImageTransparency = 0})
						tween(TopShadow, info, {ImageTransparency = 0})
						if Scroller.CanvasPosition.Y/Scroller.AbsoluteCanvasSize.Y < 0.5 then
							tween(ArrowUp, info, {ImageTransparency = 0})
						else
							tween(ArrowDown, info, {ImageTransparency = 0})
						end
						tween(Inside, info, {BackgroundTransparency = 0})
						tween(Inside2, info, {BackgroundTransparency = 0})
						tween(Scroller, info, {ScrollBarImageTransparency = 0})
						for _, object in OptionHolder:GetChildren() do
							if object:IsA("TextLabel") then
								tween(object, info, {TextTransparency = 0})
							end
						end
					end, true)
				else
					insert(new_element.closing, function(bypass)
						if not tab_frame.Visible and not bypass then return end
						local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
						tween(ScrollBackground, info, {BackgroundTransparency = 1})
						tween(BottomShadow, info, {ImageTransparency = 1})
						tween(TopShadow, info, {ImageTransparency = 1})
						tween(ArrowDown, info, {ImageTransparency = 1})
						tween(ArrowUp, info, {ImageTransparency = 1})
						tween(Inside, info, {BackgroundTransparency = 1})
						tween(Inside2, info, {BackgroundTransparency = 1})
						tween(Scroller, info, {ScrollBarImageTransparency = 1})
						for _, object in OptionHolder:GetChildren() do
							if object:IsA("TextLabel") then
								tween(object, info, {TextTransparency = 1})
							end
						end
					end, true)

					insert(new_element.opening, function(bypass)
						if not tab_frame.Visible and not bypass then return end
						local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
						tween(ScrollBackground, info, {BackgroundTransparency = 0})
						tween(BottomShadow, info, {ImageTransparency = 0})
						tween(TopShadow, info, {ImageTransparency = 0})
						tween(ArrowDown, info, {ImageTransparency = 0})
						tween(ArrowUp, info, {ImageTransparency = 0})
						tween(Inside, info, {BackgroundTransparency = 0})
						tween(Inside2, info, {BackgroundTransparency = 0})
						tween(Scroller, info, {ScrollBarImageTransparency = 0})
						for _, object in OptionHolder:GetChildren() do
							if object:IsA("TextLabel") then
								tween(object, info, {TextTransparency = 0})
							end
						end
					end)
				end

				local function updateSize()
					if OptionHolder.AbsoluteSize.Y > Inside.AbsoluteSize.Y then
						Scroller.CanvasSize = udim2new(0,0,1,0)
						Scroller.ScrollingEnabled = true
						Scroller.ScrollBarImageTransparency = 0
						ScrollBackground.Visible = true
						ArrowUp.Visible = true
						ArrowDown.Visible = true
						ScrollBackground.Visible = true
						BottomShadow.Visible = true
						TopShadow.Visible = true
					else
						Scroller.ScrollingEnabled = false
						Scroller.ScrollBarImageTransparency = 1
						ScrollBackground.Visible = false
						ArrowUp.Visible = false
						ArrowDown.Visible = false
						ScrollBackground.Visible = false
						BottomShadow.Visible = false
						TopShadow.Visible = false
					end
				end

				utility.newConnection(Scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"), function()
					ArrowUp.Visible = (Scroller.CanvasPosition.Y > 1)
					ArrowDown.Visible = (Scroller.CanvasPosition.Y + 1 < (Scroller.AbsoluteCanvasSize.Y - Scroller.AbsoluteSize.Y))
				end)

				utility.newConnection(Scroller:GetPropertyChangedSignal("CanvasPosition"), function()
					ArrowUp.Visible = (Scroller.CanvasPosition.Y > 1)
					ArrowDown.Visible = (Scroller.CanvasPosition.Y + 1 < (Scroller.AbsoluteCanvasSize.Y - Scroller.AbsoluteSize.Y))
				end)

				utility.newConnection(OptionHolder:GetPropertyChangedSignal("AbsoluteSize"), updateSize)
				utility.newConnection(Scroller:GetPropertyChangedSignal("CanvasSize"), updateSize)

				updateSize()

				utility.newConnection(ArrowUp.InputBegan, function(input, gpe)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						Scroller.CanvasPosition = vector2new(0,0)
					end
				end)

				utility.newConnection(ArrowDown.InputBegan, function(input, gpe)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						Scroller.CanvasPosition = vector2new(0,Scroller.AbsoluteCanvasSize.Y)
					end
				end)

				new_element.selected_option = nil
				new_element.onSelectionChange = signal.new()

				function new_element:removeAllOptions()
					local children = OptionHolder:GetChildren()
					for i = 1, #children do
						local option = children[i]
						if option.ClassName == "TextLabel" then
							destroy(option)
						end
					end
					new_element:setSelected(nil, true)
				end

				function new_element:setSelected(text, no)
					text = text or ""
					if new_element.selected_option == text then return end
					local old_option = new_element.selected_option and findfirstchild(OptionHolder, new_element.selected_option) or nil
					if old_option and old_option.ClassName == "TextLabel" then
						old_option.FontFace = menu_font
						old_option.TextColor3 = colorfromrgb(208,208,208)
					end
					local option = findfirstchild(OptionHolder, text)
					if not option or option.ClassName ~= "TextLabel" then
						new_element.selected_option = nil
						new_element.onSelectionChange:Fire(nil)
						return
					end
					new_element.selected_option = text
					if not no then
						new_element.onSelectionChange:Fire(text)
					end
					option.FontFace = menu_font_bold
					option.TextColor3 = menu.accent_color
				end

				function new_element:removeOption(text)
					local option = findfirstchild(OptionHolder, text)
					if option then
						destroy(option)
					end
					if new_element.selected_option == text then
						new_element:setSelected(nil)
					end
				end

				utility.newConnection(menu.on_accent_change, function(color)
					local option = new_element.selected_option
					if not option then return end
					local label = findfirstchild(OptionHolder, option)
					if not label then return end
					label.TextColor3 = color
				end)

				function new_element:addOption(text)
					local MultiOption = newObject("TextLabel", {BackgroundColor3 = colorfromrgb(25,25,25), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,0,20), ZIndex = 25, FontFace = menu_font, Text = "     "..text, TextColor3 = colorfromrgb(208,208,208), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = OptionHolder})
					MultiOption.Name = text

					utility.newConnection(MultiOption.MouseEnter, function()
						MultiOption.BackgroundTransparency = 0
						if new_element.selected_option == text then return end
						MultiOption.FontFace = menu_font_bold
					end)

					utility.newConnection(MultiOption.MouseLeave, function()
						MultiOption.BackgroundTransparency = 1
						if new_element.selected_option == text then return end
						MultiOption.FontFace = menu_font
					end)

					utility.newConnection(MultiOption.InputBegan, function(input, gpe)
						if gpe or menu.busy then return end
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							new_element:setSelected(text)
						end
					end)
				end
			elseif lower(_element) == "textbox" then
				total+=1
				Frame.Size = udim2new(1,0,0,20)
				local Textbox = newObject("Frame", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Size = udim2new(1,0,0,20), BackgroundTransparency = 1, Parent = Frame})
				local Inside = newObject("Frame", {BackgroundColor3 = colorfromrgb(12,12,12), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,19,0,0), Size = udim2new(0.72,0,0,20), BackgroundTransparency = 1, Parent = Textbox})
				local Inside2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(50,50,50), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), BackgroundTransparency = 1, Parent = Inside})
				local Inside3 = newObject("Frame", {BackgroundColor3 = colorfromrgb(24,24,24), BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,1,-2), BackgroundTransparency = 1, Parent = Inside2})
				local TextBox = newObject("TextBox", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderColor3 = colorfromrgb(0,0,0), BorderSizePixel = 0, Position = udim2new(0,5,0,0), Size = udim2new(1,-5,1,0), ZIndex = 2, FontFace = menu_font_bold, Text = "_", TextColor3 = colorfromrgb(208,208,208), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, TextTransparency = 1, Parent = Inside3})
				newObject("UISizeConstraint", {MaxSize = vector2new(200,9e9), Parent = Inside})

				flags[_info.flag] = ""
				Label.Visible = false
				new_element.onTextChange = signal.new()

				function new_element:setText(text)
					text = text or ""
					if TextBox.Text ~= text then
						TextBox.Text = text
					end
					flags[_info.flag] = text
					new_element.onTextChange:Fire(text)
				end

				utility.newConnection(TextBox.FocusLost, function()
					TextBox.TextColor3 = colorfromrgb(208,208,208)
					if TextBox.Text == "" then
						TextBox.Text = "_"
					end
				end)

				utility.newConnection(TextBox.Focused, function()
					if menu.busy then
						TextBox:ReleaseFocus()
						return
					end
					if TextBox.Text == "_" then
						TextBox.Text = ""
					end
					TextBox.TextColor3 = menu.accent_color
				end)

				utility.newConnection(TextBox:GetPropertyChangedSignal("Text"), function()
					local text = lower(TextBox.Text)
					if text == "_" then
						new_element:setText(nil)
						return
					end
					new_element:setText(TextBox.Text)
				end)

				insert(new_element.closing, function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(Inside, info, {BackgroundTransparency = 1})
					tween(Inside2, info, {BackgroundTransparency = 1})
					tween(Inside3, info, {BackgroundTransparency = 1})
					tween(TextBox, info, {TextTransparency = 1})
				end, true)

				insert(new_element.opening, function(bypass)
					if not tab_frame.Visible and not bypass then return end
					local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
					tween(Inside, info, {BackgroundTransparency = 0})
					tween(Inside2, info, {BackgroundTransparency = 0})
					tween(Inside3, info, {BackgroundTransparency = 0})
					tween(TextBox, info, {TextTransparency = 0})
				end, true)

				if not _info.no_load then
					utility.newConnection(menu.on_load, function()
						new_element:setText(flags[_info.flag])
					end, true)
				end
			end
		end

		insert(new_element.closing, function(bypass)
			if not tab_frame.Visible and not bypass then return end
			local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
			tween(Label, info, {TextTransparency = 1})
		end)

		insert(new_element.opening, function(bypass)
			if not new_element.visible then return end
			if not tab_frame.Visible and not bypass then return end
			local info = bypass and newtweeninfo(menu.animation_speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or tween_info
			tween(Label, info, {TextTransparency = 0})
		end)

		for _, opening in new_element.opening do
			utility.newConnection(menu.on_opening, opening)
		end

		for _, closing in new_element.closing do
			utility.newConnection(menu.on_closing, closing)
		end

		new_element.og_size = Frame.Size

		self.elements[info.name] = new_element

		return new_element
	end

	function element:Destroy()
		destroy(self.frame)
		setmetatable(self, nil)
	end

	function element:setText(text)
		self.label.Text = text
	end

	function element:setVisible(bool, force)
		local speed = force and 0 or menu.animation_speed
		self.visible = bool

		for _, func in self[bool and "opening" or "closing"] do
			spawn(func, true)
		end

		if bool then
			self.frame.Visible = true
		end

		tween(self.frame, newtweeninfo(menu.animation_speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = bool and ((self.slider_visible == false or self.dropdown_visible == false) and udim2new(1,0,0,8) or self.og_size) or udim2new(1,0,0,-10)})

		delay(speed, function()
			if not bool and not self.visible then
				self.frame.Visible = false
			end
		end)
	end

	utility.newConnection(uis.InputBegan, LPH_NO_VIRTUALIZE(function(input, gpe)
		if gpe then return end
		local keycode = shortened_characters[input.UserInputType] and input.UserInputType or input.KeyCode
		if keycode then
			if string.upper(input.KeyCode.Name) == menu.toggle then
				if menu.is_open then menu.on_closing:Fire() else menu.on_opening:Fire() end
				return
			end
			local keybinds = menu.keybinds[keycode]
			if keybinds then
				for _, info in keybinds do
					local flag = info[2]
					if flags[flag].method == 2 then
						info[1]:setActive(true)
					elseif flags[flag].method == 3 then
						info[1]:setActive(not menu.flags[flag].active)
					end
				end
			end
		end
	end), true)

	utility.newConnection(uis.InputEnded, LPH_NO_VIRTUALIZE(function(input, gpe)
		local keycode = shortened_characters[input.UserInputType] and input.UserInputType or input.KeyCode
		if keycode then
			local keybinds = menu.keybinds[keycode]
			if keybinds then
				for _, info in keybinds do
					local flag = info[2]
					if flags[flag].method == 2 then
						info[1]:setActive(false)
					end
				end
			end
		end
	end), true)
end

getgenv().unload_mangosense = function()
	for flag, value in pairs(flags) do
		if typeof(value) == "boolean" then
			flags[flag] = false
		end
	end
	pcall(function() menu.on_load:Fire() end)
	for _, connection in utility.connections do
		if connection then
			pcall(function() connection:Disconnect() end)
			utility.connections[_] = nil
		end
	end
	pcall(function() destroy(_screenGui) end)
	getgenv().unload_mangosense = nil
end

local window = menu:init(
	{
		[1] = {icon = "rbxassetid://18248771514"},
		[2] = {icon = "rbxassetid://15453313321"},
		[3] = {icon = "rbxassetid://15453335745", subtabs = {name = "Category", options = {{image = "rbxassetid://18686402989"}, {image = "rbxassetid://18657040454"}, {image = "rbxassetid://18205704829"}, {image = "rbxassetid://18205706952"}, {image = "rbxassetid://18205822505"}}}},
		[4] = {icon = "rbxassetid://15453344494", subtabs = {name = "Category", options = {{image = "rbxassetid://18334627891"}, {image = "rbxassetid://18334630306"}, {image = "rbxassetid://18334626899"}, {image = "rbxassetid://18334625304"}}}},
		[5] = {icon = "rbxassetid://15453349637"},
		[6] = {icon = "rbxassetid://15453354931"},
		[7] = {icon = "rbxassetid://15453359751"},
		[8] = {icon = "rbxassetid://15453364412"},
		[9] = {icon = "rbxassetid://18240049800"}
	},
	4
)

local old_list = utility.getConfigList()
local old_script_list = utility.getScriptList()
local script_environment = {}
local script_unloaded = signal.new()

do
	local rage = window:getTab(1)
	local anti_aim = window:getTab(2)
	local legit = window:getTab(3)
	legit:_setActiveSubtab(1)
	local visuals = window:getTab(4)
	local misc = window:getTab(5)
	local skins_tab = window:getTab(6)
	local players_tab = window:getTab(7)
	local configuration = window:getTab(8)
	local config_section = configuration:newSection({name = "Configs", is_changeable = false, scale = 0.8})
	local config_list = config_section:newElement({name = "Config list", types = {multibox = {max = 8, search = true}}})
	config_section:newElement({name = "Update config", types = {button = {confirmation = true, text = "Update config",
		callback = function()
			local option = config_list.selected_option
			if option then
				utility.saveConfig(option)
				for _, config in old_list do
					config_list:removeOption(config)
				end
				old_list = utility.getConfigList()
				for _, config in old_list do
					config_list:addOption(config)
				end
			end
		end
	}}})
	config_section:newElement({name = "Load config", types = {button = {confirmation = true, text = "Load config",
		callback = function()
			if config_list.selected_option then
				for lua, _ in script_environment do
					task.cancel(script_environment[lua])
					script_environment[lua] = nil
					script_unloaded:Fire(lua)
					flags["loaded_scripts"] = {}
				end
				local config = utility.convertConfig(config_list.selected_option)
				if config["loaded_scripts"] then
					for _, script in config["loaded_scripts"] do
						local data = nil
						pcall(function()
							data = readfile(config_location.."/addons/"..script..".lua")
						end)
						if not data then continue end
						wait()
						local s, err = pcall(function()
							script_environment[script] = spawn(loadstring(data))
						end)
					end
				end
				utility.loadConfig(config)
				delay(0, function()
					menu.on_load:Fire()
				end)
			end
		end
	}}})
	config_section:newElement({name = "Config name", types = {textbox = {no_load = true, flag = "config_name"}}})
	config_section:newElement({name = "Create config", types = {button = {confirmation = true, text = "Create config",
		callback = function()
			if flags["config_name"] and #flags["config_name"] > 0 then
				utility.saveConfig(flags["config_name"])
				for _, config in old_list do
					config_list:removeOption(config)
				end
				old_list = utility.getConfigList()
				for _, config in old_list do
					config_list:addOption(config)
				end
			end
		end
	}}})
	config_section:newElement({name = "Refresh list", types = {button = {text = "Refresh list",
		callback = function()
			for _, config in old_list do
				config_list:removeOption(config)
			end
			old_list = utility.getConfigList()
			for _, config in old_list do
				config_list:addOption(config)
			end
		end
	}}})
	for _, config in old_list do
		config_list:addOption(config)
	end
	local lua = window:getTab(9)
	local a_section = lua:newSection({name = "Tab A", scale = 1})
	local b_section = lua:newSection({name = "Tab B", scale = 1, x = 0.5})
	local lua_section = configuration:newSection({name = "LUA", is_changeable = false, x = 0.5, scale = 1})
	local script_list = lua_section:newElement({name = "Script list", types = {multibox = {max = 2, search = true}}})
	lua_section:newElement({name = "Load script", types = {button = {text = "Load script",
		callback = function()
			if script_list.selected_option and not script_environment[script_list.selected_option] then
				local data = nil
				pcall(function()
					data = readfile(config_location.."/addons/"..script_list.selected_option..".lua")
				end)
				if not data then
					error("mangosense\n\tfailed to read script \""..script_list.selected_option.."\"")
					return
				end
				local new_script_list = utility.getScriptList()
				for name, lua in script_environment do
					if not find(new_script_list, name..".lua") then
						task.cancel(lua)
						script_environment[name] = nil
						if find(flags["loaded_scripts"], name) then
							remove(flags["loaded_scripts"], name)
						end
					end
				end
				wait()
				local s, err = pcall(function()
					script_environment[script_list.selected_option] = spawn(loadstring(data))
				end)
				if not find(flags["loaded_scripts"], script_list.selected_option) then
					insert(flags["loaded_scripts"], script_list.selected_option)
				end
				if not s then
					error(err)
				end
			end
		end
	}}})
	lua_section:newElement({name = "Unload script", types = {button = {text = "Unload script",
		callback = function()
			if script_list.selected_option and script_environment[script_list.selected_option] then
				local lua = script_list.selected_option
				if not lua then
					error("mangosense\n\tfailed to unload script \""..script_list.selected_option.."\"")
					return
				end
				task.cancel(script_environment[lua])
				if find(flags["loaded_scripts"], lua) then
					remove(flags["loaded_scripts"], lua)
				end
				script_environment[lua] = nil
				script_unloaded:Fire(lua)
			end
		end
	}}})
	lua_section:newElement({name = "Refresh list", types = {button = {text = "Refresh list",
		callback = function()
			for _, lua in old_script_list do
				script_list:removeOption(lua)
			end
			old_script_list = utility.getScriptList()
			for _, lua in old_script_list do
				script_list:addOption(lua)
			end
		end
	}}})
	for _, lua in old_script_list do
		script_list:addOption(lua)
	end
	local menu_section = configuration:newSection({name = "Menu", is_changeable = false, y = 0.8, scale = 0.2})
	utility.newConnection(menu_section:newElement({name = "Menu key", types = {keybind = {flag = "menu_key", key = Enum.KeyCode.Delete, method = 2, method_locked = true}}}).onActiveChange, function()
		if flags["menu_key"]["key"] ~= nil then
			menu["toggle"] = string.upper(flags["menu_key"]["key"]["Name"])
		end
	end)
	utility.newConnection(menu_section:newElement({name = "Menu color", types = {colorpicker = {flag = "menu_accent", transparency_flag = "", default = menu.accent_color}}}).onColorChange, function(color)
		menu:set_accent_color(color)
	end)
	utility.newConnection(menu_section:newElement({name = "Menu animation speed", types = {slider = {flag = "animation_speed", default = 100, min = 0, max = 150, min_text = "Off", prefix = "", suffix = "%"}}}).onSliderChange, function(value)
		menu["animation_speed"] = value == 0 and value or 0.5 - value/300
	end)
	menu_section:newElement({name = "Unload cheat", types = {button = {text = "Unload cheat",
		callback = function()
			getgenv().unload_mangosense()
		end
	}}})
	menu_section:newElement({name = "Disable all", types = {button = {text = "Disable all",
		callback = function()
			for flag, value in pairs(flags) do
				if typeof(value) == "boolean" then
					flags[flag] = false
				end
			end
			menu.on_load:Fire()
		end
	}}})
	window:_setActiveTab(8)
end

do
	local _skeet_font = getgenv().mangosense_font or Font.fromId(12187371840)
	local _skeet_font_bold = getgenv().mangosense_font_bold or Font.fromId(12187371840, Enum.FontWeight.Bold)

	local KBL_Gui = Instance.new("ScreenGui")
	KBL_Gui.Name = "mangosense_keybindlist"
	KBL_Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	KBL_Gui.ResetOnSpawn = false
	KBL_Gui.Enabled = true
	KBL_Gui.Parent = cg

	local KBL = newObject("Frame", {AnchorPoint = vector2new(0,0.5), BackgroundColor3 = colorfromrgb(60,60,60), BackgroundTransparency = 0, BorderColor3 = colorfromrgb(12,12,12), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 1, Position = udim2new(0,15,0.5,0), Size = udim2new(0,225,0,0), ZIndex = 50, Parent = KBL_Gui})

	newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BackgroundTransparency = 0, BorderSizePixel = 0, Position = udim2new(0,2,0,2), Size = udim2new(1,-4,1,-4), ZIndex = 51, Parent = KBL})

	local KBL_Inner = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BorderColor3 = colorfromrgb(60,60,60), Position = udim2new(0,3,0,3), Size = udim2new(1,-6,1,-6), Image = "rbxassetid://15453092054", ScaleType = Enum.ScaleType.Tile, TileSize = udim2new(0,4,0,400), ClipsDescendants = true, ZIndex = 52, Parent = KBL})

	newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,0,2), ZIndex = 53, Image = "rbxassetid://15453122383", Parent = KBL_Inner})

	local KBL_List = newObject("Frame", {Name = "listframe", BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(0,0,0,4), Size = udim2new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 55, Parent = KBL_Inner})

	newObject("UIListLayout", {Padding = UDim.new(0,0), FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder, Parent = KBL_List})

	newObject("UIPadding", {PaddingBottom = UDim.new(0,6), PaddingLeft = UDim.new(0,12), PaddingRight = UDim.new(0,8), Parent = KBL_List})
	newObject("TextLabel", {AnchorPoint = vector2new(0,0), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = -1, Position = udim2new(0,0,0,0), Size = udim2new(1,0,0,20), ZIndex = 56, FontFace = _skeet_font_bold, RichText = false, Text = "Keybinds", TextColor3 = colorfromrgb(198,198,198), TextSize = 13, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, Parent = KBL_List})

	utility.newConnection(KBL_Layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		KBL.Size = udim2new(0,225,0,KBL_Layout.AbsoluteContentSize.Y + 12)
	end)

	local kbl_entries = {}

	local function kbl_removeEntry(flag)
		if kbl_entries[flag] then
			kbl_entries[flag]:Destroy()
			kbl_entries[flag] = nil
		end
	end

	local function kbl_prettyName(flag)
		return (flag:gsub("_", " "):gsub("(%a)([%w]*)", function(a,b)
			return string.upper(a) .. b
		end))
	end

	local function kbl_upsertEntry(flag, displayName, keyTxt, isActive)
		local accent = menu.accent_color or colorfromrgb(255,120,30)
		local textCol = isActive and accent or colorfromrgb(150,150,150)
		local keyCol = isActive and accent or colorfromrgb(150,150,150)

		if not kbl_entries[flag] then
			local row = newObject("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 1, Size = udim2new(1,0,0,17), ZIndex = 56, Parent = KBL_List})
			newObject("TextLabel", {BackgroundTransparency = 1, Position = udim2new(0,0,0,0), Size = udim2new(0.62,0,1,0), Name = "NL", ZIndex = 57, FontFace = _skeet_font, Text = displayName, TextColor3 = textCol, TextSize = 13, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Parent = row})
			newObject("TextLabel", {BackgroundTransparency = 1, Position = udim2new(0.62,0,0,0), Size = udim2new(0.38,0,1,0), Name = "KL", ZIndex = 57, FontFace = _skeet_font, Text = "[" .. keyTxt .. "]", TextColor3 = keyCol, TextSize = 13, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right, Parent = row})
			kbl_entries[flag] = row
		else
			local row = kbl_entries[flag]
			local nl = row:FindFirstChild("NL")
			local kl = row:FindFirstChild("KL")
			if nl then nl.Text = displayName; nl.TextColor3 = textCol end
			if kl then kl.Text = "[" .. keyTxt .. "]"; kl.TextColor3 = keyCol end
		end
	end

	local kbl_short = {
		[Enum.KeyCode.LeftShift] = "LSHF",
		[Enum.KeyCode.RightShift] = "RSHF",
		[Enum.UserInputType.MouseButton1] = "M1",
		[Enum.UserInputType.MouseButton2] = "M2",
		[Enum.UserInputType.MouseButton3] = "M3",
		[Enum.KeyCode.Delete] = "DEL",
		[Enum.KeyCode.Insert] = "INS",
		[Enum.KeyCode.PageUp] = "PGUP",
		[Enum.KeyCode.PageDown] = "PGDW",
		[Enum.KeyCode.LeftControl] = "LCTR",
		[Enum.KeyCode.RightControl] = "RCTR",
		[Enum.KeyCode.LeftAlt] = "LALT",
		[Enum.KeyCode.RightAlt] = "RALT",
		[Enum.KeyCode.CapsLock] = "CAPS",
		[Enum.KeyCode.Space] = "SPC",
		[Enum.KeyCode.Backspace] = "BSPC",
		[Enum.KeyCode.ScrollLock] = "SLCK",
	}

	local function kbl_keyText(kc)
		if not kc then return nil end
		return kbl_short[kc] or string.upper(kc.Name)
	end

	local kbl_seen = {}

	utility.newConnection(rs.Heartbeat, function()
		for f in pairs(kbl_seen) do kbl_seen[f] = false end

		for keycode, list in pairs(menu.keybinds) do
			local kt = kbl_keyText(keycode)
			if kt then
				for _, info in ipairs(list) do
					local flag = info[2]
					if flag and flags[flag] then
						kbl_upsertEntry(
							flag,
							kbl_prettyName(flag),
							kt,
							flags[flag].active
						)
						kbl_seen[flag] = true
					end
				end
			end
		end

		for f, present in pairs(kbl_seen) do
			if not present then
				kbl_removeEntry(f)
				kbl_seen[f] = nil
			end
		end
	end)

	local kbl_drag, kbl_dragIn, kbl_dragStart, kbl_startPos = false, nil, nil, nil

	utility.newConnection(KBL.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			kbl_drag = true
			kbl_dragStart = input.Position
			kbl_startPos = KBL.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					kbl_drag = false
				end
			end)
		end
	end)

	utility.newConnection(KBL.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			kbl_dragIn = input
		end
	end)

	utility.newConnection(rs.Heartbeat, function()
		if kbl_drag and kbl_dragIn and kbl_startPos then
			local d = kbl_dragIn.Position - kbl_dragStart
			KBL.Position = udim2new(kbl_startPos.X.Scale, kbl_startPos.X.Offset + d.X, kbl_startPos.Y.Scale, kbl_startPos.Y.Offset + d.Y)
		end
	end)

	local _kbl_prev_unload = getgenv().unload_mangosense
	getgenv().unload_mangosense = function(...)
		pcall(function() KBL_Gui:Destroy() end)
		if _kbl_prev_unload then _kbl_prev_unload(...) end
	end
end

do
	local th_font = getgenv().mangosense_font or Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	local th_font_bold = getgenv().mangosense_font_bold or Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

	local TH_connections = {}
	local function th_connect(signal, callback)
		local conn = signal:Connect(callback)
		TH_connections[#TH_connections + 1] = conn
		return conn
	end

	local G = {
		gui = Instance.new("ScreenGui"),
		frame = Instance.new("Frame"),
		frame1 = Instance.new("Frame"),
		frame2 = Instance.new("ImageLabel"),
		frame3 = Instance.new("Frame"),
		padding = Instance.new("UIPadding"),
		holder = Instance.new("Frame"),
		frame4 = Instance.new("Frame"),
		frame5 = Instance.new("Frame"),
		padding1 = Instance.new("UIPadding"),
		frame6 = Instance.new("Frame"),
		frame7 = Instance.new("Frame"),
		frame8 = Instance.new("Frame"),
		gradient = Instance.new("UIGradient"),
		padding2 = Instance.new("UIPadding"),
		frame9 = Instance.new("Frame"),
		layout = Instance.new("UIListLayout"),
		padding3 = Instance.new("UIPadding"),
		frame10 = Instance.new("Frame"),
		frame11 = Instance.new("Frame"),
		frame12 = Instance.new("Frame"),
		gradient1 = Instance.new("UIGradient"),
		bar = Instance.new("Frame"),
		gradient2 = Instance.new("UIGradient"),
		holder1 = Instance.new("Frame"),
		padding4 = Instance.new("UIPadding"),
		playerinfo = Instance.new("Frame"),
		icon = Instance.new("Frame"),
		frame13 = Instance.new("Frame"),
		frame14 = Instance.new("Frame"),
		image = Instance.new("ImageLabel"),
		gradient3 = Instance.new("UIGradient"),
		health = Instance.new("Frame"),
		frame15 = Instance.new("Frame"),
		frame16 = Instance.new("Frame"),
		gradient4 = Instance.new("UIGradient"),
		healthbar = Instance.new("Frame"),
		gradient5 = Instance.new("UIGradient"),
		healthvalue = Instance.new("TextLabel"),
		stroke = Instance.new("UIStroke"),
		frame17 = Instance.new("Frame"),
		layout1 = Instance.new("UIListLayout"),
		name = Instance.new("TextLabel"),
		stroke1 = Instance.new("UIStroke"),
		studs = Instance.new("TextLabel"),
		stroke2 = Instance.new("UIStroke"),
		armor = Instance.new("Frame"),
		frame18 = Instance.new("Frame"),
		frame19 = Instance.new("Frame"),
		gradient6 = Instance.new("UIGradient"),
		armorbar = Instance.new("Frame"),
		gradient7 = Instance.new("UIGradient"),
		armorvalue = Instance.new("TextLabel"),
		stroke3 = Instance.new("UIStroke"),
		top = Instance.new("Frame"),
		title = Instance.new("TextLabel"),
		padding5 = Instance.new("UIPadding"),
		stroke4 = Instance.new("UIStroke"),
		top1 = Instance.new("Frame"),
		subtitle = Instance.new("TextLabel"),
		padding6 = Instance.new("UIPadding"),
		stroke5 = Instance.new("UIStroke"),
		glow = Instance.new("ImageLabel"),
	}

	G.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	G.gui.Name = "mangosense_targethud"
	G.gui.ResetOnSpawn = false
	G.gui.Enabled = true
	G.gui.Parent = cg

	G.frame.AnchorPoint = Vector2.new(1,0)
	G.frame.BackgroundColor3 = Color3.fromRGB(60,60,60)
	G.frame.BorderColor3 = Color3.fromRGB(12,12,12)
	G.frame.BorderSizePixel = 1
	G.frame.Position = UDim2.new(1,-70,0,10)
	G.frame.Size = UDim2.new(0,326,0,151)
	G.frame.Parent = G.gui

	G.frame1.BackgroundColor3 = Color3.fromRGB(40,40,40)
	G.frame1.BackgroundTransparency = 0
	G.frame1.BorderSizePixel = 0
	G.frame1.Size = UDim2.new(1,-4,1,-4)
	G.frame1.Position = UDim2.new(0,2,0,2)
	G.frame1.Parent = G.frame

	G.frame2.BackgroundColor3 = Color3.fromRGB(255,255,255)
	G.frame2.BorderSizePixel = 0
	G.frame2.Image = "rbxassetid://15453092054"
	G.frame2.ScaleType = Enum.ScaleType.Tile
	G.frame2.TileSize = UDim2.new(0,4,0,151)
	G.frame2.ClipsDescendants = true
	G.frame2.Position = UDim2.new(0,3,0,3)
	G.frame2.Size = UDim2.new(1,-6,1,-6)
	G.frame2.Parent = G.frame

	G.frame3.BackgroundTransparency = 1
	G.frame3.BorderSizePixel = 0
	G.frame3.Position = UDim2.new(0,1,0,4)
	G.frame3.Size = UDim2.new(1,-2,1,-6)
	G.frame3.Parent = G.frame2

	G.padding.PaddingLeft = UDim.new(0,6)
	G.padding.Parent = G.frame3

	G.holder.BackgroundColor3 = Color3.fromRGB(16,16,16)
	G.holder.BorderSizePixel = 0
	G.holder.Position = UDim2.new(0,-3,0,16)
	G.holder.Size = UDim2.new(1,0,1,-18)
	G.holder.Name = "holder"
	G.holder.Parent = G.frame3

	G.frame4.BackgroundTransparency = 1
	G.frame4.BorderSizePixel = 0
	G.frame4.Position = UDim2.new(0,1,0,1)
	G.frame4.Size = UDim2.new(1,-2,1,-2)
	G.frame4.Parent = G.holder

	G.frame5.BackgroundTransparency = 1
	G.frame5.BorderSizePixel = 0
	G.frame5.Position = UDim2.new(0,1,0,1)
	G.frame5.Size = UDim2.new(1,-2,1,-2)
	G.frame5.Parent = G.frame4

	G.padding1.PaddingLeft = UDim.new(0,4)
	G.padding1.PaddingTop = UDim.new(0,4)
	G.padding1.Parent = G.frame5

	G.frame6.BackgroundTransparency = 1
	G.frame6.BorderSizePixel = 0
	G.frame6.Size = UDim2.new(1,-4,1,-4)
	G.frame6.Parent = G.frame5

	G.frame7.BackgroundTransparency = 1
	G.frame7.BorderSizePixel = 0
	G.frame7.Position = UDim2.new(0,1,0,1)
	G.frame7.Size = UDim2.new(1,-2,1,-2)
	G.frame7.Parent = G.frame6

	G.frame8.BackgroundColor3 = Color3.fromRGB(255,255,255)
	G.frame8.BorderSizePixel = 0
	G.frame8.Position = UDim2.new(0,1,0,1)
	G.frame8.Size = UDim2.new(1,-2,1,-2)
	G.frame8.Parent = G.frame7

	G.gradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(38,38,38)), ColorSequenceKeypoint.new(1, Color3.fromRGB(38,38,38))}
	G.gradient.Rotation = 90
	G.gradient.Parent = G.frame8

	G.padding2.PaddingBottom = UDim.new(0,1)
	G.padding2.PaddingLeft = UDim.new(0,1)
	G.padding2.PaddingRight = UDim.new(0,1)
	G.padding2.PaddingTop = UDim.new(0,1)
	G.padding2.Parent = G.frame8

	G.frame9.BackgroundTransparency = 1
	G.frame9.BorderSizePixel = 0
	G.frame9.Size = UDim2.new(1,0,1,0)
	G.frame9.Parent = G.frame8

	G.layout.Padding = UDim.new(0,4)
	G.layout.SortOrder = Enum.SortOrder.LayoutOrder
	G.layout.Parent = G.frame9

	G.padding3.PaddingBottom = UDim.new(0,4)
	G.padding3.Parent = G.frame9

	G.frame10.BackgroundTransparency = 1
	G.frame10.BorderSizePixel = 0
	G.frame10.Size = UDim2.new(1,-1,1,0)
	G.frame10.Parent = G.frame9

	G.frame11.BackgroundTransparency = 1
	G.frame11.BorderSizePixel = 0
	G.frame11.Position = UDim2.new(0,1,0,1)
	G.frame11.Size = UDim2.new(1,-2,1,-2)
	G.frame11.Parent = G.frame10

	G.frame12.BackgroundColor3 = Color3.fromRGB(23,23,23)
	G.frame12.BorderSizePixel = 0
	G.frame12.Position = UDim2.new(0,1,0,1)
	G.frame12.Size = UDim2.new(1,-2,1,-2)
	G.frame12.Parent = G.frame11

	G.gradient1.Enabled = false
	G.gradient1.Parent = G.frame12

	G.bar.BackgroundTransparency = 1
	G.bar.BorderSizePixel = 0
	G.bar.Size = UDim2.new(1,0,0,2)
	G.bar.Name = "bar"
	G.bar.Parent = G.frame12

	G.gradient2.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(0,100,0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,80,0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(0,100,0))}
	G.gradient2.Parent = G.bar

	G.holder1.BackgroundTransparency = 1
	G.holder1.BorderSizePixel = 0
	G.holder1.Position = UDim2.new(0,1,0,22)
	G.holder1.Size = UDim2.new(1,-2,1,-24)
	G.holder1.Name = "holder"
	G.holder1.Parent = G.frame12

	G.padding4.PaddingBottom = UDim.new(0,2)
	G.padding4.PaddingLeft = UDim.new(0,3)
	G.padding4.PaddingRight = UDim.new(0,3)
	G.padding4.PaddingTop = UDim.new(0,-1)
	G.padding4.Parent = G.holder1

	G.playerinfo.BackgroundTransparency = 1
	G.playerinfo.BorderSizePixel = 0
	G.playerinfo.Size = UDim2.new(1,0,1,0)
	G.playerinfo.Name = "playerinfo"
	G.playerinfo.Parent = G.holder1

	G.icon.BackgroundColor3 = Color3.fromRGB(10,10,10)
	G.icon.BorderSizePixel = 0
	G.icon.Size = UDim2.new(0,68,1,0)
	G.icon.Name = "icon"
	G.icon.Parent = G.playerinfo

	G.frame13.BackgroundColor3 = Color3.fromRGB(38,38,38)
	G.frame13.BorderSizePixel = 0
	G.frame13.Position = UDim2.new(0,1,0,1)
	G.frame13.Size = UDim2.new(1,-2,1,-2)
	G.frame13.Parent = G.icon

	G.frame14.BackgroundColor3 = Color3.fromRGB(38,38,38)
	G.frame14.BorderSizePixel = 0
	G.frame14.Position = UDim2.new(0,1,0,1)
	G.frame14.Size = UDim2.new(1,-2,1,-2)
	G.frame14.Parent = G.frame13

	G.gradient3.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(30,30,30)), ColorSequenceKeypoint.new(1, Color3.fromRGB(10,10,10))}
	G.gradient3.Rotation = 90
	G.gradient3.Parent = G.frame14

	G.image.BackgroundTransparency = 1
	G.image.BorderSizePixel = 0
	G.image.Size = UDim2.new(1,0,1,0)
	G.image.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420", lplr.UserId)
	G.image.Parent = G.frame14

	G.health.AnchorPoint = Vector2.new(0,1)
	G.health.BackgroundColor3 = Color3.fromRGB(10,10,10)
	G.health.BorderSizePixel = 0
	G.health.Position = UDim2.new(0,72,1,0)
	G.health.Size = UDim2.new(1,-72,0,14)
	G.health.Name = "health"
	G.health.Parent = G.playerinfo

	G.frame15.BackgroundColor3 = Color3.fromRGB(38,38,38)
	G.frame15.BorderSizePixel = 0
	G.frame15.Position = UDim2.new(0,1,0,1)
	G.frame15.Size = UDim2.new(1,-2,1,-2)
	G.frame15.Parent = G.health

	G.frame16.BackgroundColor3 = Color3.fromRGB(38,38,38)
	G.frame16.BorderSizePixel = 0
	G.frame16.Position = UDim2.new(0,1,0,1)
	G.frame16.Size = UDim2.new(1,-2,1,-2)
	G.frame16.Parent = G.frame15

	G.gradient4.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(20,20,20)), ColorSequenceKeypoint.new(1, Color3.fromRGB(10,10,10))}
	G.gradient4.Rotation = 90
	G.gradient4.Parent = G.frame16

	G.healthbar.BackgroundColor3 = Color3.fromRGB(0,180,0)
	G.healthbar.BorderSizePixel = 0
	G.healthbar.Size = UDim2.new(1,0,1,0)
	G.healthbar.Name = "healthbarvalue"
	G.healthbar.Parent = G.frame16

	G.gradient5.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190,190,190)), ColorSequenceKeypoint.new(1, Color3.fromRGB(125,125,125))}
	G.gradient5.Rotation = 90
	G.gradient5.Parent = G.healthbar

	G.healthvalue.Text = "100%"
	G.healthvalue.TextColor3 = Color3.fromRGB(255,255,255)
	G.healthvalue.TextSize = 13
	G.healthvalue.FontFace = th_font_bold
	G.healthvalue.AnchorPoint = Vector2.new(0.5,0.5)
	G.healthvalue.BackgroundTransparency = 1
	G.healthvalue.BorderSizePixel = 0
	G.healthvalue.Position = UDim2.new(0.5,0,0.5,0)
	G.healthvalue.Size = UDim2.new(1,0,1,0)
	G.healthvalue.Name = "healthvalue"
	G.healthvalue.Parent = G.frame16

	G.stroke.LineJoinMode = Enum.LineJoinMode.Miter
	G.stroke.Parent = G.healthvalue

	G.frame17.BackgroundTransparency = 1
	G.frame17.BorderSizePixel = 0
	G.frame17.Position = UDim2.new(0.270072997,0,0.0294117648,0)
	G.frame17.Size = UDim2.new(0,198,0,31)
	G.frame17.Parent = G.playerinfo

	G.layout1.Padding = UDim.new(0,2)
	G.layout1.SortOrder = Enum.SortOrder.LayoutOrder
	G.layout1.Parent = G.frame17

	G.name.Text = lplr.DisplayName or lplr.Name
	G.name.TextColor3 = Color3.fromRGB(255,255,255)
	G.name.TextSize = 13
	G.name.FontFace = th_font_bold
	G.name.TextXAlignment = Enum.TextXAlignment.Left
	G.name.TextYAlignment = Enum.TextYAlignment.Top
	G.name.BackgroundTransparency = 1
	G.name.BorderSizePixel = 0
	G.name.Size = UDim2.new(0.391515255,0,0.419354796,0)
	G.name.Name = "name"
	G.name.Parent = G.frame17

	G.stroke1.LineJoinMode = Enum.LineJoinMode.Miter
	G.stroke1.Parent = G.name

	G.studs.Text = "local player"
	G.studs.TextColor3 = Color3.fromRGB(180,180,180)
	G.studs.TextSize = 12
	G.studs.FontFace = th_font
	G.studs.TextXAlignment = Enum.TextXAlignment.Left
	G.studs.TextYAlignment = Enum.TextYAlignment.Top
	G.studs.BackgroundTransparency = 1
	G.studs.BorderSizePixel = 0
	G.studs.Size = UDim2.new(0.391515255,0,0.419354796,0)
	G.studs.Name = "studs"
	G.studs.Parent = G.frame17

	G.stroke2.LineJoinMode = Enum.LineJoinMode.Miter
	G.stroke2.Parent = G.studs

	G.armor.AnchorPoint = Vector2.new(0,1)
	G.armor.BackgroundColor3 = Color3.fromRGB(10,10,10)
	G.armor.BorderSizePixel = 0
	G.armor.Position = UDim2.new(0,72,0.79411763,0)
	G.armor.Size = UDim2.new(1,-72,0,14)
	G.armor.Name = "armor"
	G.armor.Parent = G.playerinfo

	G.frame18.BackgroundColor3 = Color3.fromRGB(38,38,38)
	G.frame18.BorderSizePixel = 0
	G.frame18.Position = UDim2.new(0,1,0,1)
	G.frame18.Size = UDim2.new(1,-2,1,-2)
	G.frame18.Parent = G.armor

	G.frame19.BackgroundColor3 = Color3.fromRGB(38,38,38)
	G.frame19.BorderSizePixel = 0
	G.frame19.Position = UDim2.new(0,1,0,1)
	G.frame19.Size = UDim2.new(1,-2,1,-2)
	G.frame19.Parent = G.frame18

	G.gradient6.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(20,20,20)), ColorSequenceKeypoint.new(1, Color3.fromRGB(10,10,10))}
	G.gradient6.Rotation = 90
	G.gradient6.Parent = G.frame19

	G.armorbar.BackgroundColor3 = Color3.fromRGB(0,120,255)
	G.armorbar.BorderSizePixel = 0
	G.armorbar.Size = UDim2.new(0,0,1,0)
	G.armorbar.Name = "armorbarvalue"
	G.armorbar.Parent = G.frame19

	G.gradient7.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190,190,190)), ColorSequenceKeypoint.new(1, Color3.fromRGB(125,125,125))}
	G.gradient7.Rotation = 90
	G.gradient7.Parent = G.armorbar

	G.armorvalue.Text = "0%"
	G.armorvalue.TextColor3 = Color3.fromRGB(255,255,255)
	G.armorvalue.TextSize = 13
	G.armorvalue.FontFace = th_font_bold
	G.armorvalue.AnchorPoint = Vector2.new(0.5,0.5)
	G.armorvalue.BackgroundTransparency = 1
	G.armorvalue.BorderSizePixel = 0
	G.armorvalue.Position = UDim2.new(0.5,0,0.5,0)
	G.armorvalue.Size = UDim2.new(1,0,1,0)
	G.armorvalue.Name = "armorvalue"
	G.armorvalue.Parent = G.frame19

	G.stroke3.LineJoinMode = Enum.LineJoinMode.Miter
	G.stroke3.Parent = G.armorvalue

	G.top.BackgroundTransparency = 1
	G.top.BorderSizePixel = 0
	G.top.Position = UDim2.new(0,10,0,-22)
	G.top.Size = UDim2.new(1,0,0,20)
	G.top.Name = "top"
	G.top.Visible = true
	G.top.Parent = G.frame12

	G.title.Text = '<font color="rgb(255,255,255)">mango</font><font color="rgb(118,200,64)">sense</font>'
	G.title.RichText = true
	G.title.TextColor3 = Color3.fromRGB(255,255,255)
	G.title.TextSize = 14
	G.title.FontFace = th_font_bold
	G.title.TextXAlignment = Enum.TextXAlignment.Left
	G.title.BackgroundTransparency = 1
	G.title.BorderSizePixel = 0
	G.title.Size = UDim2.new(1,0,1,0)
	G.title.Parent = G.top

	G.padding5.PaddingLeft = UDim.new(0,5)
	G.padding5.Parent = G.title

	G.stroke4.LineJoinMode = Enum.LineJoinMode.Miter
	G.stroke4.Parent = G.title

	G.top1.BackgroundTransparency = 1
	G.top1.BorderSizePixel = 0
	G.top1.Size = UDim2.new(1,-4,0,20)
	G.top1.Name = "top"
	G.top1.Parent = G.frame3

	G.subtitle.Text = ""
	G.subtitle.TextColor3 = Color3.fromRGB(180,180,180)
	G.subtitle.TextSize = 12
	G.subtitle.FontFace = th_font
	G.subtitle.TextXAlignment = Enum.TextXAlignment.Left
	G.subtitle.BackgroundTransparency = 1
	G.subtitle.BorderSizePixel = 0
	G.subtitle.Size = UDim2.new(0.5,0,1,0)
	G.subtitle.Parent = G.top1

	G.padding6.PaddingBottom = UDim.new(0,4)
	G.padding6.PaddingLeft = UDim.new(0,-2)
	G.padding6.PaddingTop = UDim.new(0,-4)
	G.padding6.Parent = G.subtitle

	G.stroke5.LineJoinMode = Enum.LineJoinMode.Miter
	G.stroke5.Parent = G.subtitle

	G.glow.Name = "glow"
	G.glow.BackgroundTransparency = 1
	G.glow.ImageTransparency = 0.4
	G.glow.ImageColor3 = Color3.fromRGB(23,23,23)
	G.glow.ScaleType = Enum.ScaleType.Slice
	G.glow.SliceCenter = Rect.new(21,21,79,79)
	G.glow.Image = "http://www.roblox.com/asset/?id=18245826428"
	G.glow.Size = UDim2.new(1,20,1,20)
	G.glow.Position = UDim2.new(0,-10,0,-10)
	G.glow.ZIndex = 0
	G.glow.BorderSizePixel = 0
	G.glow.Parent = G.frame

	local accentLine = Instance.new("ImageLabel")
	accentLine.BackgroundTransparency = 1
	accentLine.BorderSizePixel = 0
	accentLine.Position = UDim2.new(0,1,0,1)
	accentLine.Size = UDim2.new(1,-2,0,2)
	accentLine.ZIndex = 10
	accentLine.Image = "rbxassetid://15453122383"
	accentLine.Parent = G.frame2

	local function th_getArmorValue(character)
		local bf = character:FindFirstChild("BodyEffects")
		if bf then
			local v = bf:FindFirstChild("Armor")
			if v then return v end
		end
		for _, obj in character:GetDescendants() do
			if obj.ClassName == "NumberValue" or obj.ClassName == "IntValue" then
				local n = string.lower(obj.Name)
				if n == "armor" or n == "shield" or n == "armour" then return obj end
			end
		end
		return nil
	end

	local function th_updateHud()
		local character = lplr.Character
		if not character then
			G.gui.Enabled = false
			return
		end
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then
			G.gui.Enabled = false
			return
		end
		G.gui.Enabled = true

		local maxHp = math.max(humanoid.MaxHealth,1)
		local hpRatio = math.clamp(humanoid.Health / maxHp, 0, 1)
		G.healthvalue.Text = math.floor(hpRatio * 100) .. "%"
		tws:Create(G.healthbar, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = UDim2.new(hpRatio,0,1,0)}):Play()

		local armorV = th_getArmorValue(character)
		local armorRatio = armorV and math.clamp(armorV.Value / 130, 0, 1) or 0
		G.armorvalue.Text = math.floor(armorRatio * 100) .. "%"
		tws:Create(G.armorbar, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = UDim2.new(armorRatio,0,1,0)}):Play()

		if lplr.Name ~= lplr.DisplayName then
			local full = lplr.DisplayName .. " (@" .. lplr.Name .. ")"
			G.name.Text = #full > 28 and string.sub(full,1,26) .. ".." or full
		else
			G.name.Text = #lplr.Name > 28 and string.sub(lplr.Name,1,26) .. ".." or lplr.Name
		end

		G.studs.Text = "local player"
	end

	th_connect(rs.Heartbeat, th_updateHud)

	local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

	th_connect(G.frame.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = G.frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	th_connect(G.frame.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	th_connect(rs.Heartbeat, function()
		if dragging and dragInput and startPos then
			local delta = dragInput.Position - dragStart
			G.frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	local _prev_unload = getgenv().unload_mangosense
	getgenv().unload_mangosense = function(...)
		for _, c in pairs(TH_connections) do
			pcall(function() c:Disconnect() end)
		end
		if G.gui and G.gui.Parent then
			G.gui:Destroy()
		end
		if _prev_unload then _prev_unload(...) end
	end
end

do
	local _notif_font = getgenv().mangosense_font or Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	local _notif_font_bold = getgenv().mangosense_font_bold or Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

	local NOTIF_Gui = Instance.new("ScreenGui")
	NOTIF_Gui.Name = "mangosense_welcome"
	NOTIF_Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	NOTIF_Gui.ResetOnSpawn = false
	NOTIF_Gui.Enabled = true
	NOTIF_Gui.Parent = cg

	local NOTIF_Frame = newObject("Frame", {AnchorPoint = vector2new(0.5,0), BackgroundColor3 = colorfromrgb(60,60,60), BorderColor3 = colorfromrgb(12,12,12), BorderSizePixel = 1, Position = udim2new(0.5,0,0.5,284), Size = udim2new(0,320,0,28), ZIndex = 60, BackgroundTransparency = 1, Parent = NOTIF_Gui})

	local NOTIF_Glow = newObject("ImageLabel", {BackgroundTransparency = 1, ImageTransparency = 1, ImageColor3 = colorfromrgb(0,0,0), ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(21,21,79,79), Image = "http://www.roblox.com/asset/?id=18245826428", Size = udim2new(1,20,1,20), Position = udim2new(0,-10,0,-10), ZIndex = 59, BorderSizePixel = 0, Parent = NOTIF_Frame})

	local NOTIF_Border2 = newObject("Frame", {BackgroundColor3 = colorfromrgb(40,40,40), BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(0,2,0,2), Size = udim2new(1,-4,1,-4), ZIndex = 61, Parent = NOTIF_Frame})

	local NOTIF_Inner = newObject("ImageLabel", {BackgroundColor3 = colorfromrgb(255,255,255), BorderSizePixel = 0, Position = udim2new(0,3,0,3), Size = udim2new(1,-6,1,-6), Image = "rbxassetid://15453092054", ScaleType = Enum.ScaleType.Tile, TileSize = udim2new(0,4,0,400), ClipsDescendants = true, BackgroundTransparency = 1, ImageTransparency = 1, ZIndex = 62, Parent = NOTIF_Frame})

	local NOTIF_TopBar = newObject("ImageLabel", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(0,1,0,1), Size = udim2new(1,-2,0,2), ZIndex = 63, Image = "rbxassetid://15453122383", ImageTransparency = 1, Parent = NOTIF_Inner})

	local NOTIF_Label = newObject("TextLabel", {AnchorPoint = vector2new(0.5,0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Position = udim2new(0.5,0,0.5,1), Size = udim2new(1,-16,1,0), ZIndex = 64, FontFace = _notif_font_bold, RichText = true, Text = 'Welcome to <font color="rgb(118,200,64)">mangosense</font>', TextColor3 = colorfromrgb(198,198,198), TextSize = 13, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, Parent = NOTIF_Inner})

	local _ni = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local _no = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

	local function notif_show()
		NOTIF_Frame.Visible = true
		tws:Create(NOTIF_Frame, _ni, {BackgroundTransparency = 0}):Play()
		tws:Create(NOTIF_Border2, _ni, {BackgroundTransparency = 0}):Play()
		tws:Create(NOTIF_Inner, _ni, {BackgroundTransparency = 0, ImageTransparency = 0}):Play()
		tws:Create(NOTIF_TopBar, _ni, {ImageTransparency = 0}):Play()
		tws:Create(NOTIF_Glow, _ni, {ImageTransparency = 0.45}):Play()
		tws:Create(NOTIF_Label, _ni, {TextTransparency = 0}):Play()
	end

	local function notif_hide()
		tws:Create(NOTIF_Frame, _no, {BackgroundTransparency = 1}):Play()
		tws:Create(NOTIF_Border2, _no, {BackgroundTransparency = 1}):Play()
		tws:Create(NOTIF_Inner, _no, {BackgroundTransparency = 1, ImageTransparency = 1}):Play()
		tws:Create(NOTIF_TopBar, _no, {ImageTransparency = 1}):Play()
		tws:Create(NOTIF_Glow, _no, {ImageTransparency = 1}):Play()
		tws:Create(NOTIF_Label, _no, {TextTransparency = 1}):Play()
		task.delay(0.3, function()
			pcall(function() NOTIF_Gui:Destroy() end)
		end)
	end

	task.delay(0.5, function()
		notif_show()
		task.delay(3.5, notif_hide)
	end)

	local _prev_notif_unload = getgenv().unload_mangosense
	getgenv().unload_mangosense = function(...)
		pcall(function() NOTIF_Gui:Destroy() end)
		if _prev_notif_unload then _prev_notif_unload(...) end
	end
end
