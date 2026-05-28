-- [[ COMBAT FARM MODULE ]]
-- Vị trí: TitansHub -> Modules -> CombatFarm (ModuleScript)

local CombatFarm = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer

-- Gọi module Cấu hình để đồng bộ trạng thái bật/tắt
local TitansHub = script.Parent.Parent
local Config = require(TitansHub:WaitForChild("Config"))

-- Khởi tạo biến quản lý Highlight nội bộ
local currentNapeHighlight = nil
local currentSelectionBox = nil

-- =============================================
-- CÁC HÀM TIỆN ÍCH NỘI BỘ (INTERNAL HELPERS)
-- =============================================

local function findNapeInTitan(titanModel)
	local hitboxes = titanModel:FindFirstChild("Hitboxes")
	if hitboxes then
		local hitFolder = hitboxes:FindFirstChild("Hit")
		if hitFolder then
			return hitFolder:FindFirstChild("Nape")
		end
	end
	return nil
end

local function isNapeDead(nape)
	return (not nape) or (not nape.Parent) or (not nape:IsDescendantOf(workspace))
end

local function attachHighlight(napePart)
	if currentNapeHighlight and currentNapeHighlight.Parent then currentNapeHighlight:Destroy() end
	if currentSelectionBox and currentSelectionBox.Parent then currentSelectionBox:Destroy() end

	local hl = Instance.new("SelectionBox")
	hl.Adornee = napePart
	hl.Color3 = Color3.fromRGB(255, 50, 50)
	hl.LineThickness = 0.08
	hl.SurfaceTransparency = 0.4
	hl.SurfaceColor3 = Color3.fromRGB(255, 80, 80)
	hl.Parent = workspace

	local overlay = Instance.new("Part")
	overlay.Name = "_NapeOverlay"
	overlay.Anchored = false
	overlay.CanCollide = false
	overlay.CastShadow = false
	overlay.Material = Enum.Material.Neon
	overlay.BrickColor = BrickColor.new("Bright red")
	overlay.Transparency = 0.55
	overlay.Size = Vector3.new(
		math.max(napePart.Size.X * 3, 6),
		math.max(napePart.Size.Y * 3, 6),
		math.max(napePart.Size.Z * 3, 6)
	)
	overlay.Parent = workspace

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = overlay
	weld.Part1 = napePart
	weld.Parent = overlay
	overlay.CFrame = napePart.CFrame

	currentNapeHighlight = overlay
	currentSelectionBox = hl
end

local function removeHighlight()
	if currentNapeHighlight and currentNapeHighlight.Parent then currentNapeHighlight:Destroy() end
	if currentSelectionBox and currentSelectionBox.Parent then currentSelectionBox:Destroy() end
	currentNapeHighlight = nil
	currentSelectionBox = nil
end

local function applyFly(rootPart, targetPos)
	local oldBP = rootPart:FindFirstChild("_FarmBodyPos")
	if oldBP then oldBP:Destroy() end
	local oldBG = rootPart:FindFirstChild("_FarmBodyGyro")
	if oldBG then oldBG:Destroy() end

	local bp = Instance.new("BodyPosition")
	bp.Name = "_FarmBodyPos"
	bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	bp.D = 800
	bp.P = 15000
	bp.Position = targetPos
	bp.Parent = rootPart

	local bg = Instance.new("BodyGyro")
	bg.Name = "_FarmBodyGyro"
	bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
	bg.D = 400
	bg.P = 8000
	bg.CFrame = rootPart.CFrame
	bg.Parent = rootPart

	return bp, bg
end

local function removeFly(rootPart)
	local bp = rootPart:FindFirstChild("_FarmBodyPos")
	if bp then bp:Destroy() end
	local bg = rootPart:FindFirstChild("_FarmBodyGyro")
	if bg then bg:Destroy() end
end

local function getNapeInFrontCFrame(rootPart)
	local lookFlat = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	if lookFlat.Magnitude < 0.01 then
		lookFlat = Vector3.new(0, 0, -1)
	end
	lookFlat = lookFlat.Unit

	local frontPos = rootPart.Position + lookFlat * Config.NapeFrontOffset + Vector3.new(0, 1, 0)
	return CFrame.new(frontPos)
end

-- Hàm tạo tường bảo vệ (được bóc tách gián tiếp từ module Visuals)
local function tryCreateWall(targetNape, rootPart)
	local success, Visuals = pcall(function() return require(script.Parent.Visuals) end)
	if success and Visuals and Visuals.CreateWallEffect then
		Visuals.CreateWallEffect(targetNape, rootPart)
	end
end

-- =============================================
-- API CHÍNH CỦA MODULE (MAIN API)
-- =============================================

function CombatFarm.StartLoop()
	-- Tăng Session ID toàn cục để triệt tiêu các Thread vòng lặp cũ ngay tắp lự
	Config.FarmSessionId += 1
	local mySessionId = Config.FarmSessionId

	local function isAlive()
		return Config.FarmActive and (Config.FarmSessionId == mySessionId)
	end

	task.spawn(function()
		while isAlive() do
			local character = player.Character
			if not character then task.wait(0.5) continue end

			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if not rootPart then task.wait(0.5) continue end

			local titansGroup = workspace:FindFirstChild("Titans")
			if not titansGroup then task.wait(1) continue end

			-- 1. Tìm mục tiêu Titan gần nhất
			local targetNape = nil
			local closestDist = math.huge

			for _, child in ipairs(titansGroup:GetChildren()) do
				if child:IsA("Model") then
					local nape = findNapeInTitan(child)
					if nape then
						local dist = (nape.Position - rootPart.Position).Magnitude
						if dist < closestDist then
							closestDist = dist
							targetNape = nape
						end
					end
				end
			end

			if not targetNape then task.wait(0.5) continue end

			-- Đánh dấu mục tiêu bằng Highlight đỏ rực
			attachHighlight(targetNape)

			-- 2. GIAI ĐOẠN 1: Tiến hành tiếp cận (Bay lên đỉnh đầu Titan)
			local targetPos = targetNape.Position + Vector3.new(0, Config.FlyHeight, 0)
			local bp, bg = applyFly(rootPart, targetPos)

			if Config.WallEnabled then
				tryCreateWall(targetNape, rootPart)
			end

			local timeout = 0
			while isAlive() and timeout < 5 do
				if isNapeDead(targetNape) then break end
				targetPos = targetNape.Position + Vector3.new(0, Config.FlyHeight, 0)
				if bp and bp.Parent then bp.Position = targetPos end
				if (rootPart.Position - targetPos).Magnitude < 15 then break end
				task.wait(0.1)
				timeout += 0.1
			end

			if not isAlive() then break end

			-- 3. GIAI ĐOẠN 2: Khống chế CFrame Nape & Kích hoạt Auto Click
			local clickTimeout = 0
			while isAlive() and not isNapeDead(targetNape) and clickTimeout < 10 do
				if bp and bp.Parent then
					bp.Position = rootPart.Position -- Khóa chặt nhân vật lơ lửng tại chỗ
				end

				-- Đồng bộ vị trí bẻ cong Nape ra thẳng hướng ngực người chơi
				pcall(function()
					targetNape.CFrame = getNapeInFrontCFrame(rootPart)
				end)

				-- Thực hiện giả lập Click ảo qua VirtualInputManager
				pcall(function()
					local VIM = game:GetService("VirtualInputManager")
					local screenPos = workspace.CurrentCamera:WorldToScreenPoint(targetNape.Position)
					VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
					task.wait(0.04)
					VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
				end)

				task.wait(0.06)
				clickTimeout += 0.06
			end

			-- Gỡ Highlight khi Titan bị hạ gục
			removeHighlight()

			if bp and bp.Parent then bp:Destroy() end
			if bg and bg.Parent then bg:Destroy() end

			task.wait(0)
		end

		-- Tự động dọn dẹp bộ dời vị trí nếu thoát khỏi vòng lặp
		CombatFarm.Stop()
	end)
end

function CombatFarm.Stop()
	-- Thay đổi Session ID để phá vỡ vòng Loop đang chạy ngầm
	Config.FarmSessionId += 1
	
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then removeFly(rootPart) end
	end
	removeHighlight()
end

return CombatFarm