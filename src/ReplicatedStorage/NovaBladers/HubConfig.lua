local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 12,
	SPAWN_POSITION = Vector3.new(0, 3, -40),
	ARENA_FALLBACK_POSITION = Vector3.new(0, 5, 0),

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			position = Vector3.new(0, 0, 35),
			size = Vector3.new(20, 8, 12),
			color = Color3.fromRGB(255, 100, 80),
			action = "EnterArena",
			promptText = "Arena betreten",
		},
		BeyLab = {
			name = "Bey-Labor",
			position = Vector3.new(-35, 0, 0),
			size = Vector3.new(16, 8, 16),
			color = Color3.fromRGB(80, 140, 255),
			action = "OpenBeySelect",
			promptText = "Bey wählen",
		},
		HallOfFame = {
			name = "Ruhmeshalle",
			position = Vector3.new(35, 0, 0),
			size = Vector3.new(16, 8, 16),
			color = Color3.fromRGB(255, 200, 60),
			action = "ShowHallPanel",
			promptText = "Statistiken anzeigen",
		},
	},
}

return HubConfig
