local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	SPAWN_POSITION = Vector3.new(0, 4, 0),
	WALL_HEIGHT = 12,
	LEADERBOARD_BOARD_SIZE = Vector2.new(10, 6),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena!",
			position = Vector3.new(0, 1, -45),
			color = Color3.fromRGB(255, 100, 80),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey aus!",
			position = Vector3.new(-40, 1, 20),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga",
			position = Vector3.new(40, 1, 20),
			color = Color3.fromRGB(255, 200, 60),
			action = "showLeaderboard",
		},
	},

	ARENA_FOLDER = "Arena",
	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
}

return HubConfig
