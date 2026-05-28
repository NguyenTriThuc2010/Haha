-- [[ VISUALS MODULE ]]
-- Vị trí: TitansHub -> Modules -> Visuals (ModuleScript)

local Visuals = {}

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Tên định danh cho phần tử hiệu ứng để dễ quản lý, thu dọn
local WALL_EFFECT_NAME = "_NapeWallEffect"

-- =============================================
-- API CHÍNH CỦA MODULE (MAIN API)
-- =============================================

-- Hàm tạo hiệu ứng bức tường Neon đỏ kéo dài từ người chơi đến Nape
function Visuals.CreateWallEffect(napePart, characterRootPart)
	-- Dọn dẹp bức tường cũ nếu nó chưa kịp biến mất hẳn
	Visuals.ClearWallEffect()

	local napePos   = napePart.Position
	local playerPos = characterRootPart.Position
	
	-- Tính toán hướng và khoảng cách phẳng (bỏ qua trục Y để tường đứng thẳng)
	local dirFlat   = Vector3.new(playerPos.X - napePos.X, 0, playerPos.Z - napePos.Z)
	local dist      = math.max(dirFlat.Magnitude, 1)
	dirFlat         = dirFlat.Unit

	local wallHeight = 60
	local wallLength = dist + 5
	
	-- Điểm giữa của bức tường
	local midPoint   = Vector3.new(
		(napePos.X + playerPos.X) / 2,
		napePos.Y + wallHeight / 2 - 10,
		(napePos.Z + playerPos.Z) / 2
	)

	-- Khởi tạo Part cho bức tường
	local wall = Instance.new("Part")
	wall.Name         = WALL_EFFECT_NAME
	wall.Anchored      = true
	wall.CanCollide   = false
	wall.Material     = Enum.Material.Neon
	wall.BrickColor   = BrickColor.new("Bright red")
	wall.Transparency = 0.3
	
	-- Độ dày ban đầu cực mỏng để làm hiệu ứng phóng to dần ra
	wall.Size         = Vector3.new(2, wallHeight, 0.1)

	-- Xoay hướng bức tường thẳng hàng với góc nhìn từ Nape đến người chơi
	local angle = math.atan2(dirFlat.X, dirFlat.Z)
	wall.CFrame = CFrame.new(
		Vector3.new(napePos.X, napePos.Y + wallHeight / 2 - 10, napePos.Z)
	) * CFrame.Angles(0, angle, 0)
	
	wall.Parent = workspace

	-- Thực hiện hiệu ứng Tween kéo dài bức tường ra mượt mà
	TweenService:Create(wall, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size   = Vector3.new(2, wallHeight, wallLength),
		CFrame = CFrame.new(midPoint) * CFrame.Angles(0, angle, 0)
	}):Play()

	-- Tự động xóa bức tường khỏi bộ nhớ sau 2 giây (Chống rác bộ nhớ / Memory Leak)
	Debris:AddItem(wall, 2)
end

-- Hàm dọn dẹp bức tường ngay lập tức khi tắt tính năng
function Visuals.ClearWallEffect()
	local oldWall = workspace:FindFirstChild(WALL_EFFECT_NAME)
	if oldWall then 
		oldWall:Destroy() 
	end
end

return Visuals