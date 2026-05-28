-- [[ TITANS HUB - CONSOLIDATED SINGLE FILE SCRIPT ]]
-- Target: Attack on Titan Revolution (AOTR)
-- Features: Custom Draggable UI, Always Crit, Auto Heal, Anti-AFK, Hitbox Extender, Auto Refill, Auto Dodge, Nape Farm

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local VirtualUser  = game:GetService("VirtualUser")
local player       = Players.LocalPlayer

-- =============================================
-- [1] CONFIGURATION
-- =============================================
local Config = {
	FarmActive    = false,
	FlyHeight     = 50,
	HeightOptions = {30, 50, 80, 120},
	HeightIndex   = 2,

	WallEnabled   = true,

	CritEnabled   = true,       -- Always Crit (metatable hook)

	HealEnabled   = true,       -- Tự động dùng Bandage khi máu thấp
	HealThreshold = 50,         -- % máu để kích hoạt

	AntiAFKEnabled = true,      -- Chống AFK

	HitboxEnabled = true,       -- Mở rộng hitbox của Titan (Nape)
	HitboxSize    = 25,         -- Kích thước mở rộng (studs)

	RefillEnabled = true,       -- Tự động nạp Gas / Blade
	GasMin        = 20,         -- % Gas tối thiểu
	BladeMin      = 1,          -- Số lưỡi kiếm tối thiểu

	DodgeEnabled  = true,       -- Tự động né đòn titan

	_sessionToken = 0,
}

function Config:NewSession()
	self._sessionToken = self._sessionToken + 1
	return self._sessionToken
end

function Config:IsValidSession(token)
	return token == self._sessionToken
end

-- =============================================
-- [2] CRITICAL HOOK MODULE
-- =============================================
local CritHook = {}
local _hooked   = false
local _oldNamecall = nil

function CritHook.Start()
	if _hooked then return end
	if not pcall(function() return getrawmetatable(game) end) then
		warn("[CritHook] Executor không hỗ trợ getrawmetatable – bỏ qua.")
		return
	end

	local mt = getrawmetatable(game)
	_oldNamecall = mt.__namecall

	setreadonly(mt, false)

	mt.__namecall = newcclosure(function(self, ...)
		local method = getnamecallmethod()
		local args   = { ... }

		if Config.CritEnabled and method == "FireServer" then
			for _, v in ipairs(args) do
				if type(v) == "table" then
					v["Crit"]           = true
					v["CritMultiplier"] = 2.5
					if type(v["Damage"]) == "number" then
						v["Damage"] = v["Damage"] * 1.2
					end
				end
			end
		end

		if Config.CritEnabled and method == "InvokeServer" then
			for _, v in ipairs(args) do
				if type(v) == "table" then
					v["Crit"]           = true
					v["CritMultiplier"] = 2.5
				end
			end
		end

		return _oldNamecall(self, unpack(args))
	end)

	setreadonly(mt, true)
	_hooked = true
	print("[CritHook] ✅ Critical Hook: ACTIVE")
end

function CritHook.Stop()
	if not _hooked or not _oldNamecall then return end

	local mt = getrawmetatable(game)
	setreadonly(mt, false)
	mt.__namecall = _oldNamecall
	setreadonly(mt, true)

	_hooked = false
	_oldNamecall = nil
	print("[CritHook] 🔴 Critical Hook: DISABLED")
end

-- =============================================
-- [3] AUTO HEAL MODULE
-- =============================================
local AutoHeal = {}
local HEAL_ITEM_NAMES = {
	"Bandage", "bandage",
	"FirstAid", "firstaid", "first_aid",
	"HealKit", "healkit",
	"MedKit",  "medkit",
}
local _healing  = false
local _healConn = nil

local function findHealItem()
	local char = player.Character
	if not char then return nil end

	for _, name in ipairs(HEAL_ITEM_NAMES) do
		local item = player.Backpack:FindFirstChild(name)
			or char:FindFirstChild(name)
		if item then return item end
	end

	for _, tool in ipairs(player.Backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local lower = tool.Name:lower()
			for _, kw in ipairs({"bandage","heal","med","aid","first"}) do
				if lower:find(kw) then return tool end
			end
		end
	end
	return nil
end

local function getHPPercent()
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.MaxHealth <= 0 then return 100 end
	return (hum.Health / hum.MaxHealth) * 100
end

local function tryHeal()
	if _healing then return end
	if not Config.HealEnabled then return end

	local hpPct = getHPPercent()
	if hpPct > Config.HealThreshold then return end

	local item = findHealItem()
	if not item then return end

	_healing = true
	pcall(function()
		local char = player.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum and item then
			hum:EquipTool(item)
			task.wait(0.25)
			if item.Activate then
				item:Activate()
			end
			print(string.format("[AutoHeal] 💊 HP thấp (%.0f%%) – Dùng %s", hpPct, item.Name))
			task.wait(3.0)
		end
	end)
	_healing = false
end

function AutoHeal.Start()
	if _healConn then _healConn:Disconnect() end
	_healConn = RunService.Heartbeat:Connect(function()
		tryHeal()
	end)
	print("[AutoHeal] ✅ Auto Heal: ACTIVE")
end

function AutoHeal.Stop()
	if _healConn then
		_healConn:Disconnect()
		_healConn = nil
	end
	print("[AutoHeal] 🔴 Auto Heal: DISABLED")
end

-- =============================================
-- [4] ANTI-AFK MODULE
-- =============================================
local AntiAFK = {}
local _afkRunning = false
local _afkThread  = nil
local _afkJitterConn = nil

local function pingVirtualUser()
	pcall(function()
		VirtualUser:SetKeyboardEnabled(true)
		VirtualUser:SetMouseEnabled(true)
		VirtualUser:Button1Down(Vector2.new(0, 0), CFrame.new())
		task.wait(0.05)
		VirtualUser:Button1Up(Vector2.new(0, 0), CFrame.new())
	end)
end

local function doJitter()
	pcall(function()
		local char = player.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.MoveDirection.Magnitude == 0 then
			hum:Move(Vector3.new(0.01, 0, 0), false)
			task.wait(0.1)
			hum:Move(Vector3.new(0, 0, 0), false)
		end
	end)
end

local function afkLoop()
	_afkRunning = true
	while _afkRunning and Config.AntiAFKEnabled do
		pingVirtualUser()
		task.wait(120)
	end
end

function AntiAFK.Start()
	if _afkThread then task.cancel(_afkThread) end
	if _afkJitterConn then task.cancel(_afkJitterConn) end

	_afkRunning = true
	_afkJitterConn = task.delay(60, function()
		while _afkRunning do
			doJitter()
			task.wait(60)
		end
	end)

	_afkThread = task.spawn(afkLoop)
	print("[AntiAFK] ✅ Anti-AFK: ACTIVE")
end

function AntiAFK.Stop()
	_afkRunning = false
	if _afkThread then
		task.cancel(_afkThread)
		_afkThread = nil
	end
	if _afkJitterConn then
		task.cancel(_afkJitterConn)
		_afkJitterConn = nil
	end
	print("[AntiAFK] 🔴 Anti-AFK: DISABLED")
end

-- =============================================
-- [5] HITBOX EXTENDER MODULE
-- =============================================
local HitboxExtender = {}
local _originalSizes = {}
local _originalTrans = {}
local _originalCol   = {}
local _hitboxConn    = nil
local _hitboxActive  = false

local function expandNape(nape)
	if not nape or not nape:IsA("BasePart") then return end
	if not _originalSizes[nape] then
		_originalSizes[nape] = nape.Size
		_originalTrans[nape] = nape.Transparency
		_originalCol[nape]   = nape.CanCollide
	end
	local size = Config.HitboxSize or 25
	nape.Size = Vector3.new(size, size, size)
	nape.Transparency = 0.85
	nape.CanCollide = false
end

local function restoreNape(nape)
	if nape and nape.Parent then
		pcall(function()
			if _originalSizes[nape] then nape.Size = _originalSizes[nape] end
			if _originalTrans[nape] then nape.Transparency = _originalTrans[nape] end
			if _originalCol[nape]   then nape.CanCollide = _originalCol[nape] end
		end)
	end
	_originalSizes[nape] = nil
	_originalTrans[nape] = nil
	_originalCol[nape]   = nil
end

local function expandAllNapes()
	for _, v in ipairs(workspace:GetDescendants()) do
		if v.Name == "Nape" and v:IsA("BasePart") then
			expandNape(v)
		end
	end
end

local function restoreAllNapes()
	for nape, _ in pairs(_originalSizes) do
		restoreNape(nape)
	end
	_originalSizes = {}
	_originalTrans = {}
	_originalCol   = {}
end

function HitboxExtender.Start()
	if _hitboxActive then return end
	_hitboxActive = true

	pcall(expandAllNapes)

	_hitboxConn = workspace.DescendantAdded:Connect(function(desc)
		if not _hitboxActive or not Config.HitboxEnabled then return end
		if desc.Name == "Nape" and desc:IsA("BasePart") then
			task.wait(0.1)
			pcall(function() expandNape(desc) end)
		end
	end)

	task.spawn(function()
		while _hitboxActive and Config.HitboxEnabled do
			pcall(expandAllNapes)
			task.wait(2.5)
		end
	end)

	print("[HitboxExtender] ✅ Hitbox Extender: ACTIVE")
end

function HitboxExtender.Stop()
	_hitboxActive = false
	if _hitboxConn then
		_hitboxConn:Disconnect()
		_hitboxConn = nil
	end
	pcall(restoreAllNapes)
	print("[HitboxExtender] 🔴 Hitbox Extender: DISABLED")
end

function HitboxExtender.SetSize(size)
	Config.HitboxSize = size
	if _hitboxActive and Config.HitboxEnabled then
		pcall(expandAllNapes)
	end
end

-- =============================================
-- [6] AUTO REFILL MODULE
-- =============================================
local AutoRefill = {}
local _refillConn = nil
local _lastRefill = 0
local REFILL_COOLDOWN = 8

local function readStat(statNames)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		for _, name in ipairs(statNames) do
			local v = ls:FindFirstChild(name)
			if v then return tonumber(v.Value) end
		end
	end
	local pd = player:FindFirstChild("PlayerData")
		or player:FindFirstChild("Data")
		or player:FindFirstChild("Stats")
	if pd then
		for _, name in ipairs(statNames) do
			local v = pd:FindFirstChild(name)
			if v then return tonumber(v.Value) end
		end
	end
	local char = player.Character
	if char then
		for _, name in ipairs(statNames) do
			local val = char:GetAttribute(name)
			if val then return tonumber(val) end
		end
	end
	return nil
end

local function getGas() return readStat({"Gas", "GasAmount", "Fuel", "gas", "GasTank"}) end
local function getBlades() return readStat({"Blade", "BladeCount", "Blades", "blades", "SwordCount", "Swords"}) end

local function triggerNearestPrompt(keywords)
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local bestPrompt = nil
	local bestDist   = 30

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			local nameLower = obj.Name:lower()
			local matched   = false
			for _, kw in ipairs(keywords) do
				if nameLower:find(kw) then
					matched = true
					break
				end
			end
			if matched then
				local part = obj.Parent
				if part and part:IsA("BasePart") then
					local dist = (hrp.Position - part.Position).Magnitude
					if dist < bestDist then
						bestDist   = dist
						bestPrompt = obj
					end
				end
			end
		end
	end

	if bestPrompt then
		pcall(function()
			local part = bestPrompt.Parent
			if part and part:IsA("BasePart") then
				if (hrp.Position - part.Position).Magnitude > bestPrompt.MaxActivationDistance then
					hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 3))
					task.wait(0.3)
				end
			end

			local firePrompt = game:GetService("ProximityPromptService")
			firePrompt:PromptTriggered(bestPrompt, player)

			local remote = bestPrompt.Parent:FindFirstChildOfClass("RemoteEvent")
				or bestPrompt.Parent.Parent:FindFirstChildOfClass("RemoteEvent")
			if remote then
				pcall(function() remote:FireServer("Refill") end)
			end
		end)
		return true
	end
	return false
end

local function checkAndRefill()
	if not Config.RefillEnabled then return end

	local now = os.clock()
	if (now - _lastRefill) < REFILL_COOLDOWN then return end

	local gas    = getGas()
	local blades = getBlades()
	local needRefill = false

	if gas and gas <= Config.GasMin then
		needRefill = true
	end
	if blades and blades <= Config.BladeMin then
		needRefill = true
	end

	if gas == nil and blades == nil then
		if (now - _lastRefill) >= 60 then
			needRefill = true
		end
	end

	if needRefill then
		local ok = triggerNearestPrompt({
			"refill", "reload", "supply", "gas", "blade",
			"interact", "replace", "restock"
		})
		if ok then
			_lastRefill = now
			print("[AutoRefill] ✅ Refill triggered")
		end
	end
end

function AutoRefill.Start()
	if _refillConn then _refillConn:Disconnect() end
	_lastRefill = 0
	_refillConn = RunService.Heartbeat:Connect(function()
		checkAndRefill()
	end)
	print("[AutoRefill] ✅ Auto Refill: ACTIVE")
end

function AutoRefill.Stop()
	if _refillConn then
		_refillConn:Disconnect()
		_refillConn = nil
	end
	print("[AutoRefill] 🔴 Auto Refill: DISABLED")
end

-- =============================================
-- [7] AUTO DODGE MODULE
-- =============================================
local AutoDodge = {}
local DANGER_RADIUS   = 18
local DODGE_DISTANCE  = 30
local DODGE_COOLDOWN  = 1.5
local _dodgeThread     = nil
local _lastDodge = 0
local _dodging  = false

local ATTACK_ANIM_KEYWORDS = {
	"attack", "swing", "strike", "hit",
	"punch", "slap", "grab", "stomp",
	"smash", "bite"
}

local function isTitanAttacking(titanModel)
	local animator = titanModel:FindFirstChildOfClass("Animator")
		or (titanModel:FindFirstChildOfClass("Humanoid")
			and titanModel:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator"))
	if not animator then return false end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local animName = track.Name:lower()
		for _, kw in ipairs(ATTACK_ANIM_KEYWORDS) do
			if animName:find(kw) then
				return true
			end
		end
	end
	return false
end

local function findThreat()
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil, nil end

	local playerPos = hrp.Position
	local bestModel = nil
	local bestDist  = DANGER_RADIUS

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "Nape" and obj:IsA("BasePart") then
			local dist = (playerPos - obj.Position).Magnitude
			if dist < bestDist then
				local model = obj:FindFirstAncestorOfClass("Model")
				if model and model ~= char then
					if isTitanAttacking(model) then
						bestDist  = dist
						bestModel = model
					end
				end
			end
		end
	end
	return bestModel, bestDist
end

local function performDodge()
	if _dodging then return end
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	_dodging = true
	pcall(function()
		local threat, _ = findThreat()
		local dodgeDir
		if threat then
			local titanPos = threat:FindFirstChild("HumanoidRootPart") and
				threat.HumanoidRootPart.Position or hrp.Position
			dodgeDir = (hrp.Position - titanPos).Unit
		else
			dodgeDir = hrp.CFrame.RightVector
		end

		local oldBV = hrp:FindFirstChild("_DodgeBV")
		if oldBV then oldBV:Destroy() end

		local bv = Instance.new("BodyVelocity")
		bv.Name      = "_DodgeBV"
		bv.Velocity  = (dodgeDir + Vector3.new(0, 0.5, 0)).Unit * DODGE_DISTANCE * 8
		bv.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
		bv.P         = 1e4
		bv.Parent    = hrp

		task.wait(0.25)
		if bv and bv.Parent then bv:Destroy() end
	end)
	task.wait(DODGE_COOLDOWN)
	_dodging = false
end

local function dodgeLoop()
	while true do
		if Config.DodgeEnabled then
			local now = os.clock()
			if (now - _lastDodge) >= DODGE_COOLDOWN then
				local threatModel, _ = findThreat()
				if threatModel then
					_lastDodge = now
					task.spawn(performDodge)
				end
			end
		end
		task.wait(0.1)
	end
end

function AutoDodge.Start()
	if _dodgeThread then task.cancel(_dodgeThread) end
	_dodgeThread = task.spawn(dodgeLoop)
	print("[AutoDodge] ✅ Auto Dodge: ACTIVE")
end

function AutoDodge.Stop()
	if _dodgeThread then
		task.cancel(_dodgeThread)
		_dodgeThread = nil
	end
	_dodging = false
	print("[AutoDodge] 🔴 Auto Dodge: DISABLED")
end

-- =============================================
-- [8] COMBAT FARM MODULE
-- =============================================
local CombatFarm = {}
local currentNapeHighlight = nil
local currentSelectionBox  = nil

local function isNapeDead(nape)
	return (not nape) or (not nape.Parent) or (not nape:IsDescendantOf(workspace))
end

local function attachHighlight(napePart)
	if currentNapeHighlight and currentNapeHighlight.Parent then
		currentNapeHighlight:Destroy()
	end
	if currentSelectionBox and currentSelectionBox.Parent then
		currentSelectionBox:Destroy()
	end

	local hl = Instance.new("SelectionBox")
	hl.Adornee          = napePart
	hl.Color3           = Color3.fromRGB(255, 50, 50)
	hl.LineThickness    = 0.08
	hl.SurfaceTransparency = 0.4
	hl.SurfaceColor3    = Color3.fromRGB(255, 80, 80)
	hl.Parent           = workspace

	local overlay = Instance.new("Part")
	overlay.Name          = "_NapeOverlay"
	overlay.CanCollide    = false
	overlay.CastShadow    = false
	overlay.Material      = Enum.Material.Neon
	overlay.BrickColor    = BrickColor.new("Bright red")
	overlay.Transparency  = 0.55
	overlay.Size = Vector3.new(
		math.max(napePart.Size.X * 3, 6),
		math.max(napePart.Size.Y * 3, 6),
		math.max(napePart.Size.Z * 3, 6)
	)
	overlay.Parent = workspace

	local weld     = Instance.new("WeldConstraint")
	weld.Part0     = overlay
	weld.Part1     = napePart
	weld.Parent    = overlay
	overlay.CFrame = napePart.CFrame

	currentNapeHighlight = overlay
	currentSelectionBox  = hl
end

local function removeHighlight()
	if currentNapeHighlight and currentNapeHighlight.Parent then
		currentNapeHighlight:Destroy()
	end
	if currentSelectionBox and currentSelectionBox.Parent then
		currentSelectionBox:Destroy()
	end
	currentNapeHighlight = nil
	currentSelectionBox  = nil
end

local function applyFly(rootPart, targetPos)
	local oldBP = rootPart:FindFirstChild("_FarmBodyPos")
	if oldBP then oldBP:Destroy() end
	local oldBG = rootPart:FindFirstChild("_FarmBodyGyro")
	if oldBG then oldBG:Destroy() end

	local bp = Instance.new("BodyPosition")
	bp.Name     = "_FarmBodyPos"
	bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	bp.D        = 800
	bp.P        = 15000
	bp.Position = targetPos
	bp.Parent   = rootPart

	local bg = Instance.new("BodyGyro")
	bg.Name     = "_FarmBodyGyro"
	bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
	bg.D        = 400
	bg.P        = 8000
	bg.CFrame   = CFrame.lookAt(rootPart.Position, targetPos)
	bg.Parent   = rootPart

	return bp, bg
end

local function removeFly(rootPart)
	local bp = rootPart:FindFirstChild("_FarmBodyPos")
	if bp then bp:Destroy() end
	local bg = rootPart:FindFirstChild("_FarmBodyGyro")
	if bg then bg:Destroy() end
end

function CombatFarm.GetBestTarget()
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local best, minDist = nil, math.huge
	for _, v in ipairs(workspace:GetDescendants()) do
		if v.Name == "Nape" and v:IsA("BasePart") then
			if v.Transparency < 0.99 then
				local d = (hrp.Position - v.Position).Magnitude
				if d < minDist then
					minDist = d
					best    = v
				end
			end
		end
	end
	return best
end

local function doAttack()
	local char = player.Character
	if not char then return end

	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then
		for _, t in ipairs(player.Backpack:GetChildren()) do
			if t:IsA("Tool") then
				local tLower = t.Name:lower()
				if tLower:find("blade") or tLower:find("sword")
					or tLower:find("knife") or tLower:find("odm")
					or tLower:find("titan") then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then hum:EquipTool(t) end
					task.wait(0.15)
					tool = char:FindFirstChildOfClass("Tool")
					break
				end
			end
		end
	end

	if tool and tool.Activate then
		pcall(function() tool:Activate() end)
	end
end

function CombatFarm.StartFarm()
	Config.FarmActive = true
	local sessionToken = Config:NewSession()

	task.spawn(function()
		print("[CombatFarm] 🚀 Farm Loop: BẮT ĐẦU")
		while Config.FarmActive and Config:IsValidSession(sessionToken) do
			local char = player.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			local hum  = char and char:FindFirstChildOfClass("Humanoid")

			if not hrp or not hum or hum.Health <= 0 then
				task.wait(1)
				continue
			end

			local nape = CombatFarm.GetBestTarget()
			if not nape or isNapeDead(nape) then
				removeHighlight()
				removeFly(hrp)
				task.wait(2)
				continue
			end

			attachHighlight(nape)
			local flyHeight = Config.FlyHeight
			local targetPos = nape.Position + Vector3.new(0, flyHeight, 0)

			applyFly(hrp, targetPos)

			local strikeRange = 20
			local timeout     = 8
			local elapsed     = 0

			while elapsed < timeout and Config.FarmActive do
				local dist = (hrp.Position - nape.Position).Magnitude
				local bg = hrp:FindFirstChild("_FarmBodyGyro")
				if bg then
					bg.CFrame = CFrame.lookAt(hrp.Position, nape.Position)
				end
				if dist <= strikeRange then break end
				if isNapeDead(nape) then break end
				elapsed = elapsed + 0.1
				task.wait(0.1)
			end

			if not isNapeDead(nape) then
				local dist = (hrp.Position - nape.Position).Magnitude
				if dist <= strikeRange then
					doAttack()
					task.wait(0.3)
					doAttack()
				end
			end
			task.wait(0.2)
		end

		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then removeFly(hrp) end
		removeHighlight()
		print("[CombatFarm] 🔴 Farm Loop: DỪNG")
	end)
end

function CombatFarm.StopFarm()
	Config.FarmActive = false
	Config:NewSession()
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then removeFly(hrp) end
	removeHighlight()
end

-- =============================================
-- [9] UI CONTROLLER MODULE
-- =============================================
local UIController = {}
local COLOR_BG       = Color3.fromRGB(12, 12, 18)
local COLOR_TITLE    = Color3.fromRGB(180, 30, 30)
local COLOR_ON       = Color3.fromRGB(50, 200, 100)
local COLOR_OFF      = Color3.fromRGB(90, 90, 100)
local COLOR_TEXT     = Color3.fromRGB(230, 230, 230)
local COLOR_LABEL    = Color3.fromRGB(160, 160, 175)
local COLOR_ACCENT   = Color3.fromRGB(200, 50, 50)
local screenGui  = nil
local mainFrame  = nil
local menuOpen   = false
UIController.Callbacks = {}

local function makeCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function makeStroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color        = color or COLOR_ACCENT
	s.Thickness    = thickness or 1.2
	s.Transparency = transparency or 0.3
	s.Parent       = parent
	return s
end

local function makePadding(parent, px)
	local p = Instance.new("UIPadding")
	p.PaddingLeft   = UDim.new(0, px)
	p.PaddingRight  = UDim.new(0, px)
	p.PaddingTop    = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
end

local function makeListLayout(parent, spacing)
	local l = Instance.new("UIListLayout")
	l.Padding          = UDim.new(0, spacing or 6)
	l.SortOrder        = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Parent = parent
	return l
end

local function makeLabel(parent, text, size, color, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size                = UDim2.new(1, -16, 0, size or 18)
	lbl.BackgroundTransparency = 1
	lbl.Text                = text
	lbl.TextColor3          = color or COLOR_LABEL
	lbl.TextSize            = 13
	lbl.Font                = Enum.Font.GothamSemibold
	lbl.TextXAlignment      = Enum.TextXAlignment.Left
	lbl.LayoutOrder         = order or 0
	lbl.Parent              = parent
	return lbl
end

local function makeToggle(parent, label, initState, order, onToggle)
	local row = Instance.new("Frame")
	row.Size                = UDim2.new(1, -12, 0, 34)
	row.BackgroundColor3    = Color3.fromRGB(22, 22, 32)
	row.BorderSizePixel     = 0
	row.LayoutOrder         = order
	row.Parent              = parent
	makeCorner(row, 7)

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, -60, 1, 0)
	lbl.Position           = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = label
	lbl.TextColor3         = COLOR_TEXT
	lbl.TextSize           = 13
	lbl.Font               = Enum.Font.Gotham
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.Parent             = row

	local indicator = Instance.new("Frame")
	indicator.Size             = UDim2.new(0, 40, 0, 20)
	indicator.Position         = UDim2.new(1, -50, 0.5, -10)
	indicator.BackgroundColor3 = initState and COLOR_ON or COLOR_OFF
	indicator.BorderSizePixel  = 0
	indicator.Parent           = row
	makeCorner(indicator, 10)

	local indText = Instance.new("TextLabel")
	indText.Size               = UDim2.new(1, 0, 1, 0)
	indText.BackgroundTransparency = 1
	indText.Text               = initState and "ON" or "OFF"
	indText.TextColor3         = Color3.fromRGB(255, 255, 255)
	indText.TextSize           = 11
	indText.Font               = Enum.Font.GothamBold
	indText.Parent             = indicator

	local state = initState
	local function toggle()
		state = not state
		local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
		TweenService:Create(indicator, tweenInfo, {
			BackgroundColor3 = state and COLOR_ON or COLOR_OFF
		}):Play()
		indText.Text = state and "ON" or "OFF"
		if onToggle then onToggle(state) end
	end

	row.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			toggle()
		end
	end)
	return row, function() return state end
end

local function makeDraggable(frame)
	local dragging, dragStart, startPos = false, nil, nil
	frame.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = inp.Position
			startPos  = frame.Position
		end
	end)
	frame.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch) then
			local delta = inp.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

function UIController.Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name              = "TitansMenu"
	screenGui.ResetOnSpawn      = false
	screenGui.DisplayOrder      = 999999
	screenGui.IgnoreGuiInset    = true
	screenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
	
	-- Try to place in CoreGui first to prevent resetting, fallback to PlayerGui
	local coreGuiSuccess, _ = pcall(function()
		screenGui.Parent = game:GetService("CoreGui")
	end)
	if not coreGuiSuccess then
		screenGui.Parent = player:WaitForChild("PlayerGui")
	end

	local openBtn = Instance.new("TextButton")
	openBtn.Name             = "OpenButton"
	openBtn.Size             = UDim2.new(0, 42, 0, 42)
	openBtn.Position         = UDim2.new(0, 10, 0.5, -21)
	openBtn.BackgroundColor3 = COLOR_TITLE
	openBtn.Text             = "⚔"
	openBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	openBtn.TextSize         = 20
	openBtn.Font             = Enum.Font.GothamBold
	openBtn.BorderSizePixel  = 0
	openBtn.ZIndex           = 10
	openBtn.Parent           = screenGui
	makeCorner(openBtn, 12)
	makeStroke(openBtn, COLOR_ACCENT, 1.5, 0.2)
	makeDraggable(openBtn)

	mainFrame = Instance.new("Frame")
	mainFrame.Name              = "MainFrame"
	mainFrame.Size              = UDim2.new(0, 240, 0, 380)
	mainFrame.Position          = UDim2.new(0, 60, 0.5, -190)
	mainFrame.BackgroundColor3  = COLOR_BG
	mainFrame.BackgroundTransparency = 0.08
	mainFrame.BorderSizePixel   = 0
	mainFrame.Visible           = false
	mainFrame.ZIndex            = 5
	mainFrame.Parent            = screenGui
	makeCorner(mainFrame, 12)
	makeStroke(mainFrame, COLOR_ACCENT, 1.5, 0.25)
	makeDraggable(mainFrame)

	local titleBar = Instance.new("Frame")
	titleBar.Size             = UDim2.new(1, 0, 0, 42)
	titleBar.BackgroundColor3 = COLOR_TITLE
	titleBar.BorderSizePixel  = 0
	titleBar.ZIndex           = 6
	titleBar.Parent           = mainFrame
	makeCorner(titleBar, 12)

	local patchBar = Instance.new("Frame")
	patchBar.Size             = UDim2.new(1, 0, 0, 12)
	patchBar.Position         = UDim2.new(0, 0, 1, -12)
	patchBar.BackgroundColor3 = COLOR_TITLE
	patchBar.BorderSizePixel  = 0
	patchBar.ZIndex           = 6
	patchBar.Parent           = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size               = UDim2.new(1, -10, 1, 0)
	titleLabel.Position           = UDim2.new(0, 14, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text               = "⚔  TITANS HUB"
	titleLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize           = 15
	titleLabel.Font               = Enum.Font.GothamBold
	titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
	titleLabel.ZIndex             = 7
	titleLabel.Parent             = titleBar

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size               = UDim2.new(0, 60, 1, 0)
	versionLabel.Position           = UDim2.new(1, -65, 0, 0)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text               = "v2.0"
	versionLabel.TextColor3         = Color3.fromRGB(255, 200, 200)
	versionLabel.TextSize           = 11
	versionLabel.Font               = Enum.Font.Gotham
	versionLabel.ZIndex             = 7
	versionLabel.Parent             = titleBar

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name                    = "ToggleScroll"
	scroll.Size                    = UDim2.new(1, 0, 1, -46)
	scroll.Position                = UDim2.new(0, 0, 0, 44)
	scroll.BackgroundTransparency  = 1
	scroll.BorderSizePixel         = 0
	scroll.ScrollBarThickness      = 3
	scroll.ScrollBarImageColor3    = COLOR_ACCENT
	scroll.CanvasSize              = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize     = Enum.AutomaticSize.Y
	scroll.ZIndex                  = 6
	scroll.Parent                  = mainFrame
	makePadding(scroll, 8)
	makeListLayout(scroll, 6)

	makeLabel(scroll, "── FARM ──", 16, COLOR_ACCENT, 1)
	makeToggle(scroll, "🌀  Nape Farm", Config.FarmActive, 2, function(on)
		Config.FarmActive = on
		local cb = UIController.Callbacks["Farm"]
		if cb then cb(on) end
	end)

	makeLabel(scroll, "── COMBAT ──", 16, COLOR_ACCENT, 10)
	makeToggle(scroll, "💥  Always Crit", Config.CritEnabled, 11, function(on)
		Config.CritEnabled = on
		local cb = UIController.Callbacks["Crit"]
		if cb then cb(on) end
	end)
	makeToggle(scroll, "📐  Hitbox Extender", Config.HitboxEnabled, 12, function(on)
		Config.HitboxEnabled = on
		local cb = UIController.Callbacks["Hitbox"]
		if cb then cb(on) end
	end)
	makeToggle(scroll, "💨  Auto Dodge", Config.DodgeEnabled, 13, function(on)
		Config.DodgeEnabled = on
		local cb = UIController.Callbacks["Dodge"]
		if cb then cb(on) end
	end)

	makeLabel(scroll, "── SURVIVAL ──", 16, COLOR_ACCENT, 20)
	makeToggle(scroll, "💊  Auto Heal", Config.HealEnabled, 21, function(on)
		Config.HealEnabled = on
		local cb = UIController.Callbacks["Heal"]
		if cb then cb(on) end
	end)
	makeToggle(scroll, "⛽  Auto Refill", Config.RefillEnabled, 22, function(on)
		Config.RefillEnabled = on
		local cb = UIController.Callbacks["Refill"]
		if cb then cb(on) end
	end)

	makeLabel(scroll, "── MISC ──", 16, COLOR_ACCENT, 30)
	makeToggle(scroll, "⏰  Anti-AFK", Config.AntiAFKEnabled, 31, function(on)
		Config.AntiAFKEnabled = on
		local cb = UIController.Callbacks["AntiAFK"]
		if cb then cb(on) end
	end)
	makeToggle(scroll, "🧱  Wall Visual", Config.WallEnabled, 32, function(on)
		Config.WallEnabled = on
	end)

	local statusBar = Instance.new("Frame")
	statusBar.Size             = UDim2.new(1, -16, 0, 22)
	statusBar.Position         = UDim2.new(0, 8, 1, -28)
	statusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	statusBar.BorderSizePixel  = 0
	statusBar.ZIndex           = 6
	statusBar.Parent           = mainFrame
	makeCorner(statusBar, 6)

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Name               = "StatusLabel"
	statusLbl.Size               = UDim2.new(1, -8, 1, 0)
	statusLbl.Position           = UDim2.new(0, 6, 0, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text               = "● READY"
	statusLbl.TextColor3         = COLOR_ON
	statusLbl.TextSize           = 11
	statusLbl.Font               = Enum.Font.GothamSemibold
	statusLbl.TextXAlignment     = Enum.TextXAlignment.Left
	statusLbl.ZIndex             = 7
	statusLbl.Parent             = statusBar
	UIController.StatusLabel = statusLbl

	local function toggleMenu()
		menuOpen = not menuOpen
		mainFrame.Visible = menuOpen
		if menuOpen then
			local tween = TweenService:Create(mainFrame,
				TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{Size = UDim2.new(0, 240, 0, 380)}
			)
			mainFrame.Size = UDim2.new(0, 240, 0, 0)
			tween:Play()
		end
	end

	openBtn.MouseButton1Click:Connect(toggleMenu)

	UIS.InputBegan:Connect(function(inp, gp)
		if gp then return end
		if inp.KeyCode == Enum.KeyCode.RightShift then
			toggleMenu()
		end
	end)

	print("[UIController] ✅ UI Initialized – RightShift / ⚔ to toggle menu")
end

function UIController.SetStatus(text, color)
	if UIController.StatusLabel then
		UIController.StatusLabel.Text      = "● " .. text
		UIController.StatusLabel.TextColor3 = color or COLOR_ON
	end
end

-- =============================================
-- [10] WIRE CALLBACKS & INITIALIZATION
-- =============================================

UIController.Callbacks["Farm"] = function(on)
	if on then
		CombatFarm.StartFarm()
		UIController.SetStatus("FARMING...", Color3.fromRGB(255, 100, 100))
	else
		CombatFarm.StopFarm()
		UIController.SetStatus("READY", Color3.fromRGB(50, 200, 100))
	end
end

UIController.Callbacks["Crit"] = function(on)
	if on then CritHook.Start() else CritHook.Stop() end
end

UIController.Callbacks["Hitbox"] = function(on)
	if on then HitboxExtender.Start() else HitboxExtender.Stop() end
end

UIController.Callbacks["Dodge"] = function(on)
	if on then AutoDodge.Start() else AutoDodge.Stop() end
end

UIController.Callbacks["Heal"] = function(on)
	if on then AutoHeal.Start() else AutoHeal.Stop() end
end

UIController.Callbacks["Refill"] = function(on)
	if on then AutoRefill.Start() else AutoRefill.Stop() end
end

UIController.Callbacks["AntiAFK"] = function(on)
	if on then AntiAFK.Start() else AntiAFK.Stop() end
end

-- Run System
UIController.Init()

task.spawn(function()
	task.wait(0.5)
	if Config.CritEnabled then CritHook.Start() end
	if Config.HitboxEnabled then HitboxExtender.Start() end
	if Config.DodgeEnabled then AutoDodge.Start() end
	if Config.HealEnabled then AutoHeal.Start() end
	if Config.RefillEnabled then AutoRefill.Start() end
	if Config.AntiAFKEnabled then AntiAFK.Start() end
	if Config.FarmActive then
		CombatFarm.StartFarm()
		UIController.SetStatus("FARMING...", Color3.fromRGB(255, 100, 100))
	else
		UIController.SetStatus("READY", Color3.fromRGB(50, 200, 100))
	end
end)

print("[TitansHub] 🚀 Consolidated script loaded successfully!")
