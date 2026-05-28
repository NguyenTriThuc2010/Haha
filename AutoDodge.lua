-- [[ AUTO DODGE MODULE ]]
-- Tự động né khi Titan đang tấn công (animation detect + proximity)
-- Cơ chế: Phát hiện Titan đang swing bằng AnimationTrack name / proximity threat

local AutoDodge = {}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config     = getgenv().RequireModule("Configs.lua")
local player     = Players.LocalPlayer

-- Khoảng cách nguy hiểm (studs) – nếu Titan ở gần hơn thì dodge
local DANGER_RADIUS   = 18
-- Khoảng cách an toàn để bay ra
local DODGE_DISTANCE  = 30
-- Cooldown dodge (giây)
local DODGE_COOLDOWN  = 1.5

local _conn     = nil
local _lastDodge = 0
local _dodging  = false

-- Danh sách tên animation titan "đang tấn công"
local ATTACK_ANIM_KEYWORDS = {
	"attack", "swing", "strike", "hit",
	"punch", "slap", "grab", "stomp",
	"smash", "bite"
}

-- =============================================
-- HELPERS
-- =============================================

-- Kiểm tra Titan (NPC, không phải player) đang play anim tấn công
local function isTitanAttacking(titanModel)
	local animator = titanModel:FindFirstChildOfClass("Animator")
		or (titanModel:FindFirstChildOfClass("Humanoid")
			and titanModel:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator"))
	if not animator then return false end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local animName = track.Name:lower()
		for _, kw in ipairs(ATTACK_ANIM_KEYWORDS) do
			if animName:find(kw) then
				return true
			end
		end
	end
	return false
end

-- Tìm titan gần nhất đang tấn công
local function findThreat()
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil, nil end

	local playerPos = hrp.Position
	local bestModel = nil
	local bestDist  = DANGER_RADIUS

	for _, obj in ipairs(workspace:GetDescendants()) do
		-- Nape là dấu hiệu của titan trong AOTR
		if obj.Name == "Nape" and obj:IsA("BasePart") then
			local dist = (playerPos - obj.Position).Magnitude
			if dist < bestDist then
				-- Kiểm tra titan đang tấn công
				local model = obj:FindFirstAncestorOfClass("Model")
				if model and model ~= char then
					if isTitanAttacking(model) then
						bestDist  = dist
						bestModel = model
					end
				end
			end
		end
	end

	return bestModel, bestDist
end

-- =============================================
-- DODGE LOGIC
-- =============================================
local function performDodge()
	if _dodging then return end

	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	_dodging = true

	pcall(function()
		-- Tính hướng tránh: ngược lại với hướng titan
		local threat, _ = findThreat()
		local dodgeDir

		if threat then
			local titanPos = threat:FindFirstChild("HumanoidRootPart") and
				threat.HumanoidRootPart.Position or hrp.Position
			dodgeDir = (hrp.Position - titanPos).Unit
		else
			-- Không tìm thấy titan cụ thể, dodge sang phải nhân vật
			dodgeDir = hrp.CFrame.RightVector
		end

		-- Đặt BodyVelocity để dash nhanh
		local oldBV = hrp:FindFirstChild("_DodgeBV")
		if oldBV then oldBV:Destroy() end

		local bv = Instance.new("BodyVelocity")
		bv.Name      = "_DodgeBV"
		bv.Velocity  = (dodgeDir + Vector3.new(0, 0.5, 0)).Unit * DODGE_DISTANCE * 8
		bv.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
		bv.P         = 1e4
		bv.Parent    = hrp

		print("[AutoDodge] 💨 DODGE!")

		task.wait(0.25)  -- Thời gian dash

		-- Dọn dẹp
		if bv and bv.Parent then bv:Destroy() end
	end)

	task.wait(DODGE_COOLDOWN)
	_dodging = false
end

-- =============================================
-- MAIN LOOP
-- =============================================
local function dodgeLoop()
	while true do
		if Config.DodgeEnabled then
			local now = os.clock()
			if (now - _lastDodge) >= DODGE_COOLDOWN then
				local threatModel, _ = findThreat()
				if threatModel then
					_lastDodge = now
					task.spawn(performDodge)
				end
			end
		end
		task.wait(0.1)  -- Kiểm tra 10 lần/giây
	end
end

-- =============================================
-- START / STOP
-- =============================================
function AutoDodge.Start()
	if _conn then _conn:Disconnect() end
	_conn = task.spawn(dodgeLoop)
	print("[AutoDodge] ✅ Auto Dodge: ACTIVE (Radius: " .. DANGER_RADIUS .. " studs)")
end

function AutoDodge.Stop()
	if _conn then
		task.cancel(_conn)
		_conn = nil
	end
	_dodging = false
	print("[AutoDodge] 🔴 Auto Dodge: DISABLED")
end

return AutoDodge
