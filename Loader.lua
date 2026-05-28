-- [[ TITANS HUB - MAIN ENTRY POINT ]]
-- Vị trí: TitansHub -> Loader (Script chính để chạy trong Executor)

local Players = game:GetService("Players")
local player  = Players.LocalPlayer

-- 1. Thiết lập hệ thống nạp Module qua HttpGet hoặc từ Local (để test)
getgenv().TitansHubRepo = getgenv().TitansHubRepo or "https://raw.githubusercontent.com/NguyenTriThuc2010/Haha/main/"
getgenv().TitansHubCache = getgenv().TitansHubCache or {}

getgenv().RequireModule = function(file)
	if not getgenv().TitansHubCache[file] then
		-- Nếu chạy cục bộ từ executor hỗ trợ readfile, ta ưu tiên đọc file local trước để dev/test nhanh
		local success, content = pcall(function()
			if readfile then
				return readfile("TitansHub/" .. file)
			end
		end)
		if success and content then
			getgenv().TitansHubCache[file] = loadstring(content)()
		else
			-- Fallback tải từ github repo
			local url = getgenv().TitansHubRepo .. file
			local httpSuccess, httpContent = pcall(function()
				return game:HttpGet(url)
			end)
			if httpSuccess and httpContent then
				getgenv().TitansHubCache[file] = loadstring(httpContent)()
			else
				error("[TitansHub] Lỗi tải module: " .. file)
			end
		end
	end
	return getgenv().TitansHubCache[file]
end

-- 2. Tải các Module thành phần
local Config         = getgenv().RequireModule("Configs.lua")
local UIController   = getgenv().RequireModule("UIController.lua")
local CritHook       = getgenv().RequireModule("CritHook.lua")
local AutoHeal       = getgenv().RequireModule("AutoHeal.lua")
local AntiAFK        = getgenv().RequireModule("AntiAFK.lua")
local HitboxExtender = getgenv().RequireModule("HitboxExtender.lua")
local AutoRefill     = getgenv().RequireModule("AutoRefill.lua")
local AutoDodge      = getgenv().RequireModule("AutoDodge.lua")
local CombatFarm     = getgenv().RequireModule("CombatFarm.lua")

-- =============================================
-- KẾT NỐI UI TOOGLE CALLBACKS VỚI MODULE LOGIC
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
	if on then
		CritHook.Start()
	else
		CritHook.Stop()
	end
end

UIController.Callbacks["Hitbox"] = function(on)
	if on then
		HitboxExtender.Start()
	else
		HitboxExtender.Stop()
	end
end

UIController.Callbacks["Dodge"] = function(on)
	if on then
		AutoDodge.Start()
	else
		AutoDodge.Stop()
	end
end

UIController.Callbacks["Heal"] = function(on)
	if on then
		AutoHeal.Start()
	else
		AutoHeal.Stop()
	end
end

UIController.Callbacks["Refill"] = function(on)
	if on then
		AutoRefill.Start()
	else
		AutoRefill.Stop()
	end
end

UIController.Callbacks["AntiAFK"] = function(on)
	if on then
		AntiAFK.Start()
	else
		AntiAFK.Stop()
	end
end

-- =============================================
-- KHỞI TẠO HỆ THỐNG
-- =============================================

-- Khởi tạo UI
UIController.Init()

-- Khởi động các tính năng mặc định được bật trong Config
task.spawn(function()
	task.wait(0.5) -- Đợi UI sẵn sàng
	
	if Config.CritEnabled then
		CritHook.Start()
	end
	if Config.HitboxEnabled then
		HitboxExtender.Start()
	end
	if Config.DodgeEnabled then
		AutoDodge.Start()
	end
	if Config.HealEnabled then
		AutoHeal.Start()
	end
	if Config.RefillEnabled then
		AutoRefill.Start()
	end
	if Config.AntiAFKEnabled then
		AntiAFK.Start()
	end
	if Config.FarmActive then
		CombatFarm.StartFarm()
		UIController.SetStatus("FARMING...", Color3.fromRGB(255, 100, 100))
	else
		UIController.SetStatus("READY", Color3.fromRGB(50, 200, 100))
	end
end)

print("[TitansHub] 🚀 Hệ thống đã sẵn sàng!")
