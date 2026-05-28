-- [[ EXPLORER DUMPER SCRIPT ]]
-- Tự động quét cấu trúc Explorer của game và lưu vào file txt

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

-- Lưu file thông qua hàm ghi file của Executor
if writefile then
	writefile("Roblox_Explorer_Structure.txt", finalResult)
	print("✅ [Explorer Dumper] Đã xuất cấu trúc thành công thành file 'Roblox_Explorer_Structure.txt'!")
	print("📂 Vui lòng truy cập thư mục 'workspace' trong thư mục cài đặt Executor của bạn để mở file.")
else
	warn("❌ [Explorer Dumper] Executor của bạn không hỗ trợ hàm writefile!")
	print("Hãy copy thủ công từ Output Console Roblox dưới đây:")
	print(finalResult)
end
