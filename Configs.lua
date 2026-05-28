-- [[ CONFIG MODULE ]]
-- Vị trí: TitansHub -> Config (ModuleScript)

local Config = {
	-- ===== FARM =====
	FarmActive    = false,
	FlyHeight     = 50,
	HeightOptions = {30, 50, 80, 120},
	HeightIndex   = 2,

	-- ===== WALL VISUAL =====
	WallEnabled   = true,

	-- ===== CRITICAL HOOK =====
	CritEnabled   = true,       -- Always Crit (metatable hook)

	-- ===== AUTO HEAL =====
	HealEnabled   = true,       -- Tự động dùng Bandage khi máu thấp
	HealThreshold = 50,         -- % máu để kích hoạt (mặc định 50%)

	-- ===== ANTI-AFK =====
	AntiAFKEnabled = true,      -- Chống AFK

	-- ===== HITBOX EXTENDER =====
	HitboxEnabled = true,       -- Mở rộng hitbox của nhân vật
	HitboxSize    = 25,         -- Kích thước mở rộng (studs)

	-- ===== AUTO REFILL =====
	RefillEnabled = true,       -- Tự động nạp Gas / Blade
	GasMin        = 20,         -- % Gas tối thiểu trước khi refill
	BladeMin      = 1,          -- Số lưỡi kiếm tối thiểu trước khi refill

	-- ===== AUTO DODGE =====
	DodgeEnabled  = true,       -- Tự động né đòn titan

	-- ===== SESSION GUARD =====
	-- Chống trùng loop khi bật/tắt liên tục
	_sessionToken = 0,
}

function Config:NewSession()
	self._sessionToken = self._sessionToken + 1
	return self._sessionToken
end

function Config:IsValidSession(token)
	return token == self._sessionToken
end

return Config
