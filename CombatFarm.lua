-- [[ COMBAT FARM MODULE ]]
-- Vị trí: TitansHub -> Modules -> CombatFarm (ModuleScript)

local CombatFarm = {}

local Players    = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Config     = getgenv().RequireModule("Configs.lua")
local player     = Players.LocalPlayer

-- Quản lý Highlight nội bộ
local currentNapeHighlight = nil
local currentSelectionBox  = nil

-- =============================================
-- CÁC HÀM TIỆN ÍCH NỘI BỘ
-- =============================================

local function findNapeInTitan(titanModel)
	-- AOTR: Hitboxes -> Hit -> Nape
	local hitboxes = titanModel:FindFirstChild("Hitboxes")
	if hitboxes then
		local hitFolder = hitboxes:FindFirstChild("Hit")
		if hitFolder then
			local nape = hitFolder:FindFirstChild("Nape")
			if nape then return nape end
		end
	end
	-- Fallback: tìm thẳng
	return titanModel:FindFirstChild("Nape", true)
end

local function isNapeDead(nape)
	return (not nape)
		or (not nape.Parent)
		or (not nape:IsDescendantOf(workspace))
end

local function attachHighlight(napePart)
	-- Dọn cái cũ
	if currentNapeHighlight and currentNapeHighlight.Parent then
		currentNapeHighlight:Destroy()
	end
	if currentSelectionBox and currentSelectionBox.Parent then
		currentSelectionBox:Destroy()
	end

	-- SelectionBox viền đỏ
	local hl = Instance.new("SelectionBox")
	hl.Adornee          = napePart
	hl.Color3           = Color3.fromRGB(255, 50, 50)
	hl.LineThickness    = 0.08
	hl.SurfaceTransparency = 0.4
	hl.SurfaceColor3    = Color3.fromRGB(255, 80, 80)
	hl.Parent           = workspace

	-- Neon overlay
	local overlay = Instance.new("Part")
	overlay.Name          = "_NapeOverlay"
	overlay.Anchored      = false
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

-- =============================================
-- FLY SYSTEM
-- =============================================

local function applyFly(rootPart, targetPos)
	-- Dọn cũ
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

-- =============================================
-- SCANNER – TÌM TITAN GẦN NHẤT
-- =============================================

function CombatFarm.GetBestTarget()
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local best, minDist = nil, math.huge

	for _, v in ipairs(workspace:GetDescendants()) do
		if v.Name == "Nape" and v:IsA("BasePart") then
			-- Bỏ qua Nape đã chết (ẩn hoặc Transparency = 1)
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

-- =============================================
-- AUTO ATTACK – Kích hoạt Tool kiếm
-- =============================================

local function doAttack()
	local char = player.Character
	if not char then return end

	-- Tìm Tool kiếm đang cầm
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then
		-- Equip tool từ Backpack
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

-- =============================================
-- VÒNG LẶP FARM CHÍNH
-- =============================================

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

			-- Tìm Nape gần nhất
			local nape = CombatFarm.GetBestTarget()

			if not nape or isNapeDead(nape) then
				removeHighlight()
				removeFly(hrp)
				print("[CombatFarm] 🔍 Không tìm thấy Titan – Chờ...")
				task.wait(2)
				continue
			end

			-- Highlight Nape
			attachHighlight(nape)

			-- Tính toán vị trí bay – ở trên Nape theo FlyHeight
			local flyHeight = Config.FlyHeight
			local targetPos = nape.Position + Vector3.new(0, flyHeight, 0)

			-- Áp Fly
			applyFly(hrp, targetPos)

			-- Chờ đến khi đủ gần để đánh
			local strikeRange = 20
			local timeout     = 8
			local elapsed     = 0

			while elapsed < timeout and Config.FarmActive do
				local dist = (hrp.Position - nape.Position).Magnitude

				-- Cập nhật hướng nhìn về phía Nape
				local bg = hrp:FindFirstChild("_FarmBodyGyro")
				if bg then
					bg.CFrame = CFrame.lookAt(hrp.Position, nape.Position)
				end

				if dist <= strikeRange then
					break
				end

				if isNapeDead(nape) then break end

				elapsed  = elapsed + 0.1
				task.wait(0.1)
			end

			-- Tấn công nếu đủ gần
			if not isNapeDead(nape) then
				local dist = (hrp.Position - nape.Position).Magnitude
				if dist <= strikeRange then
					doAttack()
					task.wait(0.3)
					doAttack()  -- Double tap để chắc chắn
				end
			end

			task.wait(0.2)
		end

		-- Dọn dẹp khi thoát loop
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then removeFly(hrp) end
		removeHighlight()
		print("[CombatFarm] 🔴 Farm Loop: DỪNG")
	end)
end

function CombatFarm.StopFarm()
	Config.FarmActive = false
	Config:NewSession()  -- Vô hiệu hóa session cũ

	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then removeFly(hrp) end
	removeHighlight()

	print("[CombatFarm] 🔴 Farm: DỪNG")
end

return CombatFarm
