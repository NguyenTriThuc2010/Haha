-- [[ CRIT HOOK MODULE ]]
-- Dùng metatable __namecall hook để chèn Crit = true vào mọi remote attack
-- Tương thích: Synapse X, KRNL, Delta, Fluxus (cần môi trường hỗ trợ getrawmetatable)

local CritHook = {}

local Config = getgenv().RequireModule("Configs.lua")

local _hooked   = false
local _oldNamecall = nil

-- =============================================
-- KHỞI ĐỘNG HOOK
-- =============================================
function CritHook.Start()
	if _hooked then return end
	if not pcall(function() return getrawmetatable(game) end) then
		warn("[CritHook] Executor không hỗ trợ getrawmetatable – bỏ qua.")
		return
	end

	local mt = getrawmetatable(game)
	_oldNamecall = mt.__namecall

	setreadonly(mt, false)

	mt.__namecall = newcclosure(function(self, ...)
		local method = getnamecallmethod()
		local args   = { ... }

		-- Chặn các lời gọi FireServer để chèn Crit
		if Config.CritEnabled and method == "FireServer" then
			for _, v in ipairs(args) do
				if type(v) == "table" then
					-- Chèn crit flag vào packet
					v["Crit"]           = true
					v["CritMultiplier"] = 2.5
					-- Nhân thêm 20% damage nếu có
					if type(v["Damage"]) == "number" then
						v["Damage"] = v["Damage"] * 1.2
					end
				end
			end
		end

		-- Tương tự cho InvokeServer
		if Config.CritEnabled and method == "InvokeServer" then
			for _, v in ipairs(args) do
				if type(v) == "table" then
					v["Crit"]           = true
					v["CritMultiplier"] = 2.5
				end
			end
		end

		return _oldNamecall(self, unpack(args))
	end)

	setreadonly(mt, true)
	_hooked = true
	print("[CritHook] ✅ Critical Hook: ACTIVE")
end

-- =============================================
-- GỠ HOOK (khi cần tắt hoàn toàn)
-- =============================================
function CritHook.Stop()
	if not _hooked or not _oldNamecall then return end

	local mt = getrawmetatable(game)
	setreadonly(mt, false)
	mt.__namecall = _oldNamecall
	setreadonly(mt, true)

	_hooked = false
	_oldNamecall = nil
	print("[CritHook] 🔴 Critical Hook: DISABLED")
end

return CritHook
