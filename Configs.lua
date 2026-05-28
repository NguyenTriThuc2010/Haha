-- [[ CONFIG MODULE ]]
-- Vị trí: TitansHub -> Config (ModuleScript)

local Config = {
	-- Trạng thái các tính năng (Bật/Tắt)
	FarmActive = false,
	WallEnabled = true,
	
	-- Cấu hình độ cao bay
	FlyHeight = 50, -- Mặc định ban đầu
	HeightOptions = {30, 50, 80, 120},
	HeightIndex = 2, -- Tương ứng với vị trí số 2 trong bảng trên (50)
	
	-- Hệ thống Quản lý Session (Chống trùng loop khi bật/tắt liên tục)
	FarmSessionId = 0,
	
	-- Khoảng cách dịch chuyển Nape ra trước ngực người chơi (studs)
	NapeFrontOffset = 5
}

return Config