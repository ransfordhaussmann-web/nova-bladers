local HubConfig = {
	-- Offset from arena so hub and bowl can coexist in one place.
	HUB_ORIGIN = Vector3.new(0, 0, 200),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	ARENA_SPAWN = Vector3.new(0, 6, 0),

	ZONES = {
		ArenaGate = {
			offset = Vector3.new(0, 0, 52),
			size = Vector3.new(14, 12, 6),
			label = "Arena-Tor",
			prompt = "Arena betreten",
			colorKey = "Gate",
		},
		BeyShop = {
			offset = Vector3.new(-42, 0, 0),
			size = Vector3.new(12, 10, 12),
			label = "Bey-Shop",
			prompt = "Bey wählen",
			colorKey = "Shop",
		},
		HallOfFame = {
			offset = Vector3.new(42, 0, 0),
			size = Vector3.new(12, 10, 12),
			label = "Ruhmeshalle",
			prompt = "Bestenliste ansehen",
			colorKey = "Hall",
		},
	},

	COLORS = {
		Floor = Color3.fromRGB(42, 48, 68),
		Rim = Color3.fromRGB(28, 32, 48),
		Gate = Color3.fromRGB(255, 120, 60),
		Shop = Color3.fromRGB(80, 140, 255),
		Hall = Color3.fromRGB(255, 200, 60),
		Accent = Color3.fromRGB(120, 200, 255),
	},

	HUB_FOLDER_NAME = "NovaHub",
}

function HubConfig.worldPosition(offset)
	return HubConfig.HUB_ORIGIN + offset
end

function HubConfig.spawnPosition()
	return HubConfig.worldPosition(HubConfig.SPAWN_OFFSET)
end

return HubConfig
