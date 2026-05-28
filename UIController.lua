-- [[ UI CONTROLLER MODULE ]]
-- Vị trí: TitansHub -> Modules -> UIController (ModuleScript)

local UIController = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

-- Bảng lưu trữ các Instance của nút bấm để MainLoader có thể lấy ra
local buttons = {}
local backdrop = nil
local menuVisible = false

function UIController.Init()
	-- 1. Tạo ScreenGui chính
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TitansMenu"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 999999
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player.PlayerGui

	-- 2. Khung nền chính (Backdrop)
	backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(0, 220, 0, 280)
	backdrop.Position = UDim2.new(0, 20, 0.5, -140)
	backdrop.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	backdrop.BackgroundTransparency = 0.2
	backdrop.BorderSizePixel = 0
	backdrop.Visible = false -- Mặc định ẩn, nhấn RightShift để hiện
	backdrop.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = backdrop

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 30, 30)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = backdrop

	-- 3. Thanh tiêu đề (TitleBar)
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = backdrop

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 12)
	titleCorner.Parent = titleBar

	local titleFix = Instance.new("Frame")
	titleFix.Size = UDim2.new(1, 0, 0, 12)
	titleFix.Position = UDim2.new(0, 0, 1, -12)
	titleFix.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
	titleFix.BorderSizePixel = 0
	titleFix.Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -10, 1, 0)
	titleLabel.Position = UDim2.new(0, 14, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "⚔ TITANS"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 16
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar

	-- 4. Dòng chữ hướng dẫn phím tắt
	local hotkeyHint = Instance.new("TextLabel")
	hotkeyHint.Size = UDim2.new(1, -14, 0, 16)
	hotkeyHint.Position = UDim2.new(0, 14, 0, 44)
	hotkeyHint.BackgroundTransparency = 1
	hotkeyHint.Text = "Phím tắt: RightShift để ẩn/hiện"
	hotkeyHint.TextColor3 = Color3.fromRGB(150, 150, 160)
	hotkeyHint.TextSize = 10
	hotkeyHint.Font = Enum.Font.Gotham
	hotkeyHint.TextXAlignment = Enum.TextXAlignment.Left
	hotkeyHint.Parent = backdrop

	-- 5. Khung chứa danh sách nút bấm (Button List)
	local buttonList = Instance.new("Frame")
	buttonList.Size = UDim2.new(1, -20, 0, 190)
	buttonList.Position = UDim2.new(0, 10, 0, 68)
	buttonList.BackgroundTransparency = 1
	buttonList.Parent = backdrop

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = buttonList

	-- 6. Hàm khởi tạo nhanh một nút bấm (Helper Function)
	local function createButton(id, text, icon, color, order)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 44)
		btn.BackgroundColor3 = color
		btn.BorderSizePixel = 0
		btn.Text = icon .. "  " .. text
		btn.TextColor3 = Color3.fromRGB(230, 230, 235)
		btn.TextSize = 13
		btn.Font = Enum.Font.GothamSemibold
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.AutoButtonColor = false
		btn.LayoutOrder = order
		btn.Parent = buttonList

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn

		local btnPad = Instance.new("UIPadding")
		btnPad.PaddingLeft = UDim.new(0, 12)
		btnPad.Parent = btn

		-- Hiệu ứng Hover chuột mượt mà
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {
				BackgroundColor3 = Color3.fromRGB(
					math.min(color.R * 255 + 20, 255),
					math.min(color.G * 255 + 20, 255),
					math.min(color.B * 255 + 20, 255)
				)
			}):Play()
		end)
		
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {
				BackgroundColor3 = color
			}):Play()
		end)

		buttons[id] = btn -- Lưu vào hệ thống
	end

	-- Tạo 3 nút bấm tương ứng với các ID gọi từ MainLoader
	createButton("FarmNape", "Farm Nape: TẮT", "⚔", Color3.fromRGB(160, 30, 30), 1)
	createButton("ToggleWall", "Hiệu ứng tường: BẬT", "🧱", Color3.fromRGB(30, 60, 100), 2)
	createButton("ChangeHeight", "Độ cao: 50", "📏", Color3.fromRGB(30, 80, 50), 3)

	-- 7. Kích hoạt logic kéo thả (Drag GUI)
	UIController.SetupDragging(titleBar)
end

-- Hàm lấy nút bấm theo ID để MainLoader dùng
function UIController.GetButton(id)
	return buttons[id]
end

-- Hàm cập nhật trạng thái hiển thị của nút bấm (Chữ + Màu sắc)
function UIController.UpdateButton(id, newText, newColor)
	local btn = buttons[id]
	if btn then
		btn.Text = string.sub(btn.Text, 1, 4) .. newText -- Giữ lại icon đầu chuỗi
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = newColor}):Play()
	end
end

-- Logic Ẩn/Hiện Menu bằng hiệu ứng trượt mượt mà (RightShift)
function UIController.ToggleMenu()
	if not backdrop then return end
	menuVisible = not menuVisible
	
	if menuVisible then
		backdrop.Visible = true
		backdrop.Position = UDim2.new(0, -220, 0.5, -140)
		backdrop.BackgroundTransparency = 1
		TweenService:Create(backdrop, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 20, 0.5, -140),
			BackgroundTransparency = 0.2
		}):Play()
	else
		local tween = TweenService:Create(backdrop, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, -220, 0.5, -140),
			BackgroundTransparency = 1
		})
		tween:Play()
		tween.Completed:Connect(function()
			if not menuVisible then backdrop.Visible = false end
		end)
	end
end

-- Logic Kéo thả Menu
function UIController.SetupDragging(dragFrame)
	local UserInputService = game:GetService("UserInputService")
	local dragging, dragStart, startPos

	dragFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = backdrop.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			backdrop.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

return UIController