-- [[ ANTI-AFK MODULE ]]
-- Dùng VirtualUser service + physics jitter để tránh bị kick AFK
-- Tự động ping mỗi 2 phút

local AntiAFK = {}

local VirtualUser = game:GetService("VirtualUser")
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Config      = getgenv().RequireModule("Configs.lua")
local player      = Players.LocalPlayer

local _running    = false
local _thread     = nil
local _jitterConn = nil

-- =============================================
-- VIRTUALUSER PING (Chính)
-- =============================================
local function pingVirtualUser()
	pcall(function()
		-- Giả lập nhấn phím và click chuột
		VirtualUser:SetKeyboardEnabled(true)
		VirtualUser:SetMouseEnabled(true)
		VirtualUser:Button1Down(Vector2.new(0, 0), CFrame.new())
		task.wait(0.05)
		VirtualUser:Button1Up(Vector2.new(0, 0), CFrame.new())
	end)
end

-- =============================================
-- PHYSICS JITTER (Phụ – di chuyển nhỏ để server biết vẫn online)
-- =============================================
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

-- =============================================
-- VÒNG LẶP CHÍNH
-- =============================================
local function afkLoop()
	_running = true
	local interval = 120  -- 2 phút / lần

	while _running and Config.AntiAFKEnabled do
		pingVirtualUser()
		print("[AntiAFK] 🔄 Ping gửi – Chống AFK hoạt động")
		task.wait(interval)
	end
end

-- =============================================
-- START / STOP
-- =============================================
function AntiAFK.Start()
	if _thread then task.cancel(_thread) end
	if _jitterConn then _jitterConn:Disconnect() end

	-- Jitter nhẹ mỗi 60 giây
	_jitterConn = task.delay(60, function()
		while _running do
			doJitter()
			task.wait(60)
		end
	end)

	_thread  = task.spawn(afkLoop)
	print("[AntiAFK] ✅ Anti-AFK: ACTIVE")
end

function AntiAFK.Stop()
	_running = false
	if _thread then
		task.cancel(_thread)
		_thread = nil
	end
	if _jitterConn then
		task.cancel(_jitterConn)
		_jitterConn = nil
	end
	print("[AntiAFK] 🔴 Anti-AFK: DISABLED")
end

return AntiAFK
