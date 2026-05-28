-- [[ AUTO HEAL MODULE ]]
-- Tự động dùng Bandage khi máu <= HealThreshold%
-- Hỗ trợ: dùng Tool từ Backpack hoặc Character

local AutoHeal = {}

local Players   = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config    = getgenv().RequireModule("Configs.lua")
local player    = Players.LocalPlayer

-- Danh sách tên vật phẩm hồi máu có thể nhận dạng
local HEAL_ITEM_NAMES = {
	"Bandage", "bandage",
	"FirstAid", "firstaid", "first_aid",
	"HealKit", "healkit",
	"MedKit",  "medkit",
}

local _healing  = false   -- Chống gọi đè khi đang dùng băng
local _conn     = nil     -- Connection RunService

-- =============================================
-- INTERNAL HELPERS
-- =============================================

-- Tìm vật phẩm hồi máu trong Backpack hoặc Character
local function findHealItem()
	local char = player.Character
	if not char then return nil end

	-- Tìm trong Backpack trước
	for _, name in ipairs(HEAL_ITEM_NAMES) do
		local item = player.Backpack:FindFirstChild(name)
			or char:FindFirstChild(name)
		if item then return item end
	end

	-- Fallback: duyệt Backpack tìm Tool có tên chứa keyword
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

-- =============================================
-- LOGIC HEAL CHÍNH
-- =============================================
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
			-- Kích hoạt Tool (Activate thay vì Activated vì đó là event)
			if item.Activate then
				item:Activate()
			end
			print(string.format("[AutoHeal] 💊 HP thấp (%.0f%%) – Dùng %s", hpPct, item.Name))
			task.wait(3.0)  -- Chờ animation hồi máu
		end
	end)

	_healing = false
end

-- =============================================
-- START / STOP
-- =============================================
function AutoHeal.Start()
	if _conn then _conn:Disconnect() end

	_conn = RunService.Heartbeat:Connect(function()
		tryHeal()
	end)

	print("[AutoHeal] ✅ Auto Heal: ACTIVE (Ngưỡng: " .. Config.HealThreshold .. "%)")
end

function AutoHeal.Stop()
	if _conn then
		_conn:Disconnect()
		_conn = nil
	end
	print("[AutoHeal] 🔴 Auto Heal: DISABLED")
end

return AutoHeal
