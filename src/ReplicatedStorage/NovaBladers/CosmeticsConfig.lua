local CosmeticsConfig = {
	DEFAULT_TRAIL = "Nova",
	DEFAULT_ARENA_SKIN = "Midnight",

	TRAILS = {
		Nova = {
			name = "Nova",
			color = Color3.fromRGB(80, 140, 255),
			accent = Color3.fromRGB(180, 220, 255),
			minSpeed = 14,
		},
		Blaze = {
			name = "Blaze",
			color = Color3.fromRGB(255, 90, 40),
			accent = Color3.fromRGB(255, 200, 100),
			minSpeed = 14,
		},
		Frost = {
			name = "Frost",
			color = Color3.fromRGB(120, 210, 255),
			accent = Color3.fromRGB(230, 250, 255),
			minSpeed = 14,
		},
		Volt = {
			name = "Volt",
			color = Color3.fromRGB(255, 220, 70),
			accent = Color3.fromRGB(255, 255, 160),
			minSpeed = 14,
		},
	},

	ARENA_SKINS = {
		Midnight = {
			name = "Midnight",
			floor = Color3.fromRGB(30, 35, 48),
			bowl = Color3.fromRGB(40, 48, 62),
			bowlRim = Color3.fromRGB(45, 55, 75),
			rim = Color3.fromRGB(80, 140, 255),
			platform = Color3.fromRGB(55, 62, 80),
			skyMarker = Color3.fromRGB(100, 160, 255),
		},
		Crimson = {
			name = "Crimson",
			floor = Color3.fromRGB(38, 22, 28),
			bowl = Color3.fromRGB(52, 28, 35),
			bowlRim = Color3.fromRGB(70, 35, 45),
			rim = Color3.fromRGB(255, 80, 60),
			platform = Color3.fromRGB(65, 40, 48),
			skyMarker = Color3.fromRGB(255, 120, 90),
		},
		Aurora = {
			name = "Aurora",
			floor = Color3.fromRGB(22, 32, 42),
			bowl = Color3.fromRGB(30, 48, 55),
			bowlRim = Color3.fromRGB(40, 65, 72),
			rim = Color3.fromRGB(80, 255, 200),
			platform = Color3.fromRGB(45, 62, 70),
			skyMarker = Color3.fromRGB(120, 255, 220),
		},
	},
}

function CosmeticsConfig.getTrail(id)
	return CosmeticsConfig.TRAILS[id] or CosmeticsConfig.TRAILS[CosmeticsConfig.DEFAULT_TRAIL]
end

function CosmeticsConfig.getArenaSkin(id)
	return CosmeticsConfig.ARENA_SKINS[id] or CosmeticsConfig.ARENA_SKINS[CosmeticsConfig.DEFAULT_ARENA_SKIN]
end

return CosmeticsConfig
