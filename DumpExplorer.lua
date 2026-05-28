-- [[ EXPLORER DUMPER SCRIPT WITH GUI ]]
-- Tự động quét cấu trúc Explorer của game và hiển thị GUI chứa text để copy

local maxDepth = 8

local function buildTree(instance, depth)
	depth = depth or 0
	if depth > maxDepth then return "" end
	
	local indent = string.rep("  ", depth)
	local success, children = pcall(function() return instance:GetChildren() end)
	if not success or not children then return "" end
	
	local lines = {}
	
	-- Nhóm các con trùng tên và trùng ClassName để file gọn gàng
	local groups = {}
	local orderedKeys = {}
	
	for _, child in ipairs(children) do
		local successName, name = pcall(function() return child.Name end)
		local successClass, className = pcall(function() return child.ClassName end)
		if successName and successClass then
			local key = name .. "||" .. className
			if not groups[key] then
				groups[key] = {
					name = name,
					className = className,
					instances = {}
				}
				table.insert(orderedKeys, key)
			end
			table.insert(groups[key].instances, child)
		end
	end
	
	for _, key in ipairs(orderedKeys) do
		local group = groups[key]
		local count = #group.instances
		local nameStr = group.name .. " [" .. group.className .. "]"
		if count > 1 then
			nameStr = nameStr .. " (x" .. count .. ")"
		end
		
		table.insert(lines, indent .. "- " .. nameStr .. "\n")
		
		-- Duyệt sâu xuống dưới
		if count == 1 then
			local childTree = buildTree(group.instances[1], depth + 1)
			table.insert(lines, childTree)
		elseif count > 1 then
			local firstChild = group.instances[1]
			local hasChildren = false
			pcall(function()
				if #firstChild:GetChildren() > 0 then
					hasChildren = true
				end
			end)
			if hasChildren then
				table.insert(lines, indent .. "  [Cấu trúc mẫu của " .. group.name .. "]:\n")
				local childTree = buildTree(firstChild, depth + 2)
				table.insert(lines, childTree)
			end
		end
	end
	
	return table.concat(lines)
end

local output = {}
table.insert(output, "=== GAME EXPLORER STRUCTURE DUMP ===\n")
table.insert(output, "Thời gian quét: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
table.insert(output, "Game ID: " .. tostring(game.GameId) .. " | Place ID: " .. tostring(game.PlaceId) .. "\n")
table.insert(output, "====================================\n\n")

local services = {
	{name = "Workspace", service = workspace},
	{name = "ReplicatedStorage", service = game:GetService("ReplicatedStorage")},
	{name = "StarterGui", service = game:GetService("StarterGui")},
	{name = "StarterPlayer", service = game:GetService("StarterPlayer")},
	{name = "Players", service = game:GetService("Players")},
	{name = "Lighting", service = game:GetService("Lighting")}
}

for _, item in ipairs(services) do
	if item.service then
		table.insert(output, ">>> SERVICE: " .. item.name .. "\n")
		local serviceTree = buildTree(item.service, 1)
		table.insert(output, serviceTree)
		table.insert(output, "\n" .. string.rep("-", 40) .. "\n\n")
	end
end

local finalResult = table.concat(output)

-- [[ KHỞI TẠO GIAO DIỆN GUI ĐỂ COPY ]]
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local parent = game:GetService("CoreGui") or player:WaitForChild("PlayerGui")

-- Dọn dẹp GUI cũ nếu có
local oldGui = parent:FindFirstChild("ExplorerDumperGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExplorerDumperGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = parent

-- Khung nền chính
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 550, 0, 420)
mainFrame.Position = UDim2.new(0.5, -275, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

-- Tiêu đề GUI
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -150, 0, 40)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "⚔️ Explorer Dumper - Cấu trúc Game"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

-- Nút Đóng GUI
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

-- Nút Copy Nhanh (Sử dụng setclipboard của Executor)
local copyBtn = Instance.new("TextButton")
copyBtn.Name = "CopyBtn"
copyBtn.Size = UDim2.new(0, 100, 0, 30)
copyBtn.Position = UDim2.new(1, -145, 0, 5)
copyBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 70)
copyBtn.Text = "📋 Copy All"
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 12
copyBtn.Parent = mainFrame

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 6)
copyCorner.Parent = copyBtn

copyBtn.MouseButton1Click:Connect(function()
	local setclip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
	if setclip then
		setclip(finalResult)
		copyBtn.Text = "Đã Copy! ✓"
		task.wait(1.5)
		copyBtn.Text = "📋 Copy All"
	else
		copyBtn.Text = "Dùng Ctrl+A"
		task.wait(1.5)
		copyBtn.Text = "📋 Copy All"
	end
end)

-- Khung Cuộn trang (ScrollingFrame)
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ScrollFrame"
scrollFrame.Size = UDim2.new(1, -20, 1, -60)
scrollFrame.Position = UDim2.new(0, 10, 0, 50)
scrollFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
scrollFrame.BorderSizePixel = 0
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.ScrollBarThickness = 8
scrollFrame.Parent = mainFrame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 8)
scrollCorner.Parent = scrollFrame

-- TextBox chứa Text để bôi đen/sao chép
local textBox = Instance.new("TextBox")
textBox.Name = "TextBox"
textBox.Size = UDim2.new(1, -10, 1, 0)
textBox.Position = UDim2.new(0, 5, 0, 0)
textBox.BackgroundTransparency = 1
textBox.MultiLine = true
textBox.ClearTextOnFocus = false
textBox.TextEditable = true
textBox.Text = finalResult
textBox.TextColor3 = Color3.fromRGB(220, 220, 220)
textBox.TextSize = 12
textBox.Font = Enum.Font.Code
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.TextYAlignment = Enum.TextYAlignment.Top
textBox.Parent = scrollFrame

-- Tự động giãn khung cuộn theo lượng chữ
task.spawn(function()
	task.wait(0.2)
	if textBox and scrollFrame then
		scrollFrame.CanvasSize = UDim2.new(0, textBox.TextBounds.X + 20, 0, textBox.TextBounds.Y + 20)
	end
end)
