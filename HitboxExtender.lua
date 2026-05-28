-- [[ HITBOX EXTENDER MODULE ]]
-- Mở rộng hitbox của Titan (Nape) để dễ hit hơn từ khoảng cách xa
-- Cơ chế: Thay đổi Size của part "Nape" trong các model Titan ở Workspace

local HitboxExtender = {}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config     = getgenv().RequireModule("Configs.lua")
local player     = Players.LocalPlayer

local _originalSizes = {}   -- Lưu size gốc: [part] = Vector3
local _originalTrans = {}   -- Lưu transparency gốc: [part] = number
local _originalCol   = {}   -- Lưu cancollide gốc: [part] = boolean
local _conn      = nil
local _active    = false

-- =============================================
-- INTERNAL HELPERS
-- =============================================

-- Tìm Nape trong Titan model
local function getTitanNape(titanModel)
	local hitboxes = titanModel:FindFirstChild("Hitboxes")
	if hitboxes then
		local hitFolder = hitboxes:FindFirstChild("Hit")
		if hitFolder then
			return hitFolder:FindFirstChild("Nape")
		end
	end
	return titanModel:FindFirstChild("Nape", true)
end

-- Áp hitbox lên Nape
local function expandNape(nape)
	if not nape or not nape:IsA("BasePart") then return end
	if not _originalSizes[nape] then
		_originalSizes[nape] = nape.Size
		_originalTrans[nape] = nape.Transparency
		_originalCol[nape]   = nape.CanCollide
	end
	local size = Config.HitboxSize or 25
	nape.Size = Vector3.new(size, size, size)
	nape.Transparency = 0.85 -- Rất mờ để không cản trở tầm nhìn
	nape.CanCollide = false  -- Không gây kẹt vật lý
end

-- Khôi phục một Nape
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

-- Quét toàn bộ workspace để mở rộng tất cả Nape hiện có
local function expandAllNapes()
	for _, v in ipairs(workspace:GetDescendants()) do
		if v.Name == "Nape" and v:IsA("BasePart") then
			expandNape(v)
		end
	end
end

-- Khôi phục toàn bộ Napes về trạng thái gốc
local function restoreAllNapes()
	for nape, _ in pairs(_originalSizes) do
		restoreNape(nape)
	end
	_originalSizes = {}
	_originalTrans = {}
	_originalCol   = {}
end

-- =============================================
-- START / STOP
-- =============================================
function HitboxExtender.Start()
	if _active then return end
	_active = true

	-- Áp dụng ngay lập tức cho các Titan hiện có
	pcall(expandAllNapes)

	-- Lắng nghe và tự động áp dụng cho các Titan mới xuất hiện
	_conn = workspace.DescendantAdded:Connect(function(desc)
		if not _active or not Config.HitboxEnabled then return end
		if desc.Name == "Nape" and desc:IsA("BasePart") then
			task.wait(0.1) -- Đợi load xong
			pcall(function() expandNape(desc) end)
		end
	end)

	-- Chạy loop kiểm tra định kỳ đề phòng bỏ sót
	task.spawn(function()
		while _active and Config.HitboxEnabled do
			pcall(expandAllNapes)
			task.wait(2.5)
		end
	end)

	print("[HitboxExtender] ✅ Hitbox Extender: ACTIVE (Size: " .. Config.HitboxSize .. " studs)")
end

function HitboxExtender.Stop()
	_active = false

	if _conn then
		_conn:Disconnect()
		_conn = nil
	end

	pcall(restoreAllNapes)
	print("[HitboxExtender] 🔴 Hitbox Extender: DISABLED – Đã khôi phục kích thước gốc của các Titan")
end

function HitboxExtender.SetSize(size)
	Config.HitboxSize = size
	if _active and Config.HitboxEnabled then
		pcall(expandAllNapes)
	end
	print("[HitboxExtender] 📐 Cập nhật size hitbox: " .. size .. " studs")
end

return HitboxExtender
