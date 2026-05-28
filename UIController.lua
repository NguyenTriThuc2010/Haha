-- [[ UI CONTROLLER MODULE ]]
-- Vị trí: TitansHub -> Modules -> UIController (ModuleScript)
-- Giao diện đầy đủ: Farm, CritHook, AutoHeal, AntiAFK, HitboxExtender, AutoRefill, AutoDodge

local UIController = {}

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local player       = Players.LocalPlayer

local Config       = getgenv().RequireModule("Configs.lua")

-- Màu sắc chủ đạo
local COLOR_BG       = Color3.fromRGB(12, 12, 18)
local COLOR_TITLE    = Color3.fromRGB(180, 30, 30)
local COLOR_ON       = Color3.fromRGB(50, 200, 100)
local COLOR_OFF      = Color3.fromRGB(90, 90, 100)
local COLOR_TEXT     = Color3.fromRGB(230, 230, 230)
local COLOR_LABEL    = Color3.fromRGB(160, 160, 175)
local COLOR_ACCENT   = Color3.fromRGB(200, 50, 50)

local screenGui  = nil
local mainFrame  = nil
local menuOpen   = false

-- Bảng tra callback bật/tắt từng tính năng (sẽ được nối với MainLoader)
UIController.Callbacks = {}

-- =============================================
-- TIỆN ÍCH TẠO UI
-- =============================================

local function makeCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function makeStroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color        = color or COLOR_ACCENT
	s.Thickness    = thickness or 1.2
	s.Transparency = transparency or 0.3
	s.Parent       = parent
	return s
end

local function makePadding(parent, px)
	local p = Instance.new("UIPadding")
	p.PaddingLeft   = UDim.new(0, px)
	p.PaddingRight  = UDim.new(0, px)
	p.PaddingTop    = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
end

local function makeListLayout(parent, spacing)
	local l = Instance.new("UIListLayout")
	l.Padding          = UDim.new(0, spacing or 6)
	l.SortOrder        = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Parent = parent
	return l
end

-- Label đơn giản
local function makeLabel(parent, text, size, color, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size                = UDim2.new(1, -16, 0, size or 18)
	lbl.BackgroundTransparency = 1
	lbl.Text                = text
	lbl.TextColor3          = color or COLOR_LABEL
	lbl.TextSize            = 13
	lbl.Font                = Enum.Font.GothamSemibold
	lbl.TextXAlignment      = Enum.TextXAlignment.Left
	lbl.LayoutOrder         = order or 0
	lbl.Parent              = parent
	return lbl
end

-- Toggle Button với chỉ báo trạng thái
local function makeToggle(parent, label, initState, order, onToggle)
	local row = Instance.new("Frame")
	row.Size                = UDim2.new(1, -12, 0, 34)
	row.BackgroundColor3    = Color3.fromRGB(22, 22, 32)
	row.BorderSizePixel     = 0
	row.LayoutOrder         = order
	row.Parent              = parent
	makeCorner(row, 7)

	-- Tên tính năng
	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, -60, 1, 0)
	lbl.Position           = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = label
	lbl.TextColor3         = COLOR_TEXT
	lbl.TextSize           = 13
	lbl.Font               = Enum.Font.Gotham
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.Parent             = row

	-- Chỉ báo ON/OFF
	local indicator = Instance.new("Frame")
	indicator.Size             = UDim2.new(0, 40, 0, 20)
	indicator.Position         = UDim2.new(1, -50, 0.5, -10)
	indicator.BackgroundColor3 = initState and COLOR_ON or COLOR_OFF
	indicator.BorderSizePixel  = 0
	indicator.Parent           = row
	makeCorner(indicator, 10)

	local indText = Instance.new("TextLabel")
	indText.Size               = UDim2.new(1, 0, 1, 0)
	indText.BackgroundTransparency = 1
	indText.Text               = initState and "ON" or "OFF"
	indText.TextColor3         = Color3.fromRGB(255, 255, 255)
	indText.TextSize           = 11
	indText.Font               = Enum.Font.GothamBold
	indText.Parent             = indicator

	-- Toggle logic
	local state = initState
	local function toggle()
		state = not state
		local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
		TweenService:Create(indicator, tweenInfo, {
			BackgroundColor3 = state and COLOR_ON or COLOR_OFF
		}):Play()
		indText.Text = state and "ON" or "OFF"
		if onToggle then onToggle(state) end
	end

	row.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			toggle()
		end
	end)

	return row, function() return state end
end

-- =============================================
-- DRAGGABLE
-- =============================================

local function makeDraggable(frame)
	local dragging, dragStart, startPos = false, nil, nil

	frame.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = inp.Position
			startPos  = frame.Position
		end
	end)

	frame.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UIS.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
			or inp.UserInputType == Enum.UserInputType.Touch) then
			local delta = inp.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- =============================================
-- XÂY DỰNG UI
-- =============================================

function UIController.Init()
	-- Tạo ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name              = "TitansMenu"
	screenGui.ResetOnSpawn      = false
	screenGui.DisplayOrder      = 999999
	screenGui.IgnoreGuiInset    = true
	screenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
	screenGui.Parent            = player.PlayerGui

	-- ===== TOGGLE BUTTON (nút nhỏ góc trái) =====
	local openBtn = Instance.new("TextButton")
	openBtn.Name             = "OpenButton"
	openBtn.Size             = UDim2.new(0, 42, 0, 42)
	openBtn.Position         = UDim2.new(0, 10, 0.5, -21)
	openBtn.BackgroundColor3 = COLOR_TITLE
	openBtn.Text             = "⚔"
	openBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	openBtn.TextSize         = 20
	openBtn.Font             = Enum.Font.GothamBold
	openBtn.BorderSizePixel  = 0
	openBtn.ZIndex           = 10
	openBtn.Parent           = screenGui
	makeCorner(openBtn, 12)
	makeStroke(openBtn, COLOR_ACCENT, 1.5, 0.2)
	makeDraggable(openBtn)

	-- ===== MAIN FRAME =====
	mainFrame = Instance.new("Frame")
	mainFrame.Name              = "MainFrame"
	mainFrame.Size              = UDim2.new(0, 240, 0, 380)
	mainFrame.Position          = UDim2.new(0, 60, 0.5, -190)
	mainFrame.BackgroundColor3  = COLOR_BG
	mainFrame.BackgroundTransparency = 0.08
	mainFrame.BorderSizePixel   = 0
	mainFrame.Visible           = false
	mainFrame.ZIndex            = 5
	mainFrame.Parent            = screenGui
	makeCorner(mainFrame, 12)
	makeStroke(mainFrame, COLOR_ACCENT, 1.5, 0.25)
	makeDraggable(mainFrame)

	-- ===== TITLE BAR =====
	local titleBar = Instance.new("Frame")
	titleBar.Size             = UDim2.new(1, 0, 0, 42)
	titleBar.BackgroundColor3 = COLOR_TITLE
	titleBar.BorderSizePixel  = 0
	titleBar.ZIndex           = 6
	titleBar.Parent           = mainFrame
	makeCorner(titleBar, 12)

	-- Patch bottom corners of titleBar
	local patchBar = Instance.new("Frame")
	patchBar.Size             = UDim2.new(1, 0, 0, 12)
	patchBar.Position         = UDim2.new(0, 0, 1, -12)
	patchBar.BackgroundColor3 = COLOR_TITLE
	patchBar.BorderSizePixel  = 0
	patchBar.ZIndex           = 6
	patchBar.Parent           = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size               = UDim2.new(1, -10, 1, 0)
	titleLabel.Position           = UDim2.new(0, 14, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text               = "⚔  TITANS HUB"
	titleLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize           = 15
	titleLabel.Font               = Enum.Font.GothamBold
	titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
	titleLabel.ZIndex             = 7
	titleLabel.Parent             = titleBar

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size               = UDim2.new(0, 60, 1, 0)
	versionLabel.Position           = UDim2.new(1, -65, 0, 0)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text               = "v2.0"
	versionLabel.TextColor3         = Color3.fromRGB(255, 200, 200)
	versionLabel.TextSize           = 11
	versionLabel.Font               = Enum.Font.Gotham
	versionLabel.ZIndex             = 7
	versionLabel.Parent             = titleBar

	-- ===== SCROLL FRAME cho danh sách nút =====
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name                    = "ToggleScroll"
	scroll.Size                    = UDim2.new(1, 0, 1, -46)
	scroll.Position                = UDim2.new(0, 0, 0, 44)
	scroll.BackgroundTransparency  = 1
	scroll.BorderSizePixel         = 0
	scroll.ScrollBarThickness      = 3
	scroll.ScrollBarImageColor3    = COLOR_ACCENT
	scroll.CanvasSize              = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize     = Enum.AutomaticSize.Y
	scroll.ZIndex                  = 6
	scroll.Parent                  = mainFrame
	makePadding(scroll, 8)
	makeListLayout(scroll, 6)

	-- ===== NHÓM FARM =====
	makeLabel(scroll, "── FARM ──", 16, COLOR_ACCENT, 1)

	makeToggle(scroll, "🌀  Nape Farm", Config.FarmActive, 2, function(on)
		Config.FarmActive = on
		local cb = UIController.Callbacks["Farm"]
		if cb then cb(on) end
	end)

	-- ===== NHÓM COMBAT =====
	makeLabel(scroll, "── COMBAT ──", 16, COLOR_ACCENT, 10)

	makeToggle(scroll, "💥  Always Crit", Config.CritEnabled, 11, function(on)
		Config.CritEnabled = on
		local cb = UIController.Callbacks["Crit"]
		if cb then cb(on) end
	end)

	makeToggle(scroll, "📐  Hitbox Extender", Config.HitboxEnabled, 12, function(on)
		Config.HitboxEnabled = on
		local cb = UIController.Callbacks["Hitbox"]
		if cb then cb(on) end
	end)

	makeToggle(scroll, "💨  Auto Dodge", Config.DodgeEnabled, 13, function(on)
		Config.DodgeEnabled = on
		local cb = UIController.Callbacks["Dodge"]
		if cb then cb(on) end
	end)

	-- ===== NHÓM SURVIVAL =====
	makeLabel(scroll, "── SURVIVAL ──", 16, COLOR_ACCENT, 20)

	makeToggle(scroll, "💊  Auto Heal", Config.HealEnabled, 21, function(on)
		Config.HealEnabled = on
		local cb = UIController.Callbacks["Heal"]
		if cb then cb(on) end
	end)

	makeToggle(scroll, "⛽  Auto Refill", Config.RefillEnabled, 22, function(on)
		Config.RefillEnabled = on
		local cb = UIController.Callbacks["Refill"]
		if cb then cb(on) end
	end)

	-- ===== NHÓM MISC =====
	makeLabel(scroll, "── MISC ──", 16, COLOR_ACCENT, 30)

	makeToggle(scroll, "⏰  Anti-AFK", Config.AntiAFKEnabled, 31, function(on)
		Config.AntiAFKEnabled = on
		local cb = UIController.Callbacks["AntiAFK"]
		if cb then cb(on) end
	end)

	makeToggle(scroll, "🧱  Wall Visual", Config.WallEnabled, 32, function(on)
		Config.WallEnabled = on
	end)

	-- ===== STATUS BAR =====
	local statusBar = Instance.new("Frame")
	statusBar.Size             = UDim2.new(1, -16, 0, 22)
	statusBar.Position         = UDim2.new(0, 8, 1, -28)
	statusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	statusBar.BorderSizePixel  = 0
	statusBar.ZIndex           = 6
	statusBar.Parent           = mainFrame
	makeCorner(statusBar, 6)

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Name               = "StatusLabel"
	statusLbl.Size               = UDim2.new(1, -8, 1, 0)
	statusLbl.Position           = UDim2.new(0, 6, 0, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text               = "● READY"
	statusLbl.TextColor3         = COLOR_ON
	statusLbl.TextSize           = 11
	statusLbl.Font               = Enum.Font.GothamSemibold
	statusLbl.TextXAlignment     = Enum.TextXAlignment.Left
	statusLbl.ZIndex             = 7
	statusLbl.Parent             = statusBar

	UIController.StatusLabel = statusLbl

	-- ===== TOGGLE MỞ/ĐÓNG MENU (RightShift hoặc nhấn nút) =====
	local function toggleMenu()
		menuOpen = not menuOpen
		mainFrame.Visible = menuOpen
		if menuOpen then
			local tween = TweenService:Create(mainFrame,
				TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{Size = UDim2.new(0, 240, 0, 380)}
			)
			mainFrame.Size = UDim2.new(0, 240, 0, 0)
			tween:Play()
		end
	end

	openBtn.MouseButton1Click:Connect(toggleMenu)

	UIS.InputBegan:Connect(function(inp, gp)
		if gp then return end
		if inp.KeyCode == Enum.KeyCode.RightShift then
			toggleMenu()
		end
	end)

	print("[UIController] ✅ UI Khởi tạo thành công – Nhấn RightShift hoặc ⚔ để mở menu")
end

-- =============================================
-- CẬP NHẬT STATUS
-- =============================================
function UIController.SetStatus(text, color)
	if UIController.StatusLabel then
		UIController.StatusLabel.Text      = "● " .. text
		UIController.StatusLabel.TextColor3 = color or COLOR_ON
	end
end

return UIController
