-- [[ MAIN LOADER - LOCAL SCRIPT ]]
-- Vị trí: Đặt trực tiếp trong folder TitansHub (StarterPlayerScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- 1. Tìm folder gốc và các Modules con
local TitansHub = script.Parent
local Modules = TitansHub:WaitForChild("Modules")

-- 2. Require các ModuleScript thành phần
local Config = require(TitansHub:WaitForChild("Config"))
local UIController = require(Modules:WaitForChild("UIController"))
local CombatFarm = require(Modules:WaitForChild("CombatFarm"))
local Visuals = require(Modules:WaitForChild("Visuals"))
-- Sau này nếu thêm tính năng mới (vd: Teleport, ESP), bạn chỉ cần require thêm ở đây:
-- local Teleport = require(Modules:WaitForChild("Teleport"))

-- =============================================
-- KHỞI TẠO HỆ THỐNG
-- =============================================

-- Vẽ toàn bộ giao diện GUI lên màn hình người chơi
UIController.Init()

-- =============================================
-- KẾT NỐI SỰ KIỆN TỪ GIAO DIỆN (UI EVENTS)
-- =============================================

-- Lắng nghe nút bấm 1: FARM NAPE
UIController.GetButton("FarmNape").MouseButton1Click:Connect(function()
	Config.FarmActive = not Config.FarmActive

	if Config.FarmActive then
		UIController.UpdateButton("FarmNape", "Farm Nape: BẬT", Color3.fromRGB(30, 160, 30))
		CombatFarm.StartLoop()
	else
		UIController.UpdateButton("FarmNape", "Farm Nape: TẮT", Color3.fromRGB(160, 30, 30))
		CombatFarm.Stop()
	end
end)

-- Lắng nghe nút bấm 2: HIỆU ỨNG TƯỜNG (WALL EFFECT)
UIController.GetButton("ToggleWall").MouseButton1Click:Connect(function()
	Config.WallEnabled = not Config.WallEnabled
	
	if Config.WallEnabled then
		UIController.UpdateButton("ToggleWall", "Hiệu ứng tường: BẬT", Color3.fromRGB(30, 60, 100))
	else
		UIController.UpdateButton("ToggleWall", "Hiệu ứng tường: TẮT", Color3.fromRGB(50, 40, 40))
		Visuals.ClearWallEffect() -- Dọn dẹp hiệu ứng ngay lập tức nếu đang bật
	end
end)

-- Lắng nghe nút bấm 3: THAY ĐỔI ĐỘ CAO (FLY HEIGHT)
UIController.GetButton("ChangeHeight").MouseButton1Click:Connect(function()
	Config.HeightIndex = (Config.HeightIndex % #Config.HeightOptions) + 1
	Config.FlyHeight = Config.HeightOptions[Config.HeightIndex]
	
	UIController.UpdateButton("ChangeHeight", "Độ cao: " .. Config.FlyHeight, Color3.fromRGB(30, 80, 50))
end)

-- =============================================
-- QUẢN LÝ PHÍM TẮT TOÀN CỤC (HOTKEYS)
-- =============================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- Nhấn RightShift để Ẩn/Hiện Menu
	if input.KeyCode == Enum.KeyCode.RightShift then
		UIController.ToggleMenu()
	end
end)

print("✅ [Titans Hub] MainLoader đã kích hoạt thành công!")