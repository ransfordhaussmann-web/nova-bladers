local HubConfig = {
	HUB_WORLD_NAME = "HubWorld",
	ARENA_NAME = "Arena",
	HUB_SPAWN_NAME = "HubSpawn",
	ARENA_SPAWN_PREFIX = "Spawn",

	AUTO_BUILD_HUB = true,
	HUB_ORIGIN = Vector3.new(0, 0, -120),
	FLOOR_SIZE = Vector3.new(80, 1, 80),

	ZONES = {
		StatsBoard = {
			offset = Vector3.new(-18, 4, -10),
			size = Vector3.new(8, 8, 2),
			color = Color3.fromRGB(60, 120, 200),
			promptText = "Statistiken ansehen",
			action = "showLobby",
		},
		ArenaGate = {
			offset = Vector3.new(0, 6, 28),
			size = Vector3.new(14, 12, 3),
			color = Color3.fromRGB(255, 180, 60),
			promptText = "Arena betreten",
			action = "enterArena",
		},
		BeyShop = {
			offset = Vector3.new(18, 4, -10),
			size = Vector3.new(8, 8, 2),
			color = Color3.fromRGB(140, 80, 220),
			promptText = "Bey auswählen",
			action = "openBeySelect",
		},
	},

	LIGHTING = {
		Ambient = Color3.fromRGB(120, 130, 160),
		OutdoorAmbient = Color3.fromRGB(140, 150, 180),
		Brightness = 2.5,
		ClockTime = 14.5,
	},
}

return HubConfig
