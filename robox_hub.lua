--[[
   ROBOX HUB  -  Xeno Edition  v11.1
   2-column layout, opaque UI, keybinds on toggles (no Show Binds window).
   Neon redesign: gradient accents, glow toggles, modern cards.
   Built for Xeno | https://www.xeno.now/
]]

--================ Services ================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

--================ State ================
local State = {
	Fly = false,
	Noclip = false,
	God = false,
	Speed = false,
	SpeedMode = "hard",
	FlySpeed = 55,
	FlyBoost = 3,
	FlyMode = "standard",
	WalkSpeed = 70,
	WalkBoost = 3,
	VehicleSpeed = false,
	VehicleMaxSpeed = 120,
	JumpPower = 50,
	Gravity = 196.2,
	ESPBox = true,
	ESPName = false,
	ESPHealth = false,
	ESPEnabled = true,
	ESPMaxDist = 4000,
	AutoClicker = false,
	AutoClickerMin = 5,
	AutoClickerMax = 10,
	MarkerPos = nil,
	CursorTP = false,
	MaceTP = false,
	MaceInterval = 0.5,
	MaceOffsetX = 0,
	MaceOffsetY = 0,
	MaceOffsetZ = 3,
	Spinner = false,
	SpinnerSpeed = 15,
	SpinnerMode = "hard",
	AimEnabled = false,
	AimMode = "silent",
	AimCameraMode = "standard",
	AimFOV = 120,
	AimSmoothing = 5,
	AimDeadzone = 5,
	AimPrediction = 0,
	AimTeamCheck = true,
	AimVisibleCheck = false,
	AimTargetPart = "Head",
	ArrayList = false,
	CycleTP = false,
	CycleInterval = 500,
	CycleIndex = 1,
	BotRecord = false,
	BotPlay = false,
	BotLoop = false,
	BotSpeed = 1,
	Fullbright = false,
	InfJump = false,
	AntiAFK = false,
}

-- snapshot of factory defaults (used by Settings -> Reset Config)
local DEFAULTS = {}
for k, v in pairs(State) do DEFAULTS[k] = v end

-- list of features for the ArrayList overlay (toggles + sliders with values)
local arrayListEntries = {}

--================ Config System ================
local CONFIG_FILE = "RoboxHubConfig.json"
local bindKeys = {}
local unboundIds = {}   -- ids explicitly unbound by user (saved as "NONE")
local configDirty = false

local function saveConfig()
	if not writefile then return end
	-- copy State, dropping non-serializable/session fields (MarkerPos is Vector3)
	local stateCopy = {}
	for k, v in pairs(State) do
		if k ~= "MarkerPos" and k ~= "CycleIndex" and k ~= "BotRecord" and k ~= "BotPlay" then stateCopy[k] = v end
	end
	local cfg = { state = stateCopy, bindKeys = {} }
	for id, kc in pairs(bindKeys) do
		if kc and kc ~= Enum.KeyCode.Unknown then
			local ok, name = pcall(function() return kc.Name end)
			if ok and name then cfg.bindKeys[id] = name end
		end
	end
	for id in pairs(unboundIds) do
		if cfg.bindKeys[id] == nil then cfg.bindKeys[id] = "NONE" end
	end
	local ok, json = pcall(function() return HttpService:JSONEncode(cfg) end)
	if ok and json then
		pcall(writefile, CONFIG_FILE, json)
		configDirty = false
	end
end

local function loadConfig()
	if not readfile then return end
	local ok, content = pcall(readfile, CONFIG_FILE)
	if not ok or not content then return end
	local ok2, cfg = pcall(function() return HttpService:JSONDecode(content) end)
	if not ok2 or type(cfg) ~= "table" then return end
	if type(cfg.state) == "table" then
		for k, v in pairs(cfg.state) do
			if k ~= "MarkerPos" and State[k] ~= nil and type(State[k]) == type(v) then
				State[k] = v
			end
		end
	end
	if type(cfg.bindKeys) == "table" then
		for id, keyName in pairs(cfg.bindKeys) do
			if type(keyName) == "string" then
				if keyName == "NONE" then
					unboundIds[id] = true -- explicitly unbound
				else
					local ok, kc = pcall(function() return Enum.KeyCode[keyName] end)
					if ok and kc and kc ~= Enum.KeyCode.Unknown then
						bindKeys[id] = kc
					end
				end
			end
		end
	end
end

loadConfig()

task.spawn(function()
	while true do
		task.wait(2)
		if configDirty then saveConfig() end
	end
end)

--================ Theme ================
-- skeet-style palette: deep flat dark, thin precise strokes, soft lilac accent
local Theme = {
	Bg          = Color3.fromRGB(28, 28, 34),
	Sidebar     = Color3.fromRGB(34, 34, 42),
	Panel       = Color3.fromRGB(42, 42, 52),
	Card        = Color3.fromRGB(46, 46, 56),
	CardHover   = Color3.fromRGB(56, 56, 68),
	Accent      = Color3.fromRGB(224, 71, 71),
	Accent2     = Color3.fromRGB(130, 205, 225),
	Text        = Color3.fromRGB(242, 242, 248),
	SubText     = Color3.fromRGB(168, 168, 184),
	DimText     = Color3.fromRGB(120, 120, 138),
	ToggleOff   = Color3.fromRGB(58, 58, 70),
	Stroke      = Color3.fromRGB(60, 60, 74),
	StrokeDim   = Color3.fromRGB(50, 50, 62),
	Danger      = Color3.fromRGB(225, 100, 110),
	Success     = Color3.fromRGB(100, 210, 140),
}

--================ Constants ================
local PAD = 12
local GAP = 8
local RADIUS = 6
local RADIUS_SM = 6

--================ Helpers ================
local function tween(obj, t, props)
	TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or RADIUS)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Stroke
	s.Thickness = thickness or 1
	s.Transparency = 1  -- по умолчанию линии скрыты (чистый плоский вид)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function gradient(parent, c1, c2, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rot or 0
	g.Parent = parent
	return g
end

local function padding(parent, all)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, all or PAD)
	p.PaddingRight = UDim.new(0, all or PAD)
	p.PaddingTop = UDim.new(0, all or PAD)
	p.PaddingBottom = UDim.new(0, all or PAD)
	p.Parent = parent
	return p
end

local function listLayout(parent, gap)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or GAP)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

local function card(frame)
	frame.BackgroundColor3 = Theme.Card
	frame.BackgroundTransparency = 0
	corner(frame, RADIUS)
	local cs = stroke(frame, Theme.StrokeDim, 1)
	if frame:IsA("GuiButton") or frame:IsA("Frame") then
		frame.MouseEnter:Connect(function()
			tween(frame, 0.18, {BackgroundColor3 = Theme.CardHover})
			tween(cs, 0.18, {Color = Theme.Stroke})
		end)
		frame.MouseLeave:Connect(function()
			tween(frame, 0.18, {BackgroundColor3 = Theme.Card})
			tween(cs, 0.18, {Color = Theme.StrokeDim})
		end)
	end
end

local setUIVisible
local cursorKeepConn = nil
local savedMouseBehavior = nil
local savedMouseIconEnabled = nil
local stopSpinner, startSpinner

local function getGuiParent()
	-- candidates in priority order; each one is validated before use.
	-- (Xeno's gethui can return a broken/non-Instance value — parenting to it
	--  would throw and kill the whole script before the UI is ever built)
	local candidates = {}
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and typeof(hui) == "Instance" then table.insert(candidates, hui) end
	end
	local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and cg then table.insert(candidates, cg) end
	local ok3, pg = pcall(function() return player:WaitForChild("PlayerGui") end)
	if ok3 and pg then table.insert(candidates, pg) end
	-- probe: the container must actually accept parenting
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

local function getRoot()
	local char = player.Character
	if not char then return end
	return char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

--================ Keybind System ================
local bindActions = {}
local bindConns = {}

local function keyCodeName(kc)
	if not kc or kc == Enum.KeyCode.Unknown then return "—" end
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
	if keyCode and keyCode ~= Enum.KeyCode.Unknown then
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
	configDirty = true
end

--================ Fly ================
local flyBV, flyBG, flyConn
local flyTarget, flyIsVehicle = nil, false
local savedCameraType, savedCameraSubject = nil, nil
local flyLastTickAt = 0
local FLY_BYPASS_TICK = 0.15 -- bypass: re-activate fly once per tick

local function getFlyTarget()
	local root, hum = getRoot()
	if not root or not hum then return nil, nil, false end
	local seat = hum.SeatPart
	if seat then return seat, hum, true end
	return root, hum, false
end

local function restoreCamera()
	if savedCameraType then camera.CameraType = savedCameraType savedCameraType = nil end
	if savedCameraSubject then camera.CameraSubject = savedCameraSubject savedCameraSubject = nil end
end

local function stopFly()
	if flyConn then flyConn:Disconnect() flyConn = nil end
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	restoreCamera()
	flyTarget = nil
	flyIsVehicle = false
	local _, hum = getRoot()
	if hum then hum.PlatformStand = false end
end

local function attachFly(target, hum, isVehicle)
	flyTarget = target
	flyIsVehicle = isVehicle
	if not isVehicle and hum then hum.PlatformStand = true end
	if isVehicle then
		if not savedCameraType then
			savedCameraType = camera.CameraType
			savedCameraSubject = camera.CameraSubject
		end
		camera.CameraType = Enum.CameraType.Custom
		if hum and hum.Parent then camera.CameraSubject = hum end
	else
		restoreCamera()
	end
	if flyBV then flyBV:Destroy() end
	flyBV = Instance.new("BodyVelocity")
	flyBV.Velocity = Vector3.zero
	flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	flyBV.Parent = target
	if flyBG then flyBG:Destroy() end
	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	flyBG.P = isVehicle and 40000 or 90000
	flyBG.D = isVehicle and 300 or 100
	flyBG.CFrame = camera.CFrame
	flyBG.Parent = target
end

local function startFly()
	local target, hum, isVehicle = getFlyTarget()
	if not target or not hum then return end
	stopFly()
	attachFly(target, hum, isVehicle)
	flyLastTickAt = 0
	flyConn = RunService.RenderStepped:Connect(function()
		if not State.Fly then return end
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local curTarget, curHum, curIsVehicle = getFlyTarget()
		if not curTarget or not curHum then return end
		if curTarget ~= flyTarget or curIsVehicle ~= flyIsVehicle then
			if not flyIsVehicle then
				local _, oldHum = getRoot()
				if oldHum then oldHum.PlatformStand = false end
			end
			attachFly(curTarget, curHum, curIsVehicle)
		end
		if not flyTarget or not flyTarget.Parent then return end
		if not flyBV or not flyBG then return end

		-- BYPASS: re-activate fly once per tick — destroy and re-create the
		-- force objects so the anti-cheat can't flag a long-living
		-- BodyVelocity/BodyGyro on the character
		if State.FlyMode == "bypass" then
			local now = os.clock()
			if now - flyLastTickAt >= FLY_BYPASS_TICK then
				flyLastTickAt = now
				local t, h, veh = flyTarget, curHum, flyIsVehicle
				if flyBV then flyBV:Destroy() flyBV = nil end
				if flyBG then flyBG:Destroy() flyBG = nil end
				attachFly(t, h, veh)
			end
		end

		if flyIsVehicle and cam.CameraType ~= Enum.CameraType.Custom then
			cam.CameraType = Enum.CameraType.Custom
		end
		flyBG.CFrame = cam.CFrame
		local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.E) then move += Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then move -= Vector3.new(0, 1, 0) end
		local spd = State.FlySpeed
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
			spd = State.FlySpeed * State.FlyBoost
		end
		if move.Magnitude > 0 then move = move.Unit * spd end
		flyBV.Velocity = move
	end)
end

--================ Noclip ================
local noclipConn
local noclipSaved = {}

local function stopNoclip()
	if noclipConn then noclipConn:Disconnect() noclipConn = nil end
	-- restore original collision state
	for part, original in pairs(noclipSaved) do
		if part and part.Parent then
			part.CanCollide = original
		end
	end
	table.clear(noclipSaved)
end

local function startNoclip()
	stopNoclip()
	noclipConn = RunService.Stepped:Connect(function()
		local char = player.Character
		if not char then return end
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				noclipSaved[p] = true
				p.CanCollide = false
			end
		end
	end)
end

--================ Stats ================
local function applyStats()
	local _, hum = getRoot()
	if hum then
		hum.WalkSpeed = State.Speed and State.WalkSpeed or 16
		hum.UseJumpPower = true
		hum.JumpPower = State.JumpPower
	end
	Workspace.Gravity = State.Gravity
end

--================ God Mode (client-side heal) ================
local godConn = nil

local function applyGod()
	local _, hum = getRoot()
	if not hum then return end
	if State.God and hum.Health < hum.MaxHealth then
		hum.Health = hum.MaxHealth
	end
end

local function startGod()
	if godConn then return end
	applyGod()
	godConn = RunService.Heartbeat:Connect(applyGod)
end

local function stopGod()
	if godConn then godConn:Disconnect() godConn = nil end
end

--================ Fullbright / Infinite Jump / Anti-AFK ================
local lightingSaved = nil

local function applyFullbright()
	local Lighting = game:GetService("Lighting")
	if State.Fullbright then
		if not lightingSaved then
			lightingSaved = {
				Brightness = Lighting.Brightness,
				ClockTime = Lighting.ClockTime,
				FogEnd = Lighting.FogEnd,
				GlobalShadows = Lighting.GlobalShadows,
				Ambient = Lighting.Ambient,
				OutdoorAmbient = Lighting.OutdoorAmbient,
			}
		end
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(178, 178, 178)
		Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
	elseif lightingSaved then
		Lighting.Brightness = lightingSaved.Brightness
		Lighting.ClockTime = lightingSaved.ClockTime
		Lighting.FogEnd = lightingSaved.FogEnd
		Lighting.GlobalShadows = lightingSaved.GlobalShadows
		Lighting.Ambient = lightingSaved.Ambient
		Lighting.OutdoorAmbient = lightingSaved.OutdoorAmbient
		lightingSaved = nil
	end
end

RunService.Heartbeat:Connect(function()
	if not State.InfJump then return end
	local _, hum = getRoot()
	if hum and hum.FloorMaterial == Enum.Material.Air then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

-- NOTE: UserInputService.Idle was removed from Roblox ("not a valid member").
-- The canonical anti-AFK hook is LocalPlayer.Idled.
player.Idled:Connect(function()
	if not State.AntiAFK then return end
	local vu = game:GetService("VirtualUser")
	pcall(function()
		vu:CaptureController()
		vu:ClickButton2(Vector2.new(0, 0))
	end)
end)

task.spawn(function()
	RunService.Heartbeat:Connect(function()
		if State.Speed and State.SpeedMode == "hard" then
			local _, hum = getRoot()
			if hum then
				local ws = State.WalkSpeed
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
					ws = ws * State.WalkBoost
				end
				hum.WalkSpeed = ws
			end
		end
	end)
end)

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	applyStats()
	if State.God then startGod() end
	if State.Fly then task.wait(0.1) stopFly() startFly() end
	if State.Noclip then startNoclip() end
	if State.Spinner then task.wait(0.1) stopSpinner() startSpinner() end
end)

--================ ESP ================
-- NOTE: getCharacterParts/getTargetPart MUST be defined before ESP code,
-- otherwise updateESPForPlayer calls a nil global and nothing renders.
local function getCharacterParts(char)
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
	local head = char:FindFirstChild("Head")
	if not hum or not hrp then return nil end
	return hum, hrp, head
end

local function getTargetPart(char)
	if not char then return nil end
	local part = char:FindFirstChild(State.AimTargetPart)
	if part then return part end
	-- fallback chain
	local fallbacks = { "Head", "HumanoidRootPart", "Torso", "UpperTorso", "Chest" }
	for _, name in ipairs(fallbacks) do
		local fb = char:FindFirstChild(name)
		if fb then return fb end
	end
	return nil
end

local espObjects = {}
local espConnections = {}

local espGui = Instance.new("ScreenGui")
espGui.Name = "RoboxESP"
espGui.ResetOnSpawn = false
espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
espGui.IgnoreGuiInset = true
espGui.DisplayOrder = 1000
espGui.Parent = getGuiParent()

local espContainer = Instance.new("Frame")
espContainer.Size = UDim2.new(1, 0, 1, 0)
espContainer.BackgroundTransparency = 1
espContainer.BorderSizePixel = 0
espContainer.Parent = espGui

local function clearESPForPlayer(p)
	local d = espObjects[p]
	if d and d.holder then d.holder:Destroy() end
	espObjects[p] = nil
end

local function createESPForPlayer(p)
	if p == player then return end
	-- recreate holder if it was destroyed (respawn, etc)
	if espObjects[p] and espObjects[p].holder and espObjects[p].holder.Parent then
		return
	end
	if espObjects[p] then
		espObjects[p] = nil
	end
	local holder = Instance.new("Frame")
	holder.Name = p.Name
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Visible = false
	holder.Parent = espContainer

	local function mkBar()
		local b = Instance.new("Frame")
		b.BackgroundColor3 = Theme.Accent2
		b.BorderSizePixel = 0
		b.Visible = false
		b.Parent = holder
		return b
	end

	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = p.Name
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 13
	nameLbl.TextStrokeTransparency = 0
	nameLbl.Visible = false
	nameLbl.Parent = holder

	local healthLbl = Instance.new("TextLabel")
	healthLbl.BackgroundTransparency = 1
	healthLbl.Text = "100 HP"
	healthLbl.TextColor3 = Theme.Success
	healthLbl.Font = Enum.Font.GothamBold
	healthLbl.TextSize = 12
	healthLbl.TextStrokeTransparency = 0
	healthLbl.Visible = false
	healthLbl.Parent = holder

	espObjects[p] = {
		holder = holder,
		boxTop = mkBar(), boxBottom = mkBar(), boxLeft = mkBar(), boxRight = mkBar(),
		name = nameLbl, health = healthLbl,
	}
end

local function updateESPForPlayer(p)
	local d = espObjects[p]
	if not d then return end
	if not d.holder or not d.holder.Parent then
		-- holder was destroyed — clear entry so the loop re-creates it
		espObjects[p] = nil
		return
	end
	local char = p.Character
	if not char then d.holder.Visible = false return end
	local hum, hrp, head = getCharacterParts(char)
	if not hum or not hrp then d.holder.Visible = false return end
	-- no Health > 0 gate (like Infinite Yield): many games use custom health
	-- or keep Health at 0 until actual spawn — ESP should still show
	local cam = Workspace.CurrentCamera
	if not cam then d.holder.Visible = false return end
	local localRoot = getRoot()
	local dist = localRoot and (hrp.Position - localRoot.Position).Magnitude or 0
	if dist > State.ESPMaxDist then d.holder.Visible = false return end

	-- use head if available, else use hrp for top
	local topPart = head or hrp
	local topPos = topPart.Position + Vector3.new(0, 0.5, 0)
	local bottomPos = hrp.Position - Vector3.new(0, 3.2, 0)
	-- behind-camera check: WorldToViewportPoint returns mirrored garbage
	-- for points behind the camera (adornments don't have this problem)
	local camCF = cam.CFrame
	if (topPos - camCF.Position):Dot(camCF.LookVector) <= 0 or (bottomPos - camCF.Position):Dot(camCF.LookVector) <= 0 then
		d.holder.Visible = false
		return
	end
	local ts, osT = cam:WorldToViewportPoint(topPos)
	local bs, osB = cam:WorldToViewportPoint(bottomPos)
	if not osT and not osB then d.holder.Visible = false return end

	d.holder.Visible = true
	local h = math.abs(bs.Y - ts.Y)
	local w = h * 0.55
	local cx = (ts.X + bs.X) / 2
	local lx = cx - w / 2
	local rx = cx + w / 2

	if State.ESPBox then
		local et = 2
		for _, b in ipairs({d.boxTop, d.boxBottom, d.boxLeft, d.boxRight}) do b.Visible = true end
		d.boxTop.Size = UDim2.new(0, w, 0, et); d.boxTop.Position = UDim2.new(0, lx, 0, ts.Y)
		d.boxBottom.Size = UDim2.new(0, w, 0, et); d.boxBottom.Position = UDim2.new(0, lx, 0, bs.Y - et)
		d.boxLeft.Size = UDim2.new(0, et, 0, h); d.boxLeft.Position = UDim2.new(0, lx, 0, ts.Y)
		d.boxRight.Size = UDim2.new(0, et, 0, h); d.boxRight.Position = UDim2.new(0, rx - et, 0, ts.Y)
	else
		for _, b in ipairs({d.boxTop, d.boxBottom, d.boxLeft, d.boxRight}) do b.Visible = false end
	end

	if State.ESPName then
		d.name.Visible = true
		d.name.Size = UDim2.new(0, 200, 0, 18)
		d.name.Position = UDim2.new(0, cx - 100, 0, ts.Y - 20)
		d.name.TextColor3 = (p.Team and player.Team and p.Team ~= player.Team) and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
	else
		d.name.Visible = false
	end

	if State.ESPHealth then
		d.health.Visible = true
		local hp, mhp = math.floor(hum.Health), math.floor(hum.MaxHealth)
		d.health.Text = hp .. " / " .. mhp .. " HP"
		d.health.Size = UDim2.new(0, 200, 0, 16)
		d.health.Position = UDim2.new(0, cx - 100, 0, bs.Y + 2)
		local r = hum.MaxHealth > 0 and (hum.Health / hum.MaxHealth) or 0
		d.health.TextColor3 = r > 0.6 and Color3.fromRGB(80, 220, 120) or r > 0.3 and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(255, 80, 80)
	else
		d.health.Visible = false
	end
end

local espLoop
local function startESP()
	if espLoop then return end
	espGui.Enabled = true
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then createESPForPlayer(p) end
	end
	espLoop = RunService.RenderStepped:Connect(function()
		if not State.ESPEnabled then
			for p in pairs(espObjects) do
				local d = espObjects[p]
				if d and d.holder then d.holder.Visible = false end
			end
			return
		end
		for p in pairs(espObjects) do updateESPForPlayer(p) end
		-- (re)create holders: also covers respawns / destroyed holders
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and p.Character then
				local d = espObjects[p]
				if not d or not d.holder or not d.holder.Parent then
					createESPForPlayer(p)
				end
			end
		end
	end)
	espConnections.added = Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function() task.wait(0.5) createESPForPlayer(p) end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		p.CharacterAdded:Connect(function() task.wait(0.5) createESPForPlayer(p) end)
	end
	espConnections.removed = Players.PlayerRemoving:Connect(clearESPForPlayer)
end

local function stopESP()
	if espLoop then espLoop:Disconnect() espLoop = nil end
	for _, c in pairs(espConnections) do if c then c:Disconnect() end end
	table.clear(espConnections)
	for p in pairs(espObjects) do clearESPForPlayer(p) end
	-- hide instead of destroy: startESP must be able to re-enable the gui
	if espGui then espGui.Enabled = false end
end

startESP()

--================ Auto Clicker ================
local autoClickerRunning = false
local clickFunction = nil
if typeof(mouse1click) == "function" then
	clickFunction = mouse1click
elseif typeof(mouse1press) == "function" and typeof(mouse1release) == "function" then
	clickFunction = function() mouse1press() task.wait(0.01) mouse1release() end
end

local function stopAutoClicker() autoClickerRunning = false end

local function startAutoClicker()
	stopAutoClicker()
	autoClickerRunning = true
	task.spawn(function()
		while autoClickerRunning and State.AutoClicker do
			if clickFunction then
				local mn = math.max(1, State.AutoClickerMin)
				local mx = math.max(mn, State.AutoClickerMax)
				clickFunction()
				task.wait(1 / (mn + math.random() * (mx - mn)))
			else
				task.wait(0.05)
			end
		end
		autoClickerRunning = false
	end)
end

--================ Teleport ================
local markerPart, cursorPreview, cursorPreviewConn, cursorInputConn = nil, nil, nil, nil

local function clearMarker()
	if markerPart then markerPart:Destroy() markerPart = nil end
	State.MarkerPos = nil
end

local function setMarker(pos)
	clearMarker()
	State.MarkerPos = pos
	markerPart = Instance.new("Part")
	markerPart.Anchored = true
	markerPart.CanCollide = false
	markerPart.CanQuery = false
	markerPart.Size = Vector3.new(4, 0.2, 4)
	markerPart.Position = pos
	markerPart.Transparency = 0.4
	markerPart.Color = Theme.Accent2
	markerPart.Material = Enum.Material.Neon
	markerPart.Parent = Workspace
end

local function teleportTo(pos)
	local root = getRoot()
	if root then root.CFrame = CFrame.new(pos) end
end

local function stopCursorPreview()
	if cursorPreviewConn then cursorPreviewConn:Disconnect() cursorPreviewConn = nil end
	if cursorInputConn then cursorInputConn:Disconnect() cursorInputConn = nil end
	if cursorPreview then cursorPreview:Destroy() cursorPreview = nil end
end

local function startCursorPreview()
	stopCursorPreview()
	cursorPreview = Instance.new("Part")
	cursorPreview.Anchored = true
	cursorPreview.CanCollide = false
	cursorPreview.CanQuery = false
	cursorPreview.Size = Vector3.new(3, 0.2, 3)
	cursorPreview.Transparency = 0.3
	cursorPreview.Color = Theme.Accent2
	cursorPreview.Material = Enum.Material.Neon
	cursorPreview.Parent = Workspace
	cursorPreviewConn = RunService.RenderStepped:Connect(function()
		if not State.CursorTP or not cursorPreview or not cursorPreview.Parent then return end
		local m = player:GetMouse()
		if m and m.Hit then cursorPreview.Position = m.Hit.Position end
	end)
	cursorInputConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or not State.CursorTP then return end
		if input.KeyCode == Enum.KeyCode.T then
			local m = player:GetMouse()
			if m and m.Hit then teleportTo(m.Hit.Position) end
		end
	end)
end

--================ Cycle TP (multi-marker cycle) ================
local cycleMarkers = {}  -- { {pos = Vector3, part = Part, label = TextLabel} }
local cycleConn = nil
local cycleLastTP = 0

local function addCycleMarker(pos)
	local marker = Instance.new("Part")
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Size = Vector3.new(3, 0.2, 3)
	marker.Position = pos
	marker.Transparency = 0.5
	marker.Color = Theme.Accent
	marker.Material = Enum.Material.Neon
	marker.Parent = Workspace

	local idx = #cycleMarkers + 1
	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.new(0, 100, 0, 40)
	bg.StudsOffset = Vector3.new(0, 3, 0)
	bg.AlwaysOnTop = true
	bg.Parent = marker

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = tostring(idx)
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	lbl.TextStrokeTransparency = 0
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 24
	lbl.Parent = bg

	table.insert(cycleMarkers, {pos = pos, part = marker, label = lbl})
	-- renumber labels
	for i, m in ipairs(cycleMarkers) do
		m.label.Text = tostring(i)
	end
end

local function clearCycleMarkers()
	for _, m in ipairs(cycleMarkers) do
		if m.part and m.part.Parent then m.part:Destroy() end
	end
	cycleMarkers = {}
	State.CycleIndex = 1
end

local function removeLastCycleMarker()
	if #cycleMarkers == 0 then return end
	local last = cycleMarkers[#cycleMarkers]
	if last.part and last.part.Parent then last.part:Destroy() end
	table.remove(cycleMarkers, #cycleMarkers)
	if State.CycleIndex > #cycleMarkers then State.CycleIndex = 1 end
end

local function startCycleTP()
	if cycleConn then return end
	cycleLastTP = 0
	cycleConn = RunService.Heartbeat:Connect(function()
		if not State.CycleTP or #cycleMarkers == 0 then return end
		local now = os.clock()
		if now - cycleLastTP < (State.CycleInterval / 1000) then return end
		local root = getRoot()
		if not root then return end
		local marker = cycleMarkers[State.CycleIndex]
		if not marker then State.CycleIndex = 1 return end
		root.CFrame = CFrame.new(marker.pos)
		State.CycleIndex = State.CycleIndex % #cycleMarkers + 1
		cycleLastTP = now
	end)
end

local function stopCycleTP()
	if cycleConn then cycleConn:Disconnect() cycleConn = nil end
end

--================ Bot (Record/Playback) ================
local botFrames = {}
local botClickCount = 0
local recordConn = nil
local playConn = nil
local recordStart = 0
local playStart = 0
local pendingClick = nil

local function moveMouseTo(x, y)
	local current = UserInputService:GetMouseLocation()
	local dx = x - current.X
	local dy = y - current.Y
	if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then
		if mousemoverel then
			pcall(mousemoverel, dx, dy)
		elseif mousemoveabs then
			pcall(mousemoveabs, x, y)
		end
	end
end

-- click capture during recording
UserInputService.InputBegan:Connect(function(input, gpe)
	if not State.BotRecord then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local loc = UserInputService:GetMouseLocation()
		pendingClick = {x = loc.X, y = loc.Y}
	end
end)

function stopBotRecord()
	if recordConn then recordConn:Disconnect() recordConn = nil end
end

function startBotRecord()
	if recordConn then return end
	if playConn then State.BotPlay = false stopBotPlay() end
	botFrames = {}
	botClickCount = 0
	recordStart = os.clock()
	pendingClick = nil
	recordConn = RunService.RenderStepped:Connect(function()
		if not State.BotRecord then return end
		local root = getRoot()
		if not root then return end
		local elapsed = os.clock() - recordStart
		if pendingClick then botClickCount = botClickCount + 1 end
		table.insert(botFrames, {t = elapsed, cf = root.CFrame, click = pendingClick})
		pendingClick = nil
	end)
end

function stopBotPlay()
	if playConn then playConn:Disconnect() playConn = nil end
end

function startBotPlay()
	if playConn then return end
	if #botFrames == 0 then return end
	if recordConn then State.BotRecord = false stopBotRecord() end
	playStart = os.clock()
	local currentIdx = 1
	local lastClickIdx = 1
	playConn = RunService.RenderStepped:Connect(function()
		if not State.BotPlay then return end
		local elapsed = (os.clock() - playStart) * State.BotSpeed
		while currentIdx < #botFrames and botFrames[currentIdx + 1].t <= elapsed do
			currentIdx = currentIdx + 1
		end
		local frame = botFrames[currentIdx]
		if frame then
			local root = getRoot()
			if root and frame.cf then
				root.CFrame = frame.cf
			end
		end
		while lastClickIdx <= currentIdx do
			local f = botFrames[lastClickIdx]
			if f and f.click then
				moveMouseTo(f.click.x, f.click.y)
				if clickFunction then clickFunction() end
			end
			lastClickIdx = lastClickIdx + 1
		end
		if currentIdx >= #botFrames and elapsed >= botFrames[#botFrames].t then
			if State.BotLoop then
				playStart = os.clock()
				currentIdx = 1
				lastClickIdx = 1
			else
				State.BotPlay = false
				stopBotPlay()
			end
		end
	end)
end

function clearBotRecording()
	botFrames = {}
	botClickCount = 0
end

--================ Vehicle Speed ================
local vehicleConn = nil
local vehicleSaved = {}

local function getSeatedVehicleModel()
	local char = player.Character
	if not char then return nil, nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil, nil end
	local seat = hum.SeatPart
	if not seat or not seat.Parent or not seat:IsA("VehicleSeat") then return nil, nil end
	local model = seat:FindFirstAncestorOfClass("Model")
	return seat, model
end

local function stopVehicleSpeed()
	if vehicleConn then vehicleConn:Disconnect() vehicleConn = nil end
	for seat, orig in pairs(vehicleSaved) do
		if seat and seat.Parent then
			pcall(function() seat.MaxSpeed = orig end)
		end
	end
	table.clear(vehicleSaved)
end

local function startVehicleSpeed()
	stopVehicleSpeed()
	local function restoreSaved()
		for seat, orig in pairs(vehicleSaved) do
			if seat and seat.Parent then
				pcall(function() seat.MaxSpeed = orig end)
			end
		end
		table.clear(vehicleSaved)
	end
	vehicleConn = RunService.Heartbeat:Connect(function()
		if not State.VehicleSpeed then return end
		local seat, model = getSeatedVehicleModel()
		if not seat then
			restoreSaved()
			return
		end

		-- collect seats: whole model if small, else just the seat
		local seats = {}
		if model and #model:GetDescendants() <= 1000 then
			for _, obj in ipairs(model:GetDescendants()) do
				if obj:IsA("VehicleSeat") then
					table.insert(seats, obj)
				end
			end
		end
		if #seats == 0 then table.insert(seats, seat) end

		for _, vs in ipairs(seats) do
			if vehicleSaved[vs] == nil then
				vehicleSaved[vs] = vs.MaxSpeed
			end
			vs.MaxSpeed = State.VehicleMaxSpeed
		end
	end)
end

--================ MaceTP (follow nearest player) ================
local maceConn = nil
local maceTarget = nil
local maceLastTP = 0

local function getNearestPlayer()
	local root = getRoot()
	if not root then return nil end
	local closest, closestDist = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Torso")
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = (hrp.Position - root.Position).Magnitude
				if d < closestDist then
					closest = p
					closestDist = d
				end
			end
		end
	end
	return closest
end

local function startMaceTP()
	if maceConn then return end
	maceTarget = nil
	maceLastTP = 0
	-- noclip is forced ON while MaceTP is running (no collisions with walls/players)
	startNoclip()
	maceConn = RunService.Heartbeat:Connect(function()
		if not State.MaceTP then return end
		local now = os.clock()
		if now - maceLastTP < State.MaceInterval then return end

		-- re-validate current target, pick new if gone
		if not maceTarget or not maceTarget.Character or not maceTarget.Character:FindFirstChildOfClass("Humanoid") or maceTarget.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
			maceTarget = getNearestPlayer()
		end
		if not maceTarget then return end

		local hrp = maceTarget.Character:FindFirstChild("HumanoidRootPart") or maceTarget.Character:FindFirstChild("Torso")
		if not hrp then return end

		local root = getRoot()
		if not root then return end
		root.CFrame = hrp.CFrame * CFrame.new(State.MaceOffsetX, State.MaceOffsetY, State.MaceOffsetZ)
		maceLastTP = now
	end)
end

local function stopMaceTP()
	if maceConn then
		maceConn:Disconnect()
		maceConn = nil
	end
	maceTarget = nil
	-- noclip off together with MaceTP
	stopNoclip()
end

--================ Spinner ================
local spinnerBV, spinnerConn = nil, nil

function stopSpinner()
	if spinnerConn then spinnerConn:Disconnect() spinnerConn = nil end
	if spinnerBV then spinnerBV:Destroy() spinnerBV = nil end
end

function startSpinner()
	stopSpinner()
	local root = getRoot()
	if not root then return end
	spinnerBV = Instance.new("BodyAngularVelocity")
	spinnerBV.AngularVelocity = Vector3.new(0, State.SpinnerSpeed, 0)
	spinnerBV.MaxTorque = Vector3.new(0, math.huge, 0)
	spinnerBV.Parent = root
	spinnerConn = RunService.Heartbeat:Connect(function()
		if not State.Spinner then return end
		local r = getRoot()
		if not r then return end
		if not spinnerBV or not spinnerBV.Parent then
			spinnerBV = Instance.new("BodyAngularVelocity")
			spinnerBV.AngularVelocity = Vector3.new(0, State.SpinnerSpeed, 0)
			spinnerBV.MaxTorque = Vector3.new(0, math.huge, 0)
			spinnerBV.Parent = r
		elseif State.SpinnerMode == "hard" then
			spinnerBV.AngularVelocity = Vector3.new(0, State.SpinnerSpeed, 0)
		end
	end)
end

--================ Aimbot ================
local aimConn = nil
local aimFOVGui = nil
local aimTarget = nil
local aimRmbHeld = false

-- Track RMB via events (IsMouseButtonPressed is unreliable in some games)
UserInputService.InputBegan:Connect(function(input, gpe)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		aimRmbHeld = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		aimRmbHeld = false
		aimTarget = nil
	end
end)

-- getCharacterParts / getTargetPart are defined earlier (before ESP section)

local function isValidTarget(p)
	if p == player or not p.Character then return false end
	local hum = p.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	if State.AimTeamCheck and p.Team and player.Team and p.Team == player.Team then return false end
	return true
end

local function isVisible(p)
	local char = p.Character
	local part = getTargetPart(char)
	local cam = Workspace.CurrentCamera
	if not part or not cam then return false end
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {player.Character, char}
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	local ray = Workspace:Raycast(cam.CFrame.Position, (part.Position - cam.CFrame.Position), rayParams)
	return ray and ray.Instance and ray.Instance:IsDescendantOf(char)
end

local function getTargetScreenPos(p)
	local char = p.Character
	local part = getTargetPart(char)
	if not part then return nil end
	local cam = Workspace.CurrentCamera
	local sp, onScreen = cam:WorldToViewportPoint(part.Position)
	if not onScreen then return nil end
	return Vector2.new(sp.X, sp.Y)
end

local function getClosestPlayerToMouse(ignoreFOV)
	local cam = Workspace.CurrentCamera
	if not cam then return nil end
	local vp = cam.ViewportSize
	local center = Vector2.new(vp.X / 2, vp.Y / 2)
	local closest = nil
	local closestDist = math.huge
	local closest3D = nil
	local closest3DDist = math.huge
	local localRoot = getRoot()
	for _, p in ipairs(Players:GetPlayers()) do
		if isValidTarget(p) then
			if not State.AimVisibleCheck or isVisible(p) then
				local sp = getTargetScreenPos(p)
				if sp then
					local dist = (sp - center).Magnitude
					if (ignoreFOV or dist <= State.AimFOV) and dist < closestDist then
						closest = p
						closestDist = dist
					end
				elseif ignoreFOV and localRoot then
					-- range mode fallback: everyone is off-screen, pick nearest in 3D
					local part = p.Character and getTargetPart(p.Character)
					if part then
						local d3 = (part.Position - localRoot.Position).Magnitude
						if d3 < closest3DDist then
							closest3D = p
							closest3DDist = d3
						end
					end
				end
			end
		end
	end
	if closest then return closest end
	if ignoreFOV then return closest3D end
	return nil
end

local function isTargetStillValid()
	if not aimTarget or not isValidTarget(aimTarget) then return false end
	if State.AimVisibleCheck and not isVisible(aimTarget) then return false end
	local sp = getTargetScreenPos(aimTarget)
	if not sp then return false end
	local cam = Workspace.CurrentCamera
	local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	return (sp - center).Magnitude <= State.AimFOV * 1.5
end

--================ Silent Aim: BodyGyro + namecall hook ================
local mouse = player:GetMouse()
local oldNamecall = nil
local silentGyro = nil
local silentDebugAt = 0
local SILENT_DEBUG_FILE = "ROBOX_SilentDebug.txt"

-- append one line to a debug file next to RoboxHubConfig.json (Xeno workspace)
local function silentDebugLog(msg)
	pcall(function()
		if not writefile then return end
		local line = os.date("%H:%M:%S") .. "  " .. msg .. "\n"
		local old = ""
		pcall(function() old = readfile(SILENT_DEBUG_FILE) or "" end)
		if #old > 60000 then old = "" end -- keep the file small
		writefile(SILENT_DEBUG_FILE, old .. line)
	end)
end

-- Angle-based target selection: robust in first person. Instead of screen
-- projection (WorldToViewportPoint/onScreen — unreliable when the camera is
-- at your head), score each enemy by how aligned they are with the camera's
-- look direction. Works the same in first and third person.
local function getBestSilentTarget(ignoreFOV)
	local cam = Workspace.CurrentCamera
	if not cam then return nil end
	local camPos = cam.CFrame.Position
	local look = cam.CFrame.LookVector

	-- map the on-screen FOV circle (pixels) to an angular cone
	local vp = cam.ViewportSize
	local fovAngleRad
	if vp.Y > 0 then
		fovAngleRad = State.AimFOV * (math.rad(cam.FieldOfView) / vp.Y)
	else
		fovAngleRad = math.rad(45)
	end
	local dotThreshold = math.cos(math.clamp(fovAngleRad, 0, math.pi / 2))

	local best = nil
	local bestDot = -math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if isValidTarget(p) then
			if not State.AimVisibleCheck or isVisible(p) then
				local part = p.Character and getTargetPart(p.Character)
				if part then
					local dir = part.Position - camPos
					local mag = dir.Magnitude
					if mag > 0.01 then
						local dot = look:Dot(dir / mag)
						if (ignoreFOV or dot >= dotThreshold) and dot > bestDot then
							bestDot = dot
							best = p
						end
					end
				end
			end
		end
	end
	return best
end

-- shared: get silent target
local function getSilentTarget()
	if not State.AimEnabled or State.AimMode ~= "silent" then return nil, nil, nil end
	local target = getBestSilentTarget()
	-- fallback: nobody inside the FOV cone -> nearest to crosshair by angle
	if not target then target = getBestSilentTarget(true) end
	if not target or not target.Character then return nil, nil, nil end
	local part = getTargetPart(target.Character)
	if not part then return nil, nil, nil end

	local targetPos = part.Position
	if State.AimPrediction > 0 then
		local hrp = target.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			targetPos = targetPos + (hrp.AssemblyLinearVelocity * State.AimPrediction * 0.001)
		end
	end
	return target, part, targetPos
end

-- Hook __namecall (lightweight, no __index hook)
-- Argument rewriting helpers:
--  * Vector3 with unit length  -> DIRECTION: replaced with a direction toward
--    the target (length kept), NOT with a position
--  * Vector3 near camera/root  -> POSITION: replaced with targetPos
--  * CFrame                    -> keeps its position, LookVector points at target
--  * Ray                       -> rebuilt from its own origin toward target
--  * tables                    -> walked recursively (depth-limited)
local function classifyVector3(v, camPos, rootPos)
	local m = v.Magnitude
	if m >= 0.85 and m <= 1.15 then return "direction", m end
	local nearCam = (v - camPos).Magnitude
	local nearRoot = rootPos and (v - rootPos).Magnitude or math.huge
	if nearCam < 2000 or nearRoot < 500 then return "position", m end
	return "direction", m
end

local function describeArg(a)
	local t = typeof(a)
	if t == "Vector3" then
		local m = a.Magnitude
		local tag = (m >= 0.85 and m <= 1.15) and "dir" or "pos"
		return string.format("V3-%s(%.1f, %.1f, %.1f)", tag, a.X, a.Y, a.Z)
	elseif t == "CFrame" then
		return string.format("CF(%.1f, %.1f, %.1f)", a.X, a.Y, a.Z)
	elseif t == "Ray" then
		return string.format("Ray(o=%.1f, %.1f, %.1f)", a.Origin.X, a.Origin.Y, a.Origin.Z)
	elseif t == "table" then
		local n = 0
		for _ in pairs(a) do n = n + 1 end
		return "table(" .. n .. ")"
	elseif t == "Instance" then
		return "Instance(" .. a.ClassName .. ")"
	else
		return t
	end
end

local function installSilentHook()
	if oldNamecall then return end
	if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
		warn("[ROBOX HUB] hookmetamethod not found — silent aim remote hook disabled")
		return
	end

	local ok = pcall(function()
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()
			if not State.AimEnabled or State.AimMode ~= "silent" then
				return oldNamecall(self, ...)
			end
			if method ~= "FireServer" and method ~= "InvokeServer" then
				return oldNamecall(self, ...)
			end

			local target, part, targetPos = getSilentTarget()
			if not part then
				local now2 = os.clock()
				if now2 - silentDebugAt > 3 then
					silentDebugAt = now2
					local rn = "?"
					pcall(function() rn = self:GetFullName() end)
					local m = "[ROBOX silent] " .. rn .. ":" .. method .. " -> NO TARGET (no valid players: check Team Check / Visible Check)"
					print(m)
					silentDebugLog(m)
				end
				return oldNamecall(self, ...)
			end

			local args = {...}
			local cam = Workspace.CurrentCamera
			local camPos = cam and cam.CFrame.Position or Vector3.zero
			local rootPart = getRoot()
			local rootPos = rootPart and rootPart.Position or nil

			-- snapshot ORIGINAL args shape before rewriting (for diagnostics)
			local shape = {}
			for _, a in ipairs(args) do table.insert(shape, describeArg(a)) end

			-- find a plausible shot origin: position-like Vector3 closest to us
			local origin = nil
			local originIndex = nil
			local function scanForOrigin(t, depth)
				if depth > 4 then return end
				for k, v in pairs(t) do
					if typeof(v) == "Vector3" then
						local kind = classifyVector3(v, camPos, rootPos)
						if kind == "position" then
							local ref = rootPos or camPos
							if origin == nil or (v - ref).Magnitude < (origin - ref).Magnitude then
								origin = v
								originIndex = {t, k}
							end
						end
					elseif typeof(v) == "table" then
						scanForOrigin(v, depth + 1)
					end
				end
			end
			scanForOrigin(args, 1)

			local from = origin or camPos
			local toTarget = targetPos - from
			local toTargetDir = toTarget.Magnitude > 0.01 and toTarget.Unit or Vector3.zAxis

			local modified = false
			local hasOrientation = false -- direction / Ray / CFrame found in args

			local function walk1(tbl, depth)
				if depth > 4 then return end
				for _, v in pairs(tbl) do
					local t = typeof(v)
					if t == "Vector3" then
						local kind = classifyVector3(v, camPos, rootPos)
						if kind == "direction" then hasOrientation = true end
					elseif t == "Ray" or t == "CFrame" then
						hasOrientation = true
					elseif t == "table" then
						walk1(v, depth + 1)
					end
				end
			end
			walk1(args, 1)

			local function fixValue(v)
				local t = typeof(v)
				if t == "CFrame" then
					modified = true
					if (targetPos - v.Position).Magnitude < 0.01 then return v end
					return CFrame.lookAt(v.Position, targetPos)
				elseif t == "Vector3" then
					local kind, m = classifyVector3(v, camPos, rootPos)
					if kind == "direction" then
						modified = true
						return toTargetDir * m
					end
					if hasOrientation then
						return nil -- position args untouched when a direction
						            -- decides the shot (origin must stay real)
					end
					modified = true
					return targetPos
				elseif t == "Ray" then
					modified = true
					local o = v.Origin
					local d = targetPos - o
					return Ray.new(o, d.Magnitude > 0.01 and d.Unit * 5000 or Vector3.zAxis)
				end
				return nil
			end

			local function walk(tbl, depth)
				if depth > 4 then return end
				for k, v in pairs(tbl) do
					local fixed = fixValue(v)
					if fixed ~= nil then
						tbl[k] = fixed
					elseif typeof(v) == "Instance" and v:IsA("BasePart") then
						local model = v:FindFirstAncestorOfClass("Model")
						if model and Players:GetPlayerFromCharacter(model) then
							tbl[k] = part
							modified = true
						end
					elseif typeof(v) == "table" then
						walk(v, depth + 1)
					end
				end
			end
			walk(args, 1)

			-- keep the shot origin real (nearest position to us must not be
			-- rewritten, otherwise server raycasts start from inside the target)
			if originIndex and hasOrientation then
				local refT, refK = originIndex[1], originIndex[2]
				local cur = refT[refK]
				if typeof(cur) == "Vector3" and (cur - targetPos).Magnitude < 0.01 then
					refT[refK] = origin
				end
			end

			-- throttled debug: shows what the game actually sends (ORIGINAL shape)
			local now = os.clock()
			if now - silentDebugAt > 3 then
				silentDebugAt = now
				local rn = "?"
				pcall(function() rn = self:GetFullName() end)
				local m = "[ROBOX silent] " .. rn .. ":" .. method .. " | args: " .. table.concat(shape, ", ") .. " | target=" .. tostring(target.Name) .. " | modified=" .. tostring(modified)
				print(m)
				silentDebugLog(m)
			end

			if modified then
				return oldNamecall(self, unpack(args))
			end
			return oldNamecall(self, ...)
		end)
	end)

	local hookOK = ok
	local hookMsg = "[ROBOX HUB] Silent namecall hook: " .. (hookOK and "OK" or "FAIL")
	print(hookMsg)
	silentDebugLog(hookMsg)
	silentDebugLog("hookmetamethod available: " .. tostring(type(hookmetamethod) == "function") .. " | game: " .. tostring(game.PlaceId))
end

installSilentHook()

-- Silent aim body rotation loop (like Spinner, but with BodyGyro)
local silentConn = nil
local function startSilent()
	if silentConn then return end
	silentConn = RunService.Heartbeat:Connect(function()
		if not State.AimEnabled or State.AimMode ~= "silent" then
			if silentGyro then silentGyro:Destroy() silentGyro = nil end
			return
		end

		local target, part, targetPos = getSilentTarget()
		if not target or not part then
			if silentGyro then silentGyro:Destroy() silentGyro = nil end
			return
		end

		local root = getRoot()
		if not root then return end

		-- create BodyGyro if missing (same pattern as Spinner)
		if not silentGyro or not silentGyro.Parent then
			silentGyro = Instance.new("BodyGyro")
			silentGyro.MaxTorque = Vector3.new(0, math.huge, 0)
			silentGyro.P = 90000
			silentGyro.D = 100
			silentGyro.Parent = root
		end

		-- rotate HumanoidRootPart to face target (Y axis only)
		local rootPos = root.Position
		local dir = targetPos - rootPos
		if dir.Magnitude > 0.01 then
			silentGyro.CFrame = CFrame.lookAt(rootPos, Vector3.new(targetPos.X, rootPos.Y, targetPos.Z))
		end
	end)
end

local function stopSilent()
	if silentConn then
		silentConn:Disconnect()
		silentConn = nil
	end
	if silentGyro then
		silentGyro:Destroy()
		silentGyro = nil
	end
end

startSilent()

--================ Aim loop ================
local function startAim()
	if aimConn then return end
	aimConn = RunService.RenderStepped:Connect(function(dt)
		if not State.AimEnabled then return end
		-- silent mode: hooks handle everything, camera untouched
		if State.AimMode ~= "camera" then return end

		local rangeMode = State.AimCameraMode == "range"

		-- both modes activate on RMB hold (ПКМ)
		if not aimRmbHeld then
			aimTarget = nil
			return
		end

		-- find or keep target
		if rangeMode then
			-- sticky: never release a living target (ignores FOV and walls)
			if not aimTarget or not isValidTarget(aimTarget) then
				aimTarget = getClosestPlayerToMouse(true)
			end
		else
			if not isTargetStillValid() then
				aimTarget = getClosestPlayerToMouse()
			end
		end
		if not aimTarget or not aimTarget.Character then return end

		local part = getTargetPart(aimTarget.Character)
		local cam = Workspace.CurrentCamera
		if not part or not cam then return end

		-- velocity prediction
		local targetPos = part.Position
		if State.AimPrediction > 0 then
			local hrp = aimTarget.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				targetPos = targetPos + (hrp.AssemblyLinearVelocity * State.AimPrediction * 0.001)
			end
		end

		-- deadzone check (standard only; range mode always snaps)
		if not rangeMode then
			local sp, onScreen = cam:WorldToViewportPoint(targetPos)
			if not onScreen then return end
			local vp = cam.ViewportSize
			local center = Vector2.new(vp.X / 2, vp.Y / 2)
			local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
			if screenDist <= State.AimDeadzone then return end
		end

		local currentCF = cam.CFrame
		local targetCF = CFrame.lookAt(currentCF.Position, targetPos)
		if rangeMode then
			-- instant lock: hard snap every frame, no smoothing
			if (targetPos - currentCF.Position).Magnitude > 0.5 then
				cam.CFrame = targetCF
			end
		else
			-- smoothing: 1 = instant, 10 = very slow
			local alpha = 1 - math.exp(-dt * (11 - State.AimSmoothing))
			alpha = math.clamp(alpha, 0.001, 1)
			cam.CFrame = currentCF:Lerp(targetCF, alpha)
		end
	end)
end

local function stopAim()
	if aimConn then
		aimConn:Disconnect()
		aimConn = nil
	end
	aimTarget = nil
end

local function updateAimFOV()
	if not aimFOVGui then return end
	aimFOVGui.Visible = State.AimEnabled
	if State.AimEnabled then
		local cam = Workspace.CurrentCamera
		if cam then
			local vp = cam.ViewportSize
			aimFOVGui.Position = UDim2.new(0, vp.X / 2 - State.AimFOV, 0, vp.Y / 2 - State.AimFOV)
			aimFOVGui.Size = UDim2.new(0, State.AimFOV * 2, 0, State.AimFOV * 2)
		end
	end
end

startAim()

--================ Feature sync (master toggles / config restore) ================
syncFeatures = function()
	if State.Fly then startFly() else stopFly() end
	if State.Noclip then startNoclip() else stopNoclip() end
	if State.God then startGod() else stopGod() end
	if State.Speed then applyStats() end
	if State.VehicleSpeed then startVehicleSpeed() else stopVehicleSpeed() end
	if State.Spinner then startSpinner() else stopSpinner() end
	if State.CursorTP then startCursorPreview() else stopCursorPreview() end
	if State.MaceTP then startMaceTP() else stopMaceTP() end
	if State.CycleTP then startCycleTP() else stopCycleTP() end
	if State.AutoClicker then startAutoClicker() else stopAutoClicker() end
	if State.ESPBox or State.ESPName or State.ESPHealth then startESP() else stopESP() end
	applyFullbright()
end

--================ UI: Main Window ================
-- ClickGUI "luxuryfarm" reskin (clickgui-luxuryfarm.svg): 760x452 window,
-- 44px icon rail + 180px module column + top strip (title crumbs + search)
-- + settings card. All module logic/callbacks/binds unchanged.
local function buildUI()

--================ Palette (from SVG) ================
local C = {
	Rail     = Color3.fromRGB(22, 22, 22),      -- #161616
	Side     = Color3.fromRGB(26, 26, 26),      -- #1A1A1A
	Top      = Color3.fromRGB(18, 18, 18),      -- #121212
	Card     = Color3.fromRGB(28, 28, 28),      -- #1C1C1C
	Row      = Color3.fromRGB(36, 36, 36),      -- #242424
	RowHover = Color3.fromRGB(46, 46, 46),
	Input    = Color3.fromRGB(32, 32, 32),      -- #202020
	Accent   = Color3.fromRGB(224, 71, 71),     -- #E04747
	AccentD  = Color3.fromRGB(199, 62, 62),
	Text     = Color3.fromRGB(230, 230, 230),   -- #E6E6E6
	Sub      = Color3.fromRGB(138, 138, 138),   -- #8A8A8A
	Dim      = Color3.fromRGB(90, 90, 90),
	Off      = Color3.fromRGB(58, 58, 58),      -- #3A3A3A
	Line     = Color3.fromRGB(42, 42, 42),      -- #2A2A2A
	Knob     = Color3.fromRGB(255, 255, 255),
	Danger   = Color3.fromRGB(224, 71, 71),
	DangerBg = Color3.fromRGB(42, 28, 28),
}
local DOTS = {
	Color3.fromRGB(45, 212, 191),
	Color3.fromRGB(74, 222, 128),
	Color3.fromRGB(234, 179, 8),
	Color3.fromRGB(249, 115, 22),
	Color3.fromRGB(59, 130, 246),
	Color3.fromRGB(239, 68, 68),
	Color3.fromRGB(168, 85, 247),
	Color3.fromRGB(20, 184, 166),
}

--================ Guis ================
local gui = Instance.new("ScreenGui")
gui.Name = "RoboxHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = getGuiParent()

local aimGui = Instance.new("ScreenGui")
aimGui.Name = "RoboxAimFOV"
aimGui.ResetOnSpawn = false
aimGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
aimGui.IgnoreGuiInset = true
aimGui.Parent = getGuiParent()

aimFOVGui = Instance.new("Frame")
aimFOVGui.Name = "AimFOVCircle"
aimFOVGui.BackgroundTransparency = 1
aimFOVGui.Visible = false
aimFOVGui.ZIndex = 50
aimFOVGui.Parent = aimGui

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = C.Accent
fovStroke.Thickness = 1
fovStroke.Transparency = 0.4
fovStroke.Parent = aimFOVGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = aimFOVGui

RunService.RenderStepped:Connect(updateAimFOV)

-- Auto Clicker cursor label
local clickerGui = Instance.new("ScreenGui")
clickerGui.Name = "RoboxClicker"
clickerGui.ResetOnSpawn = false
clickerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
clickerGui.IgnoreGuiInset = true
clickerGui.Parent = getGuiParent()
local clickerLabel = Instance.new("TextLabel")
clickerLabel.Size = UDim2.new(0, 150, 0, 20)
clickerLabel.BackgroundTransparency = 1
clickerLabel.Text = "AutoClicker - ON"
clickerLabel.TextColor3 = Theme.Success
clickerLabel.Font = Enum.Font.GothamBold
clickerLabel.TextSize = 13
clickerLabel.TextStrokeTransparency = 0
clickerLabel.Visible = false
clickerLabel.ZIndex = 100
clickerLabel.Parent = clickerGui

RunService.RenderStepped:Connect(function()
	clickerLabel.Visible = State.AutoClicker
	if State.AutoClicker then
		local mouseLoc = UserInputService:GetMouseLocation()
		clickerLabel.Position = UDim2.new(0, mouseLoc.X + 16, 0, mouseLoc.Y + 14)
	end
end)

--================ Window skeleton (SVG 760x452) ================
local WIN_W, WIN_H = 760, 452
local RAIL_W, SIDE_W, TOP_H = 44, 180, 40

-- global window scale: 1.0 = raw SVG size (760x452). Scales everything
-- inside the window, text included. Drag math divides by it.
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

-- left rail (rounded left corners only, like SVG: main rect + square cover)
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

-- module column
local side = Instance.new("Frame")
side.Size = UDim2.new(0, SIDE_W, 1, 0)
side.Position = UDim2.new(0, RAIL_W, 0, 0)
side.BackgroundColor3 = C.Side
side.BorderSizePixel = 0
side.Parent = win

-- dividers (#2A2A2A, 1px)
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

--================ Rail: moon logo (crescent + sparkles, from SVG) ================
local logo = Instance.new("Frame")
logo.Size = UDim2.new(0, 24, 0, 24)
logo.Position = UDim2.new(0, 10, 0, 11)
logo.BackgroundTransparency = 1
logo.Parent = rail

local moonA = Instance.new("Frame")
moonA.Size = UDim2.new(0, 17, 0, 17)
moonA.Position = UDim2.new(0, 2, 0, 4)
moonA.BackgroundColor3 = C.Text
moonA.BorderSizePixel = 0
moonA.Parent = logo
corner(moonA, 9)
local moonB = Instance.new("Frame")
moonB.Size = UDim2.new(0, 14, 0, 14)
moonB.Position = UDim2.new(0, 8, 0, 1)
moonB.BackgroundColor3 = C.Rail
moonB.BorderSizePixel = 0
moonB.Parent = logo
corner(moonB, 7)
local function sparkle(x, y, s)
	local d = Instance.new("Frame")
	d.Size = UDim2.new(0, s, 0, s)
	d.Position = UDim2.new(0, x, 0, y)
	d.Rotation = 45
	d.BackgroundColor3 = C.Text
	d.BorderSizePixel = 0
	d.Parent = logo
	corner(d, 1)
end
sparkle(16, 2, 4)
sparkle(19, 9, 3)

--================ Top strip: red tick + crumbs + search ================
local titleTick = Instance.new("Frame")
titleTick.Size = UDim2.new(0, 3, 0, 16)
titleTick.Position = UDim2.new(0, 52, 0, 12)
titleTick.BackgroundColor3 = C.Accent
titleTick.BorderSizePixel = 0
titleTick.Parent = win
corner(titleTick, 2)

local crumbHolder = Instance.new("Frame")
crumbHolder.Size = UDim2.new(0, 0, 0, TOP_H)
crumbHolder.Position = UDim2.new(0, 58, 0, 0)
crumbHolder.AutomaticSize = Enum.AutomaticSize.X
crumbHolder.BackgroundTransparency = 1
crumbHolder.Parent = win
local crumbLayout = Instance.new("UIListLayout")
crumbLayout.FillDirection = Enum.FillDirection.Horizontal
crumbLayout.VerticalAlignment = Enum.VerticalAlignment.Center
crumbLayout.Padding = UDim.new(0, 6)
crumbLayout.SortOrder = Enum.SortOrder.LayoutOrder
crumbLayout.Parent = crumbHolder

local crumbOrder = 0
local function crumb(text, size, color, font)
	crumbOrder = crumbOrder + 1
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0, 0, 0, 20)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.Font = font
	l.LayoutOrder = crumbOrder
	l.Parent = crumbHolder
	return l
end

local titleLbl = crumb("", 18, C.Accent, Enum.Font.GothamBold)       -- category name
crumb("/", 11, C.Sub, Enum.Font.GothamMedium)
local crumbMod = crumb("", 13, C.Text, Enum.Font.GothamMedium)       -- module name

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
searchPad.PaddingRight = UDim.new(0, 8)
searchPad.Parent = searchBox

--================ Settings card (232,48 520x396) ================
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
cardTitle.TextColor3 = C.Text
cardTitle.Font = Enum.Font.GothamMedium
cardTitle.TextSize = 15
cardTitle.TextXAlignment = Enum.TextXAlignment.Left
cardTitle.Parent = card

local cardSwitch = nil        -- master switch instance (recreated per module)
local cardSwitchModule = nil  -- module owning it (to clear stale headSet)

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
cardPad.PaddingBottom = UDim.new(0, 8)
cardPad.Parent = cardHolder

--================ Side rows scroll ================
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
rowsLayout.Padding = UDim.new(0, 0)
rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowsLayout.Parent = rowsScroll

--================ Forward decls ================
local currentCat = nil
local currentModule = nil
local selectCategory
local applySearchFilter
local hoverModule = nil
local startBindListen
local buildSide

--================ Category icons (vector-style, built from primitives) ================
-- no image assets: icons are drawn with rings (UIStroke), lines and dots
local function makeIcon(kind)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0, 20, 0, 20)
	holder.BackgroundTransparency = 1
	local parts = {}
	local function fill(x, y, w, h, r, rot)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0, w, 0, h)
		f.Position = UDim2.new(0, x, 0, y)
		f.BackgroundColor3 = C.Sub
		f.BorderSizePixel = 0
		if rot then f.Rotation = rot end
		f.Parent = holder
		if r then corner(f, r) end
		table.insert(parts, {f = f})
	end
	local function ring(x, y, w, h, th, rad)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0, w, 0, h)
		f.Position = UDim2.new(0, x, 0, y)
		f.BackgroundTransparency = 1
		f.Parent = holder
		corner(f, rad or math.min(w, h) / 2)
		local s = Instance.new("UIStroke")
		s.Color = C.Sub
		s.Thickness = th or 1.5
		s.Parent = f
		table.insert(parts, {f = f, s = s})
	end
	if kind == "Main" then          -- globe
		ring(1, 1, 18, 18)
		fill(2, 9, 16, 2)
		fill(9, 2, 2, 16)
	elseif kind == "Visuals" then   -- eye
		ring(1, 4, 18, 12)
		fill(7, 7, 6, 6, 3)
	elseif kind == "Teleport" then  -- map pin
		ring(4, 1, 12, 12)
		fill(8, 5, 4, 4, 2)
		fill(8, 14, 4, 4, 1, 45)
	elseif kind == "Aim" then       -- crosshair
		ring(3, 3, 14, 14)
		fill(9, 0, 2, 4)
		fill(9, 16, 2, 4)
		fill(0, 9, 4, 2)
		fill(16, 9, 4, 2)
	elseif kind == "Misc" then      -- grid
		fill(2, 2, 7, 7, 1.5)
		fill(11, 2, 7, 7, 1.5)
		fill(2, 11, 7, 7, 1.5)
		fill(11, 11, 7, 7, 1.5)
	elseif kind == "Bot" then       -- robot
		ring(2, 6, 16, 12, 1.5, 3)
		fill(6, 10, 3, 3, 1.5)
		fill(11, 10, 3, 3, 1.5)
		fill(9, 2, 2, 4)
		fill(8, 0, 4, 4, 2)
	elseif kind == "Settings" then  -- gear
		fill(2, 9, 16, 2, 1)
		fill(2, 9, 16, 2, 1, 90)
		fill(2, 9, 16, 2, 1, 45)
		fill(2, 9, 16, 2, 1, 135)
		ring(6, 6, 8, 8)
	else                            -- fallback dot
		fill(6, 6, 8, 8, 2)
	end
	local icon = { holder = holder }
	function icon.set(color)
		for _, p in ipairs(parts) do
			if p.s then p.s.Color = color else p.f.BackgroundColor3 = color end
		end
	end
	return icon
end

--================ Small widgets ================
-- switch: 28x14, rx7; knob 10px white, 2px inset (SVG)
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

--================ Widget keybinds (middle-click any button/toggle to bind) ================
-- same rules as module chips: Esc = cancel, Delete/Backspace = unbind, any key = bind
local function listenForKey(bindId, action, renderFn)
	if renderFn then renderFn(true) end
	local conn
	local done = false
	conn = UserInputService.InputBegan:Connect(function(inp2)
		if inp2.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local kc = inp2.KeyCode
		if kc == Enum.KeyCode.Escape then
			-- cancel
		elseif kc == Enum.KeyCode.Delete or kc == Enum.KeyCode.Backspace then
			setBind(bindId, nil, action)
		else
			setBind(bindId, kc, action)
		end
		done = true
		conn:Disconnect()
		if renderFn then renderFn(false) end
	end)
	task.delay(5, function()
		if not done then
			if conn then conn:Disconnect() end
			if renderFn then renderFn(false) end
		end
	end)
end

local function attachMiniBind(host, keyLbl, bindId, action)
	local function renderK(listening)
		local kc = bindKeys[bindId]
		keyLbl.Text = listening and "..." or (kc and keyCodeName(kc) or "")
		keyLbl.TextColor3 = listening and C.Accent or C.Dim
	end
	-- restore saved bind (if the user didn't explicitly unbind it)
	local initial = nil
	if not unboundIds[bindId] and bindKeys[bindId] then initial = bindKeys[bindId] end
	setBind(bindId, initial, action)
	host.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			listenForKey(bindId, action, renderK)
		end
	end)
	renderK(false)
end

-- shared slider drag state (one global pair of connections)
local activeSliderUpdate = nil
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		activeSliderUpdate = nil
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if activeSliderUpdate and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		activeSliderUpdate(input)
	end
end)

-- slider (SVG): label 13px Sub top-left, value 13px Text top-right,
-- track 4px rx2 #3A3A3A, fill + 10px knob in Accent
local function sliderWidget(parent, name, min, max, suffix, get, set, fmt)
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

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 10, 0, 10)
	knob.Position = UDim2.new(1, -5, 0.5, -5)
	knob.BackgroundColor3 = C.Accent
	knob.BorderSizePixel = 0
	knob.Parent = fill
	corner(knob, 5)

	local function display(v)
		if fmt then return fmt(v) end
		return tostring(math.floor(v)) .. (suffix or "")
	end

	local function apply(rel, fire)
		rel = math.clamp(rel, 0, 1)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		local v = min + (max - min) * rel
		valueLabel.Text = display(v)
		if fire then set(v) end
	end

	local function update(input)
		local rel = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		apply(rel, true)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			activeSliderUpdate = update
			update(input)
		end
	end)

	apply((get() - min) / (max - min), false)
	return holder, valueLabel
end

-- toggle row (SVG): 10x10 rx3 swatch + 13px label (Text when on, Sub when off) + switch right
local function toggleWidget(parent, name, get, set, dotColor, bindId)
	local holder = rowFrame(parent, 32)

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 10, 0, 10)
	dot.Position = UDim2.new(0, 8, 0.5, -5)
	dot.BackgroundColor3 = dotColor or C.Accent
	dot.BorderSizePixel = 0
	dot.Parent = holder
	corner(dot, 3)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, bindId and -116 or -80, 1, 0)
	label.Position = UDim2.new(0, 24, 0, 0)
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
		attachMiniBind(holder, keyLbl, bindId, function()
			set(not (get() == true))
			render()
		end)
	end
	render()
	return holder
end

local function cycleWidget(parent, name, values, get, set)
	local holder = rowFrame(parent, 32)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -110, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = C.Text
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = holder

	local chip = Instance.new("TextButton")
	chip.Size = UDim2.new(0, 88, 0, 24)
	chip.Position = UDim2.new(1, -96, 0.5, -12)
	chip.BackgroundColor3 = C.Input
	chip.TextColor3 = C.Text
	chip.Font = Enum.Font.GothamBold
	chip.TextSize = 10
	chip.AutoButtonColor = false
	chip.BorderSizePixel = 0
	chip.Parent = holder
	corner(chip, 5)

	local function render()
		chip.Text = string.upper(tostring(get()))
	end
	chip.MouseButton1Click:Connect(function()
		local cur = get()
		local idx = 1
		for i, v in ipairs(values) do
			if v == cur then idx = i break end
		end
		idx = idx % #values + 1
		set(values[idx])
		render()
	end)
	chip.MouseEnter:Connect(function() tween(chip, 0.15, {BackgroundColor3 = C.Row}) end)
	chip.MouseLeave:Connect(function() tween(chip, 0.15, {BackgroundColor3 = C.Input}) end)
	render()
	return holder
end

local function buttonWidget(parent, name, cb, danger, bindId)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, 32)
	btn.Position = UDim2.new(0, 8, 0, 0)
	btn.BackgroundColor3 = danger and C.DangerBg or C.Row
	btn.Text = name
	btn.TextColor3 = danger and C.Danger or C.Text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Parent = parent
	corner(btn, 6)
	btn.MouseButton1Click:Connect(function() if cb then cb() end end)
	if bindId then
		local keyLbl = Instance.new("TextLabel")
		keyLbl.Size = UDim2.new(0, 40, 0, 16)
		keyLbl.Position = UDim2.new(1, -48, 0.5, -8)
		keyLbl.BackgroundTransparency = 1
		keyLbl.Font = Enum.Font.GothamBold
		keyLbl.TextSize = 9
		keyLbl.TextColor3 = C.Dim
		keyLbl.TextXAlignment = Enum.TextXAlignment.Right
		keyLbl.Text = ""
		keyLbl.Parent = btn
		attachMiniBind(btn, keyLbl, bindId, function() if cb then cb() end end)
		-- key label must not eat the click: shift text left a bit
		btn.TextXAlignment = Enum.TextXAlignment.Center
	end
	btn.MouseEnter:Connect(function()
		if danger then
			tween(btn, 0.15, {BackgroundColor3 = C.Danger, TextColor3 = Color3.fromRGB(255, 255, 255)})
		else
			tween(btn, 0.15, {BackgroundColor3 = C.RowHover})
		end
	end)
	btn.MouseLeave:Connect(function()
		if danger then
			tween(btn, 0.15, {BackgroundColor3 = C.DangerBg, TextColor3 = C.Danger})
		else
			tween(btn, 0.15, {BackgroundColor3 = C.Row})
		end
	end)
	return btn
end

local function textWidget(parent, label, placeholder)
	local holder = rowFrame(parent, 32)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 20, 1, 0)
	lbl.Position = UDim2.new(0, 8, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = C.Sub
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = holder

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -42, 0, 28)
	box.Position = UDim2.new(0, 30, 0.5, -14)
	box.BackgroundColor3 = C.Input
	box.Text = ""
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = C.Dim
	box.TextColor3 = C.Text
	box.Font = Enum.Font.GothamMedium
	box.TextSize = 12
	box.ClearTextOnFocus = false
	box.BorderSizePixel = 0
	box.Parent = holder
	corner(box, 5)
	local bp = Instance.new("UIPadding")
	bp.PaddingLeft = UDim.new(0, 8)
	bp.PaddingRight = UDim.new(0, 8)
	bp.Parent = box
	return holder, box
end

local function infoWidget(parent)
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
	lbl.Parent = parent
	return lbl
end

local function miniBtn(parent, text, x, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 28, 0, 20)
	b.Position = UDim2.new(1, x, 0.5, -10)
	b.BackgroundColor3 = C.Row
	b.Text = text
	b.TextColor3 = C.Sub
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 5)
	b.MouseButton1Click:Connect(cb)
	b.MouseEnter:Connect(function() tween(b, 0.12, {BackgroundColor3 = C.Accent, TextColor3 = Color3.fromRGB(255, 255, 255)}) end)
	b.MouseLeave:Connect(function() tween(b, 0.12, {BackgroundColor3 = C.Row, TextColor3 = C.Sub}) end)
	return b
end

--================ Categories / modules data ================
local categories = {}
local function addCategory(name)
	local c = {name = name, modules = {}}
	table.insert(categories, c)
	return c
end

local liveConns = {}
local playerListRefresh = nil

local function clearLive()
	for _, cn in ipairs(liveConns) do
		if cn then cn:Disconnect() end
	end
	liveConns = {}
end
local function live(conn)
	table.insert(liveConns, conn)
	return conn
end

local function addModule(cat, name, opts)
	opts = opts or {}
	local m = {
		name = name,
		bindId = opts.bindId,
		defaultKey = opts.key,
		settings = {},
		getMaster = opts.get,
		setMaster = opts.set,
	}

	if opts.get then
		if unboundIds[opts.bindId] then
			m.currentKey = nil
		elseif bindKeys[opts.bindId] then
			m.currentKey = bindKeys[opts.bindId]
		else
			m.currentKey = opts.key
		end
		m.doToggle = function()
			local v = not (m.getMaster() == true)
			m.setMaster(v)
			if m.rowSet then m.rowSet(v) end
			if m.headSet then m.headSet(v) end
		end
		setBind(opts.bindId, m.currentKey, m.doToggle)
		m.renderBind = function()
			if not m.rowBind then return end
			if m.listening then
				m.rowBind.Text = "..."
				m.rowBind.Visible = true
				m.rowBind.TextColor3 = C.Accent
			else
				local has = m.currentKey ~= nil
				m.rowBind.Text = has and keyCodeName(m.currentKey) or "BIND"
				m.rowBind.Visible = true
				m.rowBind.TextColor3 = has and C.Sub or C.Dim
			end
		end
		table.insert(arrayListEntries, {name = name, isSlider = false, getState = opts.get})
	end

	local dotIdx = 0
	function m.toggle(name2, get, set)
		dotIdx = dotIdx + 1
		local color = DOTS[((dotIdx - 1) % #DOTS) + 1]
		local bid = "tgl_" .. name .. "_" .. name2
		table.insert(m.settings, {build = function(parent) toggleWidget(parent, name2, get, set, color, bid) end})
		table.insert(arrayListEntries, {name = name2, isSlider = false, getState = get})
	end

	function m.slider(name2, min, max, suffix, get, set, depGet, fmt)
		local function display(v)
			if fmt then return fmt(v) end
			return tostring(math.floor(v)) .. (suffix or "")
		end
		table.insert(m.settings, {build = function(parent) sliderWidget(parent, name2, min, max, suffix, get, set, fmt) end})
		table.insert(arrayListEntries, {
			name = name2,
			isSlider = true,
			getValue = function() return display(get()) end,
			getState = depGet,
		})
	end

	function m.cycle(name2, values, get, set)
		table.insert(m.settings, {build = function(parent) cycleWidget(parent, name2, values, get, set) end})
	end

	function m.button(name2, cb, danger)
		local bid = "btn_" .. name .. "_" .. name2
		table.insert(m.settings, {build = function(parent) buttonWidget(parent, name2, cb, danger, bid) end})
	end

	function m.custom(fn)
		table.insert(m.settings, {build = fn})
	end

	function m.info(getText)
		table.insert(m.settings, {build = function(parent)
			local lbl = infoWidget(parent)
			lbl.Text = getText()
			live(RunService.RenderStepped:Connect(function()
				if lbl.Parent then lbl.Text = getText() end
			end))
		end})
	end

	table.insert(cat.modules, m)
	return m
end

--================ MAIN ================
local catMain = addCategory("Main")

local mFly = addModule(catMain, "Fly", {bindId = "fly", key = Enum.KeyCode.F,
	get = function() return State.Fly end,
	set = function(v) State.Fly = v if v then startFly() else stopFly() end configDirty = true end})
mFly.slider("Fly Speed", 10, 300, "", function() return State.FlySpeed end, function(v) State.FlySpeed = v configDirty = true end, function() return State.Fly end)
mFly.slider("Fly Boost", 1, 10, "x", function() return State.FlyBoost end, function(v) State.FlyBoost = v configDirty = true end, function() return State.Fly end)
mFly.cycle("Fly Mode", {"standard", "bypass"}, function() return State.FlyMode end, function(mode) State.FlyMode = mode configDirty = true if State.Fly then startFly() end end)

local mNoclip = addModule(catMain, "Noclip", {bindId = "noclip", key = Enum.KeyCode.N,
	get = function() return State.Noclip end,
	set = function(v) State.Noclip = v if v then startNoclip() else stopNoclip() end configDirty = true end})

local mGod = addModule(catMain, "God Mode", {bindId = "god", key = Enum.KeyCode.H,
	get = function() return State.God end,
	set = function(v) State.God = v if v then startGod() else stopGod() end configDirty = true end})

local mSpeed = addModule(catMain, "Speed Hack", {bindId = "speed", key = Enum.KeyCode.V,
	get = function() return State.Speed end,
	set = function(v) State.Speed = v applyStats() configDirty = true end})
mSpeed.slider("Walk Speed", 16, 500, "", function() return State.WalkSpeed end, function(v) State.WalkSpeed = v if State.Speed then applyStats() end configDirty = true end, function() return State.Speed end)
mSpeed.slider("Walk Boost", 1, 10, "x", function() return State.WalkBoost end, function(v) State.WalkBoost = v configDirty = true end, function() return State.Speed end)
mSpeed.cycle("Speed Mode", {"standard", "hard"}, function() return State.SpeedMode end, function(mode) State.SpeedMode = mode if State.Speed then applyStats() end configDirty = true end)

local mSpinner = addModule(catMain, "Spinner", {bindId = "spinner", key = Enum.KeyCode.B,
	get = function() return State.Spinner end,
	set = function(v) State.Spinner = v if v then startSpinner() else stopSpinner() end configDirty = true end})
mSpinner.slider("Spin Speed", 1, 100, "", function() return State.SpinnerSpeed end, function(v)
	State.SpinnerSpeed = v
	if State.Spinner and spinnerBV then spinnerBV.AngularVelocity = Vector3.new(0, State.SpinnerSpeed, 0) end
	configDirty = true
end, function() return State.Spinner end)
mSpinner.cycle("Spinner Mode", {"standard", "hard"}, function() return State.SpinnerMode end, function(mode) State.SpinnerMode = mode configDirty = true end)

local mPlayer = addModule(catMain, "Player")
mPlayer.slider("Jump Power", 50, 500, "", function() return State.JumpPower end, function(v) State.JumpPower = v applyStats() configDirty = true end)
mPlayer.slider("Gravity", 0, 400, "", function() return State.Gravity end, function(v) State.Gravity = v Workspace.Gravity = v configDirty = true end)

local mVehicle = addModule(catMain, "Vehicle", {bindId = "vehiclespeed", key = Enum.KeyCode.J,
	get = function() return State.VehicleSpeed end,
	set = function(v) State.VehicleSpeed = v if v then startVehicleSpeed() else stopVehicleSpeed() end configDirty = true end})
mVehicle.slider("Max Speed", 10, 500, "", function() return State.VehicleMaxSpeed end, function(v) State.VehicleMaxSpeed = v configDirty = true end, function() return State.VehicleSpeed end)

--================ VISUALS ================
local catVis = addCategory("Visuals")
local mESP = addModule(catVis, "ESP", {bindId = "esp",
	get = function() return State.ESPEnabled end,
	set = function(v) State.ESPEnabled = v if v then startESP() else stopESP() end configDirty = true end})
mESP.toggle("Box", function() return State.ESPBox end, function(v) State.ESPBox = v configDirty = true end)
mESP.toggle("Name", function() return State.ESPName end, function(v) State.ESPName = v configDirty = true end)
mESP.toggle("Health", function() return State.ESPHealth end, function(v) State.ESPHealth = v configDirty = true end)
mESP.slider("Max Distance", 100, 10000, " studs", function() return State.ESPMaxDist end, function(v) State.ESPMaxDist = v configDirty = true end)

local mFull = addModule(catVis, "Fullbright", {bindId = "fullbright",
	get = function() return State.Fullbright end,
	set = function(v) State.Fullbright = v applyFullbright() configDirty = true end})

local mList = addModule(catVis, "ArrayList", {bindId = "arraylist", key = Enum.KeyCode.L,
	get = function() return State.ArrayList end,
	set = function(v) State.ArrayList = v configDirty = true end})

--================ TELEPORT ================
local catTp = addCategory("Teleport")
local mCursor = addModule(catTp, "Cursor TP", {bindId = "cursortp", key = Enum.KeyCode.K,
	get = function() return State.CursorTP end,
	set = function(v) State.CursorTP = v if v then startCursorPreview() else stopCursorPreview() end configDirty = true end})

local mMace = addModule(catTp, "MaceTP", {bindId = "macetp", key = Enum.KeyCode.G,
	get = function() return State.MaceTP end,
	set = function(v) State.MaceTP = v if v then startMaceTP() else stopMaceTP() end configDirty = true end})
mMace.slider("TP Interval", 1, 5000, " ms", function() return State.MaceInterval * 1000 end, function(v)
	State.MaceInterval = math.max(0.001, v / 1000)
	configDirty = true
end, function() return State.MaceTP end)
mMace.custom(function(parent)
	local renders = {}
	local function axisRow(axisName, plusKey, minusKey)
		local holder = rowFrame(parent, 28)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, 14, 1, 0)
		lbl.Position = UDim2.new(0, 2, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = axisName
		lbl.TextColor3 = C.Accent
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = holder

		local val = Instance.new("TextLabel")
		val.Size = UDim2.new(0, 46, 1, 0)
		val.Position = UDim2.new(0, 20, 0, 0)
		val.BackgroundTransparency = 1
		val.TextColor3 = C.Sub
		val.Font = Enum.Font.GothamBold
		val.TextSize = 12
		val.TextXAlignment = Enum.TextXAlignment.Left
		val.Parent = holder

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -140, 1, 0)
		title.Position = UDim2.new(0, 70, 0, 0)
		title.BackgroundTransparency = 1
		title.TextColor3 = C.Dim
		title.Font = Enum.Font.Gotham
		title.TextSize = 11
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = axisName == "Y" and "height" or (axisName == "X" and "side" or "distance")
		title.Parent = holder

		local function cur()
			if axisName == "Y" then return State.MaceOffsetY
			elseif axisName == "X" then return State.MaceOffsetX
			else return State.MaceOffsetZ end
		end
		local function render() val.Text = string.format("%+.1f", cur()) end
		local function step(d)
			local v = math.clamp(cur() + d, -25, 25)
			if axisName == "Y" then State.MaceOffsetY = v
			elseif axisName == "X" then State.MaceOffsetX = v
			else State.MaceOffsetZ = v end
			configDirty = true
			render()
		end
		miniBtn(holder, "-", -64, function() step(-0.5) end)
		miniBtn(holder, "+", -32, function() step(0.5) end)

		local upId = "mace_" .. axisName .. "_up"
		local downId = "mace_" .. axisName .. "_down"
		local upKey = plusKey
		if unboundIds[upId] then upKey = nil elseif bindKeys[upId] then upKey = bindKeys[upId] end
		local downKey = minusKey
		if unboundIds[downId] then downKey = nil elseif bindKeys[downId] then downKey = bindKeys[downId] end
		setBind(upId, upKey, function() step(0.5) end)
		setBind(downId, downKey, function() step(-0.5) end)

		render()
		table.insert(renders, render)
	end
	axisRow("Y", Enum.KeyCode.Y, Enum.KeyCode.BackSlash)
	axisRow("X", Enum.KeyCode.X, Enum.KeyCode.Z)
	axisRow("Z", Enum.KeyCode.O, Enum.KeyCode.P)
	buttonWidget(parent, "Reset Offset", function()
		State.MaceOffsetX = 0
		State.MaceOffsetY = 0
		State.MaceOffsetZ = 3
		configDirty = true
		for _, r in ipairs(renders) do r() end
	end)
end)

-- Cycle TP (merged into Teleport)
local mCycle = addModule(catTp, "Cycle TP", {bindId = "cycletp", key = Enum.KeyCode.C,
	get = function() return State.CycleTP end,
	set = function(v) State.CycleTP = v if v then startCycleTP() else stopCycleTP() end configDirty = true end})
mCycle.slider("Cycle Interval", 10, 5000, " ms", function() return State.CycleInterval end, function(v) State.CycleInterval = v configDirty = true end, function() return State.CycleTP end)
mCycle.button("Add Marker Here", function() local r = getRoot() if r then addCycleMarker(r.Position) end end)
mCycle.button("Remove Last", function() removeLastCycleMarker() end)
mCycle.button("Clear Markers", function() clearCycleMarkers() end)
mCycle.info(function()
	return "Markers: " .. #cycleMarkers .. " | Index: " .. State.CycleIndex
end)
local mMarker = addModule(catTp, "Marker")
mMarker.button("Set Marker Here", function() local r = getRoot() if r then setMarker(r.Position) end end)
mMarker.button("Teleport to Marker", function() if State.MarkerPos then teleportTo(State.MarkerPos) end end)
mMarker.button("Clear Marker", function() clearMarker() end)
mMarker.info(function()
	return State.MarkerPos and ("Marker: " .. tostring(State.MarkerPos)) or "No marker set."
end)

local mCoords = addModule(catTp, "Coordinates")
mCoords.custom(function(parent)
	local _, xBox = textWidget(parent, "X", "0")
	local _, yBox = textWidget(parent, "Y", "0")
	local _, zBox = textWidget(parent, "Z", "0")
	xBox.Text = "0" yBox.Text = "0" zBox.Text = "0"
	buttonWidget(parent, "Teleport to Coords", function()
		teleportTo(Vector3.new(tonumber(xBox.Text) or 0, tonumber(yBox.Text) or 0, tonumber(zBox.Text) or 0))
	end)
	buttonWidget(parent, "Fill Current Position", function()
		local root = getRoot()
		if root then
			local p = root.Position
			xBox.Text = tostring(math.floor(p.X))
			yBox.Text = tostring(math.floor(p.Y))
			zBox.Text = tostring(math.floor(p.Z))
		end
	end)
end)

local mPlayers = addModule(catTp, "Players")
mPlayers.custom(function(parent)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 0, 210)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = C.Off
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = parent
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 4)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = scroll

	local buttons = {}
	local function refresh()
		if not scroll.Parent then
			playerListRefresh = nil
			return
		end
		for _, b in pairs(buttons) do
			if b and b.Parent then b:Destroy() end
		end
		buttons = {}
		local sorted = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then table.insert(sorted, p) end
		end
		table.sort(sorted, function(a, b) return a.Name:lower() < b.Name:lower() end)
		for i, p in ipairs(sorted) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 0, 30)
			btn.BackgroundColor3 = C.Row
			btn.Text = "  " .. p.Name
			btn.TextColor3 = C.Text
			btn.Font = Enum.Font.GothamMedium
			btn.TextSize = 12
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.AutoButtonColor = false
			btn.LayoutOrder = i
			btn.Parent = scroll
			corner(btn, 6)
			btn.MouseEnter:Connect(function() tween(btn, 0.12, {BackgroundColor3 = C.Accent}) end)
			btn.MouseLeave:Connect(function() tween(btn, 0.12, {BackgroundColor3 = C.Row}) end)
			btn.MouseButton1Click:Connect(function()
				local char = p.Character
				local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
				if hrp then teleportTo(hrp.Position + Vector3.new(0, 4, 0)) end
			end)
			buttons[p] = btn
		end
	end
	refresh()
	playerListRefresh = refresh
end)

--================ AIM ================
local catAim = addCategory("Aim")
local mAim = addModule(catAim, "Aimbot", {bindId = "aim", key = Enum.KeyCode.E,
	get = function() return State.AimEnabled end,
	set = function(v) State.AimEnabled = v configDirty = true end})
mAim.cycle("Aim Mode", {"silent", "camera"}, function() return State.AimMode end, function(mode) State.AimMode = mode configDirty = true end)
mAim.cycle("Camera Aim", {"standard", "range"}, function() return State.AimCameraMode end, function(mode) State.AimCameraMode = mode configDirty = true end)
mAim.cycle("Target Part", {"Head", "Torso", "HumanoidRootPart"}, function() return State.AimTargetPart end, function(part) State.AimTargetPart = part configDirty = true end)
mAim.toggle("Team Check", function() return State.AimTeamCheck end, function(v) State.AimTeamCheck = v configDirty = true end)
mAim.toggle("Visible Check", function() return State.AimVisibleCheck end, function(v) State.AimVisibleCheck = v configDirty = true end)
mAim.slider("FOV Radius", 20, 500, " px", function() return State.AimFOV end, function(v) State.AimFOV = v configDirty = true end, function() return State.AimEnabled end)
mAim.slider("Smoothing", 1, 10, "", function() return State.AimSmoothing end, function(v) State.AimSmoothing = v configDirty = true end, function() return State.AimEnabled end)
mAim.slider("Deadzone", 0, 50, " px", function() return State.AimDeadzone end, function(v) State.AimDeadzone = v configDirty = true end, function() return State.AimEnabled end)
mAim.slider("Prediction", 0, 100, " ms", function() return State.AimPrediction end, function(v) State.AimPrediction = v configDirty = true end, function() return State.AimEnabled end)

--================ MISC ================
local catMisc = addCategory("Misc")
local mClicker = addModule(catMisc, "Auto Clicker", {bindId = "autoclicker",
	get = function() return State.AutoClicker end,
	set = function(v) State.AutoClicker = v if v then startAutoClicker() else stopAutoClicker() end configDirty = true end})
mClicker.slider("Min CPS", 1, 50, " cps", function() return State.AutoClickerMin end, function(v) State.AutoClickerMin = v configDirty = true end, function() return State.AutoClicker end)
mClicker.slider("Max CPS", 1, 50, " cps", function() return State.AutoClickerMax end, function(v) State.AutoClickerMax = v configDirty = true end, function() return State.AutoClicker end)

local mInfJump = addModule(catMisc, "Inf Jump", {bindId = "infjump",
	get = function() return State.InfJump end,
	set = function(v) State.InfJump = v configDirty = true end})

local mAntiAFK = addModule(catMisc, "Anti-AFK", {bindId = "antiafk",
	get = function() return State.AntiAFK end,
	set = function(v) State.AntiAFK = v configDirty = true end})

--================ BOT ================
local catBot = addCategory("Bot")
local mRec = addModule(catBot, "Record", {bindId = "botrecord", key = Enum.KeyCode.U,
	get = function() return State.BotRecord end,
	set = function(v) State.BotRecord = v if v then startBotRecord() else stopBotRecord() end configDirty = true end})

local mPlay = addModule(catBot, "Play", {bindId = "botplay",
	get = function() return State.BotPlay end,
	set = function(v) State.BotPlay = v if v then startBotPlay() else stopBotPlay() end configDirty = true end})
mPlay.toggle("Loop", function() return State.BotLoop end, function(v) State.BotLoop = v configDirty = true end)
mPlay.slider("Speed", 1, 10, "x", function() return State.BotSpeed end, function(v) State.BotSpeed = v configDirty = true end, function() return State.BotPlay end)
mPlay.button("Clear Recording", function() clearBotRecording() end)
mPlay.info(function()
	local dur = 0
	if #botFrames > 0 then dur = botFrames[#botFrames].t end
	return "Frames: " .. #botFrames .. " | Duration: " .. string.format("%.1f", dur) .. "s | Clicks: " .. botClickCount
end)

--================ SETTINGS ================
local catSet = addCategory("Settings")
local mCfg = addModule(catSet, "Config")
mCfg.button("Save Config Now", function() saveConfig() end)
mCfg.button("Reload Config", function()
	loadConfig()
	syncFeatures()
	if currentCat then buildSide(currentCat) end
end)
mCfg.button("Reset Config to Defaults", function()
	for k, v in pairs(DEFAULTS) do State[k] = v end
	table.clear(bindKeys)
	table.clear(unboundIds)
	for id, conn in pairs(bindConns) do
		if conn then conn:Disconnect() bindConns[id] = nil end
	end
	for _, c in ipairs(categories) do
		for _, m in ipairs(c.modules) do
			if m.bindId and m.doToggle then
				m.currentKey = m.defaultKey
				setBind(m.bindId, m.defaultKey, m.doToggle)
			end
		end
	end
	syncFeatures()
	configDirty = true
	saveConfig()
	if currentCat then buildSide(currentCat) end
end, true)
mCfg.info(function()
	return "File: " .. CONFIG_FILE .. "\nBinds: click the key chip on a module row, then press a key. Esc = cancel, Delete/Backspace = unbind.\nMiddle-click any button or toggle in this card = bind a key to it."
end)

local mUnhook = addModule(catSet, "Unhook")
mUnhook.button("UNHOOK SCRIPT", function()
	State.Fly = false; stopFly()
	State.Noclip = false; stopNoclip()
	State.God = false; stopGod()
	State.Speed = false; applyStats()
	State.VehicleSpeed = false; stopVehicleSpeed()
	State.Spinner = false; stopSpinner()
	State.CursorTP = false; stopCursorPreview()
	State.MaceTP = false; stopMaceTP()
	State.CycleTP = false; stopCycleTP(); clearCycleMarkers()
	State.BotRecord = false; stopBotRecord()
	State.BotPlay = false; stopBotPlay()
	clearBotRecording()
	clearMarker()
	State.ESPBox = false; State.ESPName = false; State.ESPHealth = false
	stopESP()
	State.AutoClicker = false; stopAutoClicker()
	State.AimEnabled = false; stopAim(); stopSilent()
	State.Fullbright = false; applyFullbright()
	State.InfJump = false
	State.AntiAFK = false
	for id, conn in pairs(bindConns) do
		if conn then conn:Disconnect() bindConns[id] = nil end
	end
	Workspace.Gravity = 196.2
	local _, hum = getRoot()
	if hum then
		hum.WalkSpeed = 16
		hum.JumpPower = 50
		hum.UseJumpPower = true
		hum.PlatformStand = false
	end
	saveConfig()
	if espGui then espGui:Destroy() end
	if aimGui then aimGui:Destroy() end
	if aimFOVGui then aimFOVGui.Visible = false end
	if clickerGui then clickerGui:Destroy() end
	if cursorKeepConn then cursorKeepConn:Disconnect() cursorKeepConn = nil end
	gui:Destroy()
end, true)

local mAbout = addModule(catSet, "About")
mAbout.info(function()
	return "ROBOX HUB v11.1\nRightCtrl - show/hide UI\nMiddle-click button/toggle = bind key.\nConfig auto-saves every 2s when changed."
end)

--================ Rail buttons (32x32, step 40, red bar on selected) ================
for i, c in ipairs(categories) do
	local y = 54 + (i - 1) * 40

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
	btn.BackgroundColor3 = C.Row
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Parent = rail
	corner(btn, 6)

	local icon = makeIcon(c.name)
	icon.holder.Position = UDim2.new(0.5, -10, 0.5, -10)
	icon.holder.Parent = btn

	c.btn = btn
	c.bar = bar
	c.icon = icon

	btn.MouseEnter:Connect(function()
		if c ~= currentCat then icon.set(C.Text) end
	end)
	btn.MouseLeave:Connect(function()
		if c ~= currentCat then icon.set(C.Sub) end
	end)
	btn.MouseButton1Click:Connect(function() selectCategory(c) end)
end

--================ Side rows / content build ================
local function openModule(cat, m)
	clearLive()
	currentModule = m
	crumbMod.Text = m.name
	cardTitle.Text = m.name

	for _, m2 in ipairs(cat.modules) do
		local sel = (m2 == m)
		if m2.rowBar then m2.rowBar.Visible = sel end
		if m2.rowBg then m2.rowBg.BackgroundTransparency = sel and 0 or 1 end
		if m2.rowName then m2.rowName.TextColor3 = sel and C.Text or C.Sub end
		if m2.rowArrow then
			m2.rowArrow.Text = sel and "v" or ">"
			m2.rowArrow.TextColor3 = sel and C.Text or C.Dim
		end
	end

	for _, ch in ipairs(cardHolder:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end

	-- master switch in card header (recreated; stale headSet cleared)
	if cardSwitchModule then cardSwitchModule.headSet = nil cardSwitchModule = nil end
	if cardSwitch then cardSwitch:Destroy() cardSwitch = nil end
	if m.getMaster then
		local sw, setSw = makeSwitch(card)
		sw.Position = UDim2.new(0, 480, 0, 11)
		cardSwitch = sw
		cardSwitchModule = m
		m.headSet = setSw
		setSw(m.getMaster() == true)
		sw.MouseButton1Click:Connect(function() m.doToggle() end)
	else
		m.headSet = nil
	end

	if #m.settings == 0 then
		local none = Instance.new("TextLabel")
		none.Size = UDim2.new(1, -16, 0, 18)
		none.Position = UDim2.new(0, 8, 0, 0)
		none.BackgroundTransparency = 1
		none.Text = "Нет настроек"
		none.TextColor3 = C.Dim
		none.Font = Enum.Font.Gotham
		none.TextSize = 12
		none.TextXAlignment = Enum.TextXAlignment.Left
		none.Parent = cardHolder
	else
		for _, s in ipairs(m.settings) do
			s.build(cardHolder)
		end
	end
end

buildSide = function(cat)
	for _, ch in ipairs(rowsScroll:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end

	for _, m in ipairs(cat.modules) do
		-- row slot 180x32; selected bg 172x28 at (4,2) — SVG geometry
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Parent = rowsScroll
		m.row = row

		local rowBg = Instance.new("Frame")
		rowBg.Size = UDim2.new(0, 172, 0, 28)
		rowBg.Position = UDim2.new(0, 4, 0, 2)
		rowBg.BackgroundColor3 = C.Row
		rowBg.BackgroundTransparency = 1
		rowBg.BorderSizePixel = 0
		rowBg.Parent = row
		corner(rowBg, 6)
		m.rowBg = rowBg

		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, 2, 0, 16)
		bar.Position = UDim2.new(0, 0, 0.5, -8)
		bar.BackgroundColor3 = C.Accent
		bar.BorderSizePixel = 0
		bar.Visible = false
		bar.Parent = rowBg
		m.rowBar = bar

		-- transparent click zone (name area) — opens settings card
		local rowClick = Instance.new("TextButton")
		rowClick.Size = UDim2.new(1, -10, 1, 0)
		rowClick.Position = UDim2.new(0, 10, 0, 0)
		rowClick.BackgroundTransparency = 1
		rowClick.Text = ""
		rowClick.AutoButtonColor = false
		rowClick.Parent = rowBg
		m.rowClick = rowClick

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, 0, 1, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = m.name
		nameLbl.TextColor3 = C.Sub
		nameLbl.Font = Enum.Font.GothamMedium
		nameLbl.TextSize = 13
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Parent = rowClick
		m.rowName = nameLbl

		-- chevron: has settings (">" closed / "v" open)
		local chev = Instance.new("TextLabel")
		chev.Size = UDim2.new(0, 12, 0, 12)
		chev.Position = UDim2.new(0, 94, 0.5, -6)
		chev.BackgroundTransparency = 1
		chev.Text = ">"
		chev.TextColor3 = C.Dim
		chev.Font = Enum.Font.GothamBold
		chev.TextSize = 12
		chev.Visible = #m.settings > 0
		chev.Parent = rowBg
		m.rowArrow = chev

		-- master switch (28x14)
		if m.getMaster then
			local sw, setSw = makeSwitch(rowBg)
			sw.Position = UDim2.new(0, 120, 0.5, -7)
			m.rowSet = setSw
			setSw(m.getMaster() == true)
			sw.MouseButton1Click:Connect(function() m.doToggle() end)
		else
			m.rowSet = nil
		end

		-- bind chip (right edge slot of the SVG info icon)
		local bindLbl = Instance.new("TextButton")
		bindLbl.Size = UDim2.new(0, 20, 0, 16)
		bindLbl.Position = UDim2.new(0, 150, 0.5, -8)
		bindLbl.BackgroundColor3 = C.Input
		bindLbl.TextColor3 = C.Dim
		bindLbl.Font = Enum.Font.GothamBold
		bindLbl.TextSize = 8
		bindLbl.AutoButtonColor = false
		bindLbl.BorderSizePixel = 0
		bindLbl.ClipsDescendants = true
		bindLbl.Parent = rowBg
		corner(bindLbl, 4)
		m.rowBind = bindLbl
		if m.bindId and m.doToggle then
			bindLbl.MouseButton1Click:Connect(function() startBindListen(m) end)
		else
			bindLbl.Visible = false
		end
		if m.renderBind then m.renderBind() end

		rowClick.MouseButton1Click:Connect(function() openModule(cat, m) end)
		row.MouseEnter:Connect(function() hoverModule = m end)
		row.MouseLeave:Connect(function() if hoverModule == m then hoverModule = nil end end)
	end

	applySearchFilter()

	local target = cat.modules[1]
	for _, m in ipairs(cat.modules) do
		if m == currentModule then target = m break end
	end
	if target then openModule(cat, target) end
end

applySearchFilter = function()
	local q = searchBox.Text:lower()
	if currentCat then
		for _, m in ipairs(currentCat.modules) do
			if m.row then
				m.row.Visible = (q == "") or (m.name:lower():find(q, 1, true) ~= nil)
			end
		end
	end
end

selectCategory = function(cat)
	currentCat = cat
	titleLbl.Text = cat.name
	for _, c in ipairs(categories) do
		local active = (c == cat)
		c.bar.Visible = active
		c.btn.BackgroundTransparency = active and 0 or 1
		c.icon.set(active and C.Text or C.Sub)
	end
	buildSide(cat)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(applySearchFilter)

Players.PlayerAdded:Connect(function()
	task.wait(0.2)
	if playerListRefresh then playerListRefresh() end
end)
Players.PlayerRemoving:Connect(function()
	task.wait(0.2)
	if playerListRefresh then playerListRefresh() end
end)

--================ Bind listening (click chip or middle-click row) ================
startBindListen = function(m)
	if not m.bindId or not m.doToggle or m.listening then return end
	m.listening = true
	m.renderBind()
	local conn
	local done = false
	conn = UserInputService.InputBegan:Connect(function(inp2, gpe2)
		-- NOTE: NO gpe filter while listening — a bind editor must capture keys
		-- the game already processes (Z, Esc, WASD...), otherwise they can't bind
		if inp2.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local kc = inp2.KeyCode
		if kc == Enum.KeyCode.Escape then
			-- cancel: keep current bind
		elseif kc == Enum.KeyCode.Delete or kc == Enum.KeyCode.Backspace then
			m.currentKey = nil
			setBind(m.bindId, nil, m.doToggle) -- unbind
		else
			m.currentKey = kc
			setBind(m.bindId, kc, m.doToggle)
		end
		done = true
		m.listening = false
		m.renderBind()
		conn:Disconnect()
	end)
	task.delay(5, function()
		if not done and m.listening then
			m.listening = false
			m.renderBind()
			if conn then conn:Disconnect() end
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton3 then
		local m = hoverModule
		if m and m.bindId and m.doToggle then
			startBindListen(m)
		end
	end
end)

--================ UI visibility ================
setUIVisible = function(visible)
	gui.Enabled = visible
	if visible then
		savedMouseBehavior = UserInputService.MouseBehavior
		savedMouseIconEnabled = UserInputService.MouseIconEnabled
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		if not cursorKeepConn then
			cursorKeepConn = RunService.RenderStepped:Connect(function()
				if gui.Enabled then
					UserInputService.MouseBehavior = Enum.MouseBehavior.Default
					UserInputService.MouseIconEnabled = true
				end
			end)
		end
	else
		if cursorKeepConn then cursorKeepConn:Disconnect() cursorKeepConn = nil end
		if savedMouseBehavior then UserInputService.MouseBehavior = savedMouseBehavior end
		if savedMouseIconEnabled ~= nil then UserInputService.MouseIconEnabled = savedMouseIconEnabled end
	end
end

--================ Draggable (top strip, left of search) ================
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
		setUIVisible(not gui.Enabled)
	end
end)

--================ Init ================
applyStats()
applyFullbright()
selectCategory(categories[1])

-- Session restore: re-start features that were ON in saved config.
task.spawn(function()
	local char = player.Character
	if not char or not char:FindFirstChildOfClass("Humanoid") then
		char = player.CharacterAdded:Wait()
	end
	task.wait(0.5)
	if State.God then startGod() end
	if State.Noclip then startNoclip() end
	if State.Spinner then startSpinner() end
	if State.Fly then startFly() end
	if State.CursorTP then startCursorPreview() end
	if State.MaceTP then startMaceTP() end
	if State.VehicleSpeed then startVehicleSpeed() end
	if State.AutoClicker then startAutoClicker() end
	if State.CycleTP then startCycleTP() end
end)

--================ ArrayList overlay ================
local alGui = Instance.new("ScreenGui")
alGui.Name = "RoboxArrayList"
alGui.ResetOnSpawn = false
alGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
alGui.IgnoreGuiInset = true
alGui.Parent = getGuiParent()

local alHolder = Instance.new("Frame")
alHolder.AnchorPoint = Vector2.new(0, 1)
alHolder.Position = UDim2.new(0, 5, 1, -5)
alHolder.AutomaticSize = Enum.AutomaticSize.X
alHolder.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
alHolder.BackgroundTransparency = 1
alHolder.BorderSizePixel = 0
alHolder.Visible = false
alHolder.Parent = alGui

local alLayout = Instance.new("UIListLayout")
alLayout.FillDirection = Enum.FillDirection.Horizontal
alLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
alLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
alLayout.SortOrder = Enum.SortOrder.LayoutOrder
alLayout.Padding = UDim.new(0, 4)
alLayout.Parent = alHolder

local alRects = {}

local function getALRect(i)
	if alRects[i] then return alRects[i] end
	local rect = Instance.new("Frame")
	rect.AutomaticSize = Enum.AutomaticSize.XY
	rect.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	rect.BackgroundTransparency = 1 - (195 / 255)
	rect.BorderSizePixel = 0
	rect.LayoutOrder = i
	rect.Visible = false
	rect.Parent = alHolder
	corner(rect, RADIUS)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.Parent = rect

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 13.25
	lbl.TextStrokeTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.AutomaticSize = Enum.AutomaticSize.XY
	lbl.Parent = rect

	alRects[i] = {rect = rect, label = lbl}
	return alRects[i]
end

RunService.RenderStepped:Connect(function()
	if not State.ArrayList then
		alHolder.Visible = false
		return
	end
	local count = 0
	for _, entry in ipairs(arrayListEntries) do
		if entry.getState and entry.getState() then
			count = count + 1
			local r = getALRect(count)
			if entry.isSlider then
				r.label.Text = entry.name .. " -> [" .. entry.getValue() .. "]"
			else
				r.label.Text = entry.name
			end
			r.label.TextColor3 = Theme.Accent
			r.rect.Visible = true
		end
	end
	for i = count + 1, #alRects do
		alRects[i].rect.Visible = false
	end
	alHolder.Visible = count > 0
end)

end -- buildUI

local okUI, errUI = xpcall(buildUI, debug.traceback)
if not okUI then
	warn("[ROBOX HUB] UI build FAILED: " .. tostring(errUI))
else
	local mainGui = getGuiParent():FindFirstChild("RoboxHub")
	print("[ROBOX HUB] UI parented to: " .. tostring(mainGui and mainGui:GetFullName() or "?") .. " | toggle key: RightCtrl")
end

print("[ROBOX HUB v11.1] Loaded — full category set, clickable keybind chips, ESP master toggle, Fullbright/InfJump/Anti-AFK, Settings category. Built for Xeno.")
