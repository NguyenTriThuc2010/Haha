-- [[ BLADE / REFILL FINDER SCRIPT ]]
-- Quét ReplicatedStorage và Workspace để tìm các đối tượng liên quan đến việc thay kiếm / nạp gas

local searchTerms = {"blade", "refill", "reload", "equip", "supply", "gas", "interact", "weapon"}
local remotes = {}
local prompts = {}
local tools = {}
local other = {}

local function scan(instance)
	for _, desc in ipairs(instance:GetDescendants()) do
		local success, name = pcall(function() return string.lower(desc.Name) end)
		if success and name then
			local isMatch = false
			for _, term in ipairs(searchTerms) do
				if string.find(name, term) then
					isMatch = true
					break
				end
			end
			
			if isMatch then
				local path = desc:GetFullName()
				local className = desc.ClassName
				local entry = "- " .. desc.Name .. " [" .. className .. "] -> Path: " .. path
				
				if className == "RemoteEvent" or className == "RemoteFunction" then
					table.insert(remotes, entry)
				elseif className == "ProximityPrompt" then
					table.insert(prompts, entry)
				elseif className == "Tool" then
					table.insert(tools, entry)
				else
					if #other < 100 then -- Giới hạn tránh tràn bộ nhớ
						table.insert(other, entry)
					end
				end
			end
		end
	end
end

pcall(function() scan(game:GetService("ReplicatedStorage")) end)
pcall(function() scan(workspace) end)

local result = {}
table.insert(result, "=== KẾT QUẢ TÌM KIẾM THAY KIẾM / REFILL ===\n\n")

table.insert(result, ">>> 1. REMOTE EVENTS / FUNCTIONS (Dùng để gửi lệnh thay kiếm lên Server):\n")
if #remotes > 0 then
	table.insert(result, table.concat(remotes, "\n") .. "\n")
else
	table.insert(result, "(Không tìm thấy Remote nào liên quan)\n")
end

table.insert(result, "\n>>> 2. PROXIMITY PROMPTS (Nút bấm tương tác trong game):\n")
if #prompts > 0 then
	table.insert(result, table.concat(prompts, "\n") .. "\n")
else
	table.insert(result, "(Không tìm thấy ProximityPrompt nào liên quan)\n")
end

table.insert(result, "\n>>> 3. TOOLS (Vũ khí đang cầm):\n")
if #tools > 0 then
	table.insert(result, table.concat(tools, "\n") .. "\n")
else
	table.insert(result, "(Không tìm thấy Tool nào liên quan)\n")
end

table.insert(result, "\n>>> 4. CÁC ĐỐI TƯỢNG KHÁC (Parts, Models...):\n")
if #other > 0 then
	table.insert(result, table.concat(other, "\n") .. "\n")
else
	table.insert(result, "(Không tìm thấy đối tượng nào)\n")
end

local finalResult = table.concat(result)

-- [[ KHỞI TẠO GUI ĐỂ COPY ]]
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local parent = game:GetService("CoreGui") or player:WaitForChild("PlayerGui")

local oldGui = parent:FindFirstChild("RefillFinderGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RefillFinderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = parent

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 580, 0, 420)
mainFrame.Position = UDim2.new(0.5, -290, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -150, 0, 40)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🔍 Tìm kiếm phương thức Thay Kiếm / Refill"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

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

task.spawn(function()
	task.wait(0.2)
	if textBox and scrollFrame then
		scrollFrame.CanvasSize = UDim2.new(0, textBox.TextBounds.X + 20, 0, textBox.TextBounds.Y + 20)
	end
end)
