-- [[ AUTO REFILL MODULE ]]
-- Tự động nạp Gas và thay Lưỡi kiếm khi cạn
-- Cơ chế: Tìm ProximityPrompt "Refill" trong workspace rồi trigger

local AutoRefill = {}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config     = getgenv().RequireModule("Configs.lua")
local player     = Players.LocalPlayer

local _conn      = nil
local _lastRefill = 0
local REFILL_COOLDOWN = 8  -- giây giữa 2 lần refill

-- =============================================
-- INTERNAL HELPERS – ĐỌC CHỈ SỐ
-- =============================================

-- Đọc Gas / Blade từ PlayerGui hoặc từ leaderstats / character attributes
local function readStat(statNames)
	-- Thử leaderstats
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		for _, name in ipairs(statNames) do
			local v = ls:FindFirstChild(name)
			if v then return tonumber(v.Value) end
		end
	end
	-- Thử PlayerData (common AOTR structure)
	local pd = player:FindFirstChild("PlayerData")
		or player:FindFirstChild("Data")
		or player:FindFirstChild("Stats")
	if pd then
		for _, name in ipairs(statNames) do
			local v = pd:FindFirstChild(name)
			if v then return tonumber(v.Value) end
		end
	end
	-- Thử Character Attributes
	local char = player.Character
	if char then
		for _, name in ipairs(statNames) do
			local val = char:GetAttribute(name)
			if val then return tonumber(val) end
		end
	end
	return nil
end

local function getGas()
	return readStat({"Gas", "GasAmount", "Fuel", "gas", "GasTank"})
end

local function getBlades()
	return readStat({"Blade", "BladeCount", "Blades", "blades", "SwordCount", "Swords"})
end

-- =============================================
-- TRIGGER PROXIMITY PROMPT
-- =============================================
local function triggerNearestPrompt(keywords)
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local bestPrompt = nil
	local bestDist   = 30  -- Bán kính tìm kiếm (studs)

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
			-- Tele gần nếu quá xa
			local part = bestPrompt.Parent
			if part and part:IsA("BasePart") then
				if (hrp.Position - part.Position).Magnitude > bestPrompt.MaxActivationDistance then
					hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 3))
					task.wait(0.3)
				end
			end

			-- Trigger prompt
			local firePrompt = game:GetService("ProximityPromptService")
			firePrompt:PromptTriggered(bestPrompt, player)

			-- Fallback: dùng remote nếu có
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

-- =============================================
-- LOGIC REFILL CHÍNH
-- =============================================
local function checkAndRefill()
	if not Config.RefillEnabled then return end

	local now = os.clock()
	if (now - _lastRefill) < REFILL_COOLDOWN then return end

	local gas    = getGas()
	local blades = getBlades()

	local needRefill = false

	if gas and gas <= Config.GasMin then
		print(string.format("[AutoRefill] ⛽ Gas thấp (%s) – Đang tìm trạm refill...", tostring(gas)))
		needRefill = true
	end

	if blades and blades <= Config.BladeMin then
		print(string.format("[AutoRefill] ⚔️  Lưỡi kiếm thấp (%s) – Đang tìm trạm thay...", tostring(blades)))
		needRefill = true
	end

	-- Nếu không đọc được stat, vẫn thử refill định kỳ mỗi 60 giây (safe fallback)
	if gas == nil and blades == nil then
		if (now - _lastRefill) >= 60 then
			needRefill = true
			print("[AutoRefill] ℹ️  Không đọc được stat – Thử refill định kỳ...")
		end
	end

	if needRefill then
		local ok = triggerNearestPrompt({
			"refill", "reload", "supply", "gas", "blade",
			"interact", "replace", "restock"
		})
		if ok then
			_lastRefill = now
			print("[AutoRefill] ✅ Refill thành công!")
		end
	end
end

-- =============================================
-- START / STOP
-- =============================================
function AutoRefill.Start()
	if _conn then _conn:Disconnect() end

	_lastRefill = 0
	_conn = RunService.Heartbeat:Connect(function()
		checkAndRefill()
	end)

	print("[AutoRefill] ✅ Auto Refill: ACTIVE")
end

function AutoRefill.Stop()
	if _conn then
		_conn:Disconnect()
		_conn = nil
	end
	print("[AutoRefill] 🔴 Auto Refill: DISABLED")
end

return AutoRefill
