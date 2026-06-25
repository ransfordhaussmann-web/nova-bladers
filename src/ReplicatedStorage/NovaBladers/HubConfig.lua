local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN = CFrame.new(0, 3, 20),

	FLOOR_SIZE = Vector3.new(80, 1, 80),
	FLOOR_POSITION = Vector3.new(0, 0, 0),

	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Arena — drücke E",
			position = Vector3.new(0, 1, -30),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey — drücke E",
			position = Vector3.new(-28, 1, 5),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga",
			position = Vector3.new(28, 1, 5),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 200, 60),
			action = "hallOfFame",
		},
	},

	ZONE_ACTIVATE_DISTANCE = 8,
	INTERACT_KEY = Enum.KeyCode.E,

	ARENA_SPAWN_PATHS = {
		"Arena.Spawn",
		"Arena.Bowl.Spawn",
	},
}

return HubConfig
