--[[
   ROBOX Render Killer  v1.0  —  built for Xeno | https://www.xeno.now/
   Disables rendering of objects that games spam (lag tests, record farms).
   Same luxuryfarm UI language as ROBOX HUB: 44px icon rail + 180px list + card.
   Toggle key: RightCtrl   |   Search on top   |   Click row = select, chip = bind
]]

--================ Services ================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

--================ State ================
local State = {
	Hidden = {},        -- [groupName] = true  (objects hidden by name)
	GroupsHidden = {},  -- [className] = true  (whole class hidden)
	MaxDist = 500,
	AutoHideNew = false,
}

local CONFIG_FILE = "RoboxRenderKiller.json"

--================ Config ================
local function saveConfig()
	if not writefile then return end
	local ok, json = pcall(function()
		return HttpService:JSONEncode({
			maxDist = State.MaxDist,
			autoHideNew = State.AutoHideNew,
			groups = State.GroupsHidden,
			hidden = State.Hidden,
		})
	end)
	if ok and json then pcall(writefile, CONFIG_FILE, json) end
end

local function loadConfig()
	if not readfile then return end
	local ok, content = pcall(readfile, CONFIG_FILE)
	if not ok or not content then return end
	local ok2, cfg = pcall(function() return HttpService:JSONDecode(content) end)
	if not ok2 or type(cfg) ~= "table" then return end
	if type(cfg.maxDist) == "number" then State.MaxDist = cfg.maxDist end
	if type(cfg.autoHideNew) == "boolean" then State.AutoHideNew = cfg.autoHideNew end
	if type(cfg.groups) == "table" then State.GroupsHidden = cfg.groups end
	if type(cfg.hidden) == "table" then State.Hidden = cfg.hidden end
end

loadConfig()

--================ Keybind system ================
local bindKeys = {}
local bindConns = {}
local bindActions = {}
local unboundIds = {}

local function keyCodeName(kc)
	if not kc then return "" end
	local ok, name = pcall(function() return kc.Name end)
	if ok and name then return name:upper() end
	return tostring(kc)
end

local function setBind(id, keyCode, action)
	if bindConns[id] then
		bindConns[id]:Disconnect()
		bindConns[id] = nil
	end
	bindActions[id] = action
	if keyCode then
		bindKeys[id] = keyCode
		unboundIds[id] = nil
		bindConns[id] = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.KeyCode == keyCode then
				if bindActions[id] then bindActions[id]() end
			end
		end)
	else
		bindKeys[id] = nil
		unboundIds[id] = true
	end
end

--================ Gui parent (Xeno-safe, from ROBOX HUB) ================
local function getGuiParent()
	local candidates = {}
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and typeof(hui) == "Instance" then table.insert(candidates, hui) end
	end
	local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and cg then table.insert(candidates, cg) end
	local ok3, pg = pcall(function() return player:WaitForChild("PlayerGui") end)
	if ok3 and pg then table.insert(candidates, pg) end
	for _, dest in ipairs(candidates) do
		local okProbe = pcall(function()
			local probe = Instance.new("Folder")
			probe.Parent = dest
			probe:Destroy()
		end)
		if okProbe then return dest end
	end
	return player:WaitForChild("PlayerGui")
end

--================ Hide / Restore engine ================
-- "hide" = disable rendering on every descendant part:
-- Transparency 1, CanCollide/CanQuery/CanTouch false, Material Plastic.
-- Original properties are remembered and fully restored.
local savedProps = {}  -- [BasePart] = {transparency, canCollide, canQuery, canTouch, material, decals}

local function savePart(obj)
	if savedProps[obj] then return end
	local rec
	if obj:IsA("BasePart") then
		rec = {
			transparency = obj.Transparency,
			canCollide = obj.CanCollide,
			canQuery = obj.CanQuery,
			canTouch = obj.CanTouch,
			decals = {},
		}
		if obj:IsA("MeshPart") or obj:IsA("Part") then
			rec.material = obj.Material
		end
		for _, d in ipairs(obj:GetChildren()) do
			if d:IsA("Decal") or d:IsA("Texture") then
				rec.decals[d] = d.Transparency
			end
		end
	elseif obj:IsA("Decal") or obj:IsA("Texture") then
		rec = { transparency = obj.Transparency }
	end
	if rec then savedProps[obj] = rec end
end

local function applyHidden(obj)
	pcall(function()
		if obj:IsA("BasePart") then
			obj.Transparency = 1
			obj.CanCollide = false
			obj.CanQuery = false
			obj.CanTouch = false
			if obj:IsA("MeshPart") or obj:IsA("Part") then
				obj.Material = Enum.Material.Plastic
			end
			for _, d in ipairs(obj:GetChildren()) do
				if d:IsA("Decal") or d:IsA("Texture") then
					d.Transparency = 1
				end
			end
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			obj.Transparency = 1
		end
	end)
end

local function restorePart(obj)
	local rec = savedProps[obj]
	if not rec then return end
	pcall(function()
		if obj:IsA("BasePart") then
			obj.Transparency = rec.transparency
			obj.CanCollide = rec.canCollide
			obj.CanQuery = rec.canQuery
			obj.CanTouch = rec.canTouch
			if rec.material and (obj:IsA("MeshPart") or obj:IsA("Part")) then
				obj.Material = rec.material
			end
			for d, t in pairs(rec.decals or {}) do
				if d and d.Parent then d.Transparency = t end
			end
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			obj.Transparency = rec.transparency
		end
	end)
	savedProps[obj] = nil
end

-- object-level ----------------------------------------------------------
local function hideObject(obj)
	if not obj or not obj.Parent then return end
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
			savePart(d)
			applyHidden(d)
		end
	end
	if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
		savePart(obj)
		applyHidden(obj)
	end
end

local function restoreObject(obj)
	if not obj then return end
	for _, d in ipairs(obj:GetDescendants()) do
		restorePart(d)
	end
	restorePart(obj)
end

-- groups by NAME: lag tests clone one template many times with same name
local function findGroup(name)
	local out = {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d.Name == name then table.insert(out, d) end
	end
	return out
end

local function hideGroup(name)
	for _, obj in ipairs(findGroup(name)) do
		hideObject(obj)
	end
end

local function restoreGroup(name)
	for _, obj in ipairs(findGroup(name)) do
		restoreObject(obj)
	end
end

-- class-level kill switch ------------------------------------------------
local function applyClassState(className, hidden)
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d.ClassName == className then
			if hidden then
				savePart(d)
				applyHidden(d)
			else
				restorePart(d)
			end
		end
	end
end

--================ Workspace scan (groups by name) ================
local function scanGroups()
	-- collect renderable top-ish objects: direct children of Workspace or
	-- children of container models, grouped by name with counts
	local groups = {}
	local root = Workspace

	local function addObj(obj, container)
		local name = obj.Name
		if name == "" then return end
		if not (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Folder")) then
			-- still count things like ParticleEmitter parents are parts, skip pure services
			return
		end
		local key = name
		local g = groups[key]
		if not g then
			g = { name = name, className = obj.ClassName, objects = {}, container = container }
			groups[key] = g
		end
		table.insert(g.objects, obj)
	end

	for _, obj in ipairs(root:GetChildren()) do
		if obj ~= player.Character then
			addObj(obj, nil)
			-- one level deep: spam often lives inside a container model/folder
			if #obj:GetChildren() > 0 and (obj:IsA("Model") or obj:IsA("Folder")) then
				for _, child in ipairs(obj:GetChildren()) do
					addObj(child, obj)
				end
			end
		end
	end
	-- array form sorted by count desc
	local arr = {}
	for _, g in pairs(groups) do table.insert(arr, g) end
	table.sort(arr, function(a, b) return #a.objects > #b.objects end)
	return arr
end

--================ Position helpers (shared by auto-hide + cards) ================
local function getObjPart(obj)
	if not obj then return nil end
	if obj:IsA("BasePart") then return obj end
	if obj:IsA("Model") then
		return obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function getObjPosition(obj)
	local pp = getObjPart(obj)
	if pp then return pp.Position end
	return nil
end

--================ Top groups by ClassName (for class switch) ================
local function scanClasses()
	local counts = {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		counts[d.ClassName] = (counts[d.ClassName] or 0) + 1
	end
	local arr = {}
	for cn, n in pairs(counts) do
		table.insert(arr, { className = cn, count = n })
	end
	table.sort(arr, function(a, b) return a.count > b.count end)
	return arr
end

--================ Auto-hide far objects (optional) ================
local autoHideRunning = false
local function startAutoHide()
	if autoHideRunning then return end
	autoHideRunning = true
	task.spawn(function()
		while autoHideRunning do
			task.wait(3)
			if State.AutoHideNew and not State.HiddenOff then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					for _, g in ipairs(scanGroups()) do
						if #g.objects >= 3 and not State.GroupsHidden[g.name] and not State.Hidden[g.name] then
							-- nearest distance of the group
							local minDist = math.huge
							for _, obj in ipairs(g.objects) do
								local pp = getObjPart(obj)
								if pp then
									local dd = (pp.Position - root.Position).Magnitude
									if dd < minDist then minDist = dd end
								end
							end
							if minDist > State.MaxDist then
								hideGroup(g.name)
								State.Hidden[g.name] = true
							end
						end
					end
				end
			end
		end
	end)
end

startAutoHide()

-- watch for re-enabled/new spam: keep hidden things hidden ----------------
task.spawn(function()
	while true do
		task.wait(1)
		-- re-apply group hides (games often reset transparency)
		for name in pairs(State.Hidden) do
			pcall(hideGroup, name)
		end
		for cn in pairs(State.GroupsHidden) do
			pcall(applyClassState, cn, true)
		end
	end
end)

--================ UI ================
-- luxuryfarm palette
local C = {
	Rail     = Color3.fromRGB(22, 22, 22),
	Side     = Color3.fromRGB(26, 26, 26),
	Top      = Color3.fromRGB(18, 18, 18),
	Card     = Color3.fromRGB(28, 28, 28),
	Row      = Color3.fromRGB(36, 36, 36),
	RowHover = Color3.fromRGB(46, 46, 46),
	Input    = Color3.fromRGB(32, 32, 32),
	Accent   = Color3.fromRGB(224, 71, 71),
	Text     = Color3.fromRGB(230, 230, 230),
	Sub      = Color3.fromRGB(138, 138, 138),
	Dim      = Color3.fromRGB(90, 90, 90),
	Off      = Color3.fromRGB(58, 58, 58),
	Line     = Color3.fromRGB(42, 42, 42),
	Knob     = Color3.fromRGB(255, 255, 255),
}

local PAD = 8
local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = parent
	return c
end
local function tween(obj, t, props)
	TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

local gui = Instance.new("ScreenGui")
gui.Name = "RoboxRenderKiller"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = getGuiParent()

-- window 760x452, scale 1.35 like ROBOX HUB
local WIN_W, WIN_H = 760, 452
local RAIL_W, SIDE_W, TOP_H = 44, 180, 40
local UI_SCALE = 1.35

local uiScale = Instance.new("UIScale")
uiScale.Scale = UI_SCALE
uiScale.Parent = gui

local win = Instance.new("Frame")
win.Size = UDim2.new(0, WIN_W, 0, WIN_H)
win.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
win.BackgroundColor3 = C.Top
win.BorderSizePixel = 0
win.Active = true
win.Parent = gui
corner(win, 8)

-- rail
local rail = Instance.new("Frame")
rail.Size = UDim2.new(0, RAIL_W, 1, 0)
rail.BackgroundColor3 = C.Rail
rail.BorderSizePixel = 0
rail.Parent = win
corner(rail, 8)
local railCover = Instance.new("Frame")
railCover.Size = UDim2.new(0, 8, 1, 0)
railCover.Position = UDim2.new(0, RAIL_W - 8, 0, 0)
railCover.BackgroundColor3 = C.Rail
railCover.BorderSizePixel = 0
railCover.Parent = rail

-- side column
local side = Instance.new("Frame")
side.Size = UDim2.new(0, SIDE_W, 1, 0)
side.Position = UDim2.new(0, RAIL_W, 0, 0)
side.BackgroundColor3 = C.Side
side.BorderSizePixel = 0
side.Parent = win

-- dividers
local hDiv = Instance.new("Frame")
hDiv.Size = UDim2.new(0, WIN_W - RAIL_W, 0, 1)
hDiv.Position = UDim2.new(0, RAIL_W, 0, 39)
hDiv.BackgroundColor3 = C.Line
hDiv.BorderSizePixel = 0
hDiv.Parent = win
local vDiv = Instance.new("Frame")
vDiv.Size = UDim2.new(0, 1, 1, -TOP_H)
vDiv.Position = UDim2.new(0, RAIL_W + SIDE_W - 1, 0, TOP_H)
vDiv.BackgroundColor3 = C.Line
vDiv.BorderSizePixel = 0
vDiv.Parent = win

-- top: red tick + title + search
local titleTick = Instance.new("Frame")
titleTick.Size = UDim2.new(0, 3, 0, 16)
titleTick.Position = UDim2.new(0, 52, 0, 12)
titleTick.BackgroundColor3 = C.Accent
titleTick.BorderSizePixel = 0
titleTick.Parent = win
corner(titleTick, 2)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(0, 300, 0, 24)
titleLbl.Position = UDim2.new(0, 58, 0, 8)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "Render Killer"
titleLbl.TextColor3 = C.Accent
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 18
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = win

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(0, 200, 0, 24)
searchBox.Position = UDim2.new(0, 548, 0, 8)
searchBox.BackgroundColor3 = C.Input
searchBox.Text = ""
searchBox.PlaceholderText = "Поиск..."
searchBox.PlaceholderColor3 = C.Sub
searchBox.TextColor3 = C.Text
searchBox.Font = Enum.Font.GothamMedium
searchBox.TextSize = 11
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.BorderSizePixel = 0
searchBox.Parent = win
corner(searchBox, 5)
local searchPad = Instance.new("UIPadding")
searchPad.PaddingLeft = UDim.new(0, 8)
searchPad.Parent = searchBox

-- settings card
local card = Instance.new("Frame")
card.Size = UDim2.new(0, 520, 0, 396)
card.Position = UDim2.new(0, 232, 0, 48)
card.BackgroundColor3 = C.Card
card.BorderSizePixel = 0
card.Parent = win
corner(card, 6)

local cardTitle = Instance.new("TextLabel")
cardTitle.Size = UDim2.new(0, 400, 0, 36)
cardTitle.Position = UDim2.new(0, 16, 0, 0)
cardTitle.BackgroundTransparency = 1
cardTitle.Text = ""
cardTitle.TextColor3 = C.Text
cardTitle.Font = Enum.Font.GothamMedium
cardTitle.TextSize = 15
cardTitle.TextXAlignment = Enum.TextXAlignment.Left
cardTitle.Parent = card

local cardDiv = Instance.new("Frame")
cardDiv.Size = UDim2.new(0, 500, 0, 1)
cardDiv.Position = UDim2.new(0, 10, 0, 35)
cardDiv.BackgroundColor3 = C.Line
cardDiv.BorderSizePixel = 0
cardDiv.Parent = card

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(0, 506, 0, 348)
contentScroll.Position = UDim2.new(0, 8, 0, 40)
contentScroll.BackgroundTransparency = 1
contentScroll.BorderSizePixel = 0
contentScroll.ScrollBarThickness = 2
contentScroll.ScrollBarImageColor3 = C.Accent
contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentScroll.ScrollingDirection = Enum.ScrollingDirection.Y
contentScroll.Parent = card

local cardHolder = Instance.new("Frame")
cardHolder.Size = UDim2.new(1, 0, 0, 0)
cardHolder.AutomaticSize = Enum.AutomaticSize.Y
cardHolder.BackgroundTransparency = 1
cardHolder.Parent = contentScroll
local cardLayout = Instance.new("UIListLayout")
cardLayout.Padding = UDim.new(0, 6)
cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardLayout.Parent = cardHolder
local cardPad = Instance.new("UIPadding")
cardPad.PaddingTop = UDim.new(0, 6)
cardPad.Parent = cardHolder

-- rows scroll
local rowsScroll = Instance.new("ScrollingFrame")
rowsScroll.Size = UDim2.new(1, 0, 1, -TOP_H)
rowsScroll.Position = UDim2.new(0, 0, 0, TOP_H + 4)
rowsScroll.BackgroundTransparency = 1
rowsScroll.BorderSizePixel = 0
rowsScroll.ScrollBarThickness = 0
rowsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
rowsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
rowsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
rowsScroll.Parent = side
local rowsLayout = Instance.new("UIListLayout")
rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowsLayout.Parent = rowsScroll

--================ Widgets ================
local function makeSwitch(parent)
	local sw = Instance.new("TextButton")
	sw.Size = UDim2.new(0, 28, 0, 14)
	sw.BackgroundColor3 = C.Off
	sw.AutoButtonColor = false
	sw.Text = ""
	sw.BorderSizePixel = 0
	sw.Parent = parent
	corner(sw, 7)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 10, 0, 10)
	knob.Position = UDim2.new(0, 2, 0.5, -5)
	knob.BackgroundColor3 = C.Knob
	knob.BorderSizePixel = 0
	knob.Parent = sw
	corner(knob, 5)
	local function set(on)
		tween(sw, 0.15, {BackgroundColor3 = on and C.Accent or C.Off})
		tween(knob, 0.15, {Position = on and UDim2.new(1, -12, 0.5, -5) or UDim2.new(0, 2, 0.5, -5)})
	end
	return sw, set
end

local function rowFrame(parent, h)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, h)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- switch row with optional middle-click bind
local function toggleWidget(parent, name, get, set, bindId)
	local holder = rowFrame(parent, 32)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -80, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = C.Sub
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = holder

	local sw, setSw = makeSwitch(holder)
	sw.Position = UDim2.new(1, -40, 0.5, -7)

	local function render()
		local on = get() == true
		setSw(on)
		label.TextColor3 = on and C.Text or C.Sub
	end
	sw.MouseButton1Click:Connect(function()
		set(not (get() == true))
		render()
	end)
	if bindId then
		local keyLbl = Instance.new("TextLabel")
		keyLbl.Size = UDim2.new(0, 30, 0, 14)
		keyLbl.Position = UDim2.new(1, -76, 0.5, -7)
		keyLbl.BackgroundTransparency = 1
		keyLbl.Font = Enum.Font.GothamBold
		keyLbl.TextSize = 9
		keyLbl.TextColor3 = C.Dim
		keyLbl.TextXAlignment = Enum.TextXAlignment.Right
		keyLbl.Parent = holder
		-- middle-click = listen for key
		holder.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton3 then
				keyLbl.Text = "..."
				keyLbl.TextColor3 = C.Accent
				local conn
				conn = UserInputService.InputBegan:Connect(function(inp2)
					if inp2.UserInputType ~= Enum.UserInputType.Keyboard then return end
					local kc = inp2.KeyCode
					if kc == Enum.KeyCode.Escape then
						-- cancel
					elseif kc == Enum.KeyCode.Delete or kc == Enum.KeyCode.Backspace then
						setBind(bindId, nil, function() set(not (get() == true)) render() end)
					else
						setBind(bindId, kc, function() set(not (get() == true)) render() end)
					end
					conn:Disconnect()
					keyLbl.Text = bindKeys[bindId] and keyCodeName(bindKeys[bindId]) or ""
					keyLbl.TextColor3 = C.Dim
				end)
				task.delay(5, function()
					if conn.Connected then conn:Disconnect() end
					keyLbl.Text = bindKeys[bindId] and keyCodeName(bindKeys[bindId]) or ""
					keyLbl.TextColor3 = C.Dim
				end)
			end
		end)
	end
	render()
	return holder
end

local function buttonWidget(parent, name, cb, danger)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, 32)
	btn.Position = UDim2.new(0, 8, 0, 0)
	btn.BackgroundColor3 = danger and Color3.fromRGB(42, 28, 28) or C.Row
	btn.Text = name
	btn.TextColor3 = danger and C.Accent or C.Text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Parent = parent
	corner(btn, 6)
	btn.MouseButton1Click:Connect(function() if cb then cb() end end)
	return btn
end

local function sliderWidget(parent, name, min, max, get, set)
	local holder = rowFrame(parent, 44)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -96, 0, 16)
	label.Position = UDim2.new(0, 8, 0, 4)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = C.Sub
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = holder

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0, 88, 0, 16)
	valueLabel.Position = UDim2.new(1, -96, 0, 4)
	valueLabel.BackgroundTransparency = 1
	valueLabel.TextColor3 = C.Text
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 13
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Parent = holder

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -16, 0, 4)
	track.Position = UDim2.new(0, 8, 0, 28)
	track.BackgroundColor3 = C.Off
	track.BorderSizePixel = 0
	track.Parent = holder
	corner(track, 2)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = C.Accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 2)

	local function display(v) return tostring(math.floor(v)) end
	local function apply(rel, fire)
		rel = math.clamp(rel, 0, 1)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		local v = min + (max - min) * rel
		valueLabel.Text = display(v)
		if fire then set(v) end
	end
	local active = nil
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			active = function(pos)
				local rel = (pos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
				apply(rel, true)
			end
			active(input.Position)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			active = nil
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if active and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			active(input.Position)
		end
	end)
	apply((get() - min) / (max - min), false)
	return holder
end

local function infoWidget(parent, getText)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -16, 0, 0)
	lbl.Position = UDim2.new(0, 8, 0, 0)
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = C.Sub
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.TextWrapped = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	lbl.Text = getText()
	lbl.Parent = parent
	return lbl
end

--================ Category tabs (Objects / Classes / Settings) ================
local currentTab = nil
local selectedRow = nil
local refreshUI

local railIcons = {}
local function addTab(name, glyph, onSelect)
	local y = 54 + (#railIcons) * 40
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 2, 0, 36)
	bar.Position = UDim2.new(0, 0, 0, y - 2)
	bar.BackgroundColor3 = C.Accent
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = rail

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 32, 0, 32)
	btn.Position = UDim2.new(0, 6, 0, y)
	btn.BackgroundTransparency = 1
	btn.BackgroundColor3 = C.Row
	btn.Text = glyph
	btn.TextColor3 = C.Sub
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Parent = rail
	corner(btn, 6)

	local tab = { name = name, bar = bar, btn = btn, onSelect = onSelect }
	table.insert(railIcons, tab)
	btn.MouseButton1Click:Connect(function()
		refreshUI(tab)
	end)
	return tab
end

local function selectTab(tab)
	currentTab = tab
	for _, t in ipairs(railIcons) do
		local active = (t == tab)
		t.bar.Visible = active
		t.btn.BackgroundTransparency = active and 0 or 1
		t.btn.TextColor3 = active and C.Text or C.Sub
	end
end

-- clear helpers
local function clearRows()
	for _, ch in ipairs(rowsScroll:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
end

local function clearCard()
	for _, ch in ipairs(cardHolder:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
end

local function applySearch(rows)
	local q = searchBox.Text:lower()
	for _, r in ipairs(rows) do
		r.Visible = (q == "") or (r.data.name:lower():find(q, 1, true) ~= nil)
	end
end

--================ Tab: OBJECTS (group rows) ================
local function buildObjectsCard(g)
	clearCard()
	cardTitle.Text = g.name .. "  (" .. #g.objects .. ")"

	toggleWidget(cardHolder, "Hide All (" .. #g.objects .. ")", function()
		return State.Hidden[g.name] == true
	end, function(v)
		if v then
			hideGroup(g.name)
			State.Hidden[g.name] = true
		else
			State.Hidden[g.name] = nil
			restoreGroup(g.name)
		end
		saveConfig()
	end, "obj_" .. g.name)

	infoWidget(cardHolder, function()
		return "Class: " .. g.className .. "\nObjects: " .. #g.objects .. "\nIn containers: " .. (g.container and "yes" or "no")
	end)

	buttonWidget(cardHolder, "Restore All", function()
		State.Hidden[g.name] = nil
		restoreGroup(g.name)
		saveConfig()
		refreshUI(currentTab)
	end)

	buttonWidget(cardHolder, "Teleport to First", function()
		local obj = g.objects[1]
		if not obj then return end
		local pp = getObjPart(obj)
		local charRoot = player.Character and player.Character.PrimaryPart
		if pp and charRoot then
			charRoot.CFrame = pp.CFrame + Vector3.new(0, 5, 0)
		end
	end)

	if #g.objects <= 50 then
		infoWidget(cardHolder, function()
			local parts = {}
			local charRoot = player.Character and player.Character.PrimaryPart
			for i, obj in ipairs(g.objects) do
				if i > 20 then break end
				local d = ""
				local pos = getObjPosition(obj)
				if pos and charRoot then
					d = string.format("  (%.0f studs)", (pos - charRoot.Position).Magnitude)
				end
				table.insert(parts, i .. ". " .. obj.Name .. d)
			end
			return table.concat(parts, "\n")
		end)
	end
end

local function buildObjectsTab()
	clearRows()
	titleLbl.Text = "Render Killer / Objects"
	local groups = scanGroups()
	local rows = {}
	local maxN = math.min(#groups, 200)
	for i = 1, maxN do
		local g = groups[i]
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Parent = rowsScroll
		row.LayoutOrder = i
		row.data = { name = g.name }

		local rowBg = Instance.new("Frame")
		rowBg.Size = UDim2.new(0, 172, 0, 28)
		rowBg.Position = UDim2.new(0, 4, 0, 2)
		rowBg.BackgroundColor3 = C.Row
		rowBg.BackgroundTransparency = (selectedRow == g.name) and 0 or 1
		rowBg.BorderSizePixel = 0
		rowBg.Parent = row
		corner(rowBg, 6)

		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, 2, 0, 16)
		bar.Position = UDim2.new(0, 0, 0.5, -8)
		bar.BackgroundColor3 = C.Accent
		bar.BorderSizePixel = 0
		bar.Visible = (selectedRow == g.name)
		bar.Parent = rowBg

		local rowClick = Instance.new("TextButton")
		rowClick.Size = UDim2.new(1, -10, 1, 0)
		rowClick.Position = UDim2.new(0, 10, 0, 0)
		rowClick.BackgroundTransparency = 1
		rowClick.Text = ""
		rowClick.AutoButtonColor = false
		rowClick.Parent = rowBg

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -20, 1, 0)
		nameLbl.Position = UDim2.new(0, 4, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = g.name
		nameLbl.TextColor3 = (selectedRow == g.name) and C.Text or C.Sub
		nameLbl.Font = Enum.Font.GothamMedium
		nameLbl.TextSize = 12
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = rowClick

		local cntLbl = Instance.new("TextLabel")
		cntLbl.Size = UDim2.new(0, 36, 0, 16)
		cntLbl.Position = UDim2.new(1, -44, 0.5, -8)
		cntLbl.BackgroundTransparency = 1
		cntLbl.Text = "x" .. #g.objects
		cntLbl.TextColor3 = (State.Hidden[g.name] or State.GroupsHidden[g.name]) and C.Accent or C.Dim
		cntLbl.Font = Enum.Font.GothamBold
		cntLbl.TextSize = 9
		cntLbl.TextXAlignment = Enum.TextXAlignment.Right
		cntLbl.Parent = rowBg

		local isHidden = State.Hidden[g.name] == true
		local sw, setSw = makeSwitch(rowBg)
		sw.Position = UDim2.new(0, 118, 0.5, -7)
		setSw(isHidden)
		sw.MouseButton1Click:Connect(function()
			local v = not (State.Hidden[g.name] == true)
			if v then
				hideGroup(g.name)
				State.Hidden[g.name] = true
			else
				State.Hidden[g.name] = nil
				restoreGroup(g.name)
			end
			saveConfig()
			setSw(v)
			cntLbl.TextColor3 = v and C.Accent or C.Dim
			if selectedRow == g.name then buildObjectsCard(g) end
		end)

		rowClick.MouseButton1Click:Connect(function()
			selectedRow = g.name
			buildObjectsCard(g)
			-- refresh row visuals
			for _, r in ipairs(rows) do
				r.rowBg.BackgroundTransparency = (r.data.name == g.name) and 0 or 1
				r.bar.Visible = (r.data.name == g.name)
				r.nameLbl.TextColor3 = (r.data.name == g.name) and C.Text or C.Sub
			end
		end)

		table.insert(rows, {
			row = row, rowBg = rowBg, bar = bar, nameLbl = nameLbl, cntLbl = cntLbl,
			data = { name = g.name },
		})
	end
	applySearch(rows)
end

local function buildClassesTab()
	clearRows()
	titleLbl.Text = "Render Killer / Classes"
	local classes = scanClasses()
	local rows = {}
	for i, cl in ipairs(classes) do
		if i > 100 then break end
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Parent = rowsScroll
		row.LayoutOrder = i
		row.data = { name = cl.className }

		local rowBg = Instance.new("Frame")
		rowBg.Size = UDim2.new(0, 172, 0, 28)
		rowBg.Position = UDim2.new(0, 4, 0, 2)
		rowBg.BackgroundColor3 = C.Row
		rowBg.BackgroundTransparency = 1
		rowBg.BorderSizePixel = 0
		rowBg.Parent = row
		corner(rowBg, 6)

		local rowClick = Instance.new("TextButton")
		rowClick.Size = UDim2.new(1, -10, 1, 0)
		rowClick.Position = UDim2.new(0, 10, 0, 0)
		rowClick.BackgroundTransparency = 1
		rowClick.Text = ""
		rowClick.AutoButtonColor = false
		rowClick.Parent = rowBg

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -20, 1, 0)
		nameLbl.Position = UDim2.new(0, 4, 0, 0)
		nameLbl.Text = cl.className
		nameLbl.TextColor3 = C.Sub
		nameLbl.Font = Enum.Font.GothamMedium
		nameLbl.TextSize = 12
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = rowClick

		local cntLbl = Instance.new("TextLabel")
		cntLbl.Size = UDim2.new(0, 36, 0, 16)
		cntLbl.Position = UDim2.new(1, -44, 0.5, -8)
		cntLbl.BackgroundTransparency = 1
		cntLbl.Text = "x" .. cl.count
		cntLbl.TextColor3 = State.GroupsHidden[cl.className] and C.Accent or C.Dim
		cntLbl.Font = Enum.Font.GothamBold
		cntLbl.TextSize = 9
		cntLbl.TextXAlignment = Enum.TextXAlignment.Right
		cntLbl.Parent = rowBg

		local isHidden = State.GroupsHidden[cl.className] == true
		local sw, setSw = makeSwitch(rowBg)
		sw.Position = UDim2.new(0, 118, 0.5, -7)
		setSw(isHidden)
		sw.MouseButton1Click:Connect(function()
			local v = not (State.GroupsHidden[cl.className] == true)
			if v then
				applyClassState(cl.className, true)
				State.GroupsHidden[cl.className] = true
			else
				applyClassState(cl.className, false)
				State.GroupsHidden[cl.className] = nil
			end
			saveConfig()
			setSw(v)
			cntLbl.TextColor3 = v and C.Accent or C.Dim
		end)

		rowClick.MouseButton1Click:Connect(function()
			clearCard()
			cardTitle.Text = "All " .. cl.className .. " (" .. cl.count .. ")"
			toggleWidget(cardHolder, "Hide ALL " .. cl.className, function()
				return State.GroupsHidden[cl.className] == true
			end, function(v)
				if v then
					applyClassState(cl.className, true)
					State.GroupsHidden[cl.className] = true
				else
					applyClassState(cl.className, false)
					State.GroupsHidden[cl.className] = nil
				end
				saveConfig()
			end)
			infoWidget(cardHolder, function() return "Instances of this class in Workspace (incl. children). Hiding a class kills rendering of EVERY instance — careful with Terrain." end)
		end)

		table.insert(rows, {
			row = row, rowBg = rowBg, nameLbl = nameLbl, cntLbl = cntLbl,
			data = { name = cl.className },
		})
	end
	applySearch(rows)
end

local function buildSettingsTab()
	clearRows()
	titleLbl.Text = "Render Killer / Settings"

	local entries = {
		{ name = "Auto Hide", desc = "Auto-hide groups of 3+ far objects" },
		{ name = "Max Distance", desc = "Auto-hide threshold in studs" },
	}
	local rows = {}
	for i, e in ipairs(entries) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Parent = rowsScroll
		row.LayoutOrder = i
		row.data = { name = e.name }

		local rowBg = Instance.new("Frame")
		rowBg.Size = UDim2.new(0, 172, 0, 28)
		rowBg.Position = UDim2.new(0, 4, 0, 2)
		rowBg.BackgroundColor3 = C.Row
		rowBg.BackgroundTransparency = 1
		rowBg.BorderSizePixel = 0
		rowBg.Parent = row
		corner(rowBg, 6)

		local rowClick = Instance.new("TextButton")
		rowClick.Size = UDim2.new(1, -10, 1, 0)
		rowClick.Position = UDim2.new(0, 10, 0, 0)
		rowClick.BackgroundTransparency = 1
		rowClick.Text = ""
		rowClick.AutoButtonColor = false
		rowClick.Parent = rowBg

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -20, 1, 0)
		nameLbl.Position = UDim2.new(0, 4, 0, 0)
		nameLbl.Text = e.name
		nameLbl.TextColor3 = C.Sub
		nameLbl.Font = Enum.Font.GothamMedium
		nameLbl.TextSize = 12
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Parent = rowClick

		table.insert(rows, { row = row, rowBg = rowBg, nameLbl = nameLbl, data = { name = e.name } })
	end
	applySearch(rows)

	clearCard()
	cardTitle.Text = "Settings"

	toggleWidget(cardHolder, "Auto-Hide New Spam", function() return State.AutoHideNew end, function(v)
		State.AutoHideNew = v
		saveConfig()
	end, "rk_autohide")

	sliderWidget(cardHolder, "Max Distance", 100, 5000, function() return State.MaxDist end, function(v)
		State.MaxDist = v
		saveConfig()
	end)

	buttonWidget(cardHolder, "RESTORE EVERYTHING", function()
		State.Hidden = {}
		State.GroupsHidden = {}
		-- restore all tracked parts
		for obj in pairs(savedProps) do
			restorePart(obj)
		end
		-- re-scan: restore groups even if props were re-created by the game
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency == 1 and not d:FindFirstChild("__rkSaved") then
				-- try restoring by known saved records only
			end
		end
		saveConfig()
		refreshUI(currentTab)
	end, true)

	buttonWidget(cardHolder, "Rescan Workspace", function()
		refreshUI(currentTab)
	end)

	infoWidget(cardHolder, function() return "ROBOX Render Killer v1.0\nRightCtrl - show/hide UI.\nMiddle-click a toggle = bind a key.\nConfig auto-saves on change." end)
end

-- tabs
local tabObjects = addTab("Objects", "O", buildObjectsTab)
local tabClasses = addTab("Classes", "C", buildClassesTab)
local tabSettings = addTab("Settings", "S", buildSettingsTab)

refreshUI = function(tab)
	if not tab then tab = tabObjects end
	selectTab(tab)
	if tab == tabObjects then buildObjectsTab()
	elseif tab == tabClasses then buildClassesTab()
	else buildSettingsTab() end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	refreshUI(currentTab)
end)

--================ Drag (top strip) ================
do
	local dragBtn = Instance.new("TextButton")
	dragBtn.Size = UDim2.new(0, 500, 0, TOP_H)
	dragBtn.Position = UDim2.new(0, RAIL_W, 0, 0)
	dragBtn.BackgroundTransparency = 1
	dragBtn.Text = ""
	dragBtn.AutoButtonColor = false
	dragBtn.Parent = win

	local dragging, dragInput, dragStart, startPos
	dragBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = win.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	dragBtn.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = (input.Position - dragStart) / UI_SCALE
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

--================ Toggle key ================
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		gui.Enabled = not gui.Enabled
	end
end)

--================ Init ================
refreshUI(tabObjects)

print("[ROBOX Render Killer v1.0] Loaded — Workspace object groups, class kill-switches, auto-hide. RightCtrl = toggle UI.")
