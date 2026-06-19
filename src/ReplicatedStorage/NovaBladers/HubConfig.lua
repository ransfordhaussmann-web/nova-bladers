local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 4, -40),
	FLOOR_SIZE = Vector3.new(140, 1, 140),
	WALL_HEIGHT = 16,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 1, 45),
			size = Vector3.new(24, 1, 14),
			color = Color3.fromRGB(255, 90, 70),
			prompt = "Arena betreten",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey",
			position = Vector3.new(-42, 1, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(80, 160, 255),
			prompt = "Bey auswählen",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Sieh deine Stats & das Leaderboard",
			position = Vector3.new(42, 1, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(255, 200, 60),
			prompt = "Stats anzeigen",
		},
	},

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.ArenaSpawn",
		"Workspace.ArenaSpawn",
	},
}

return HubConfig
