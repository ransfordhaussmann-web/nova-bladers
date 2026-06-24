local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 100),
	FLOOR_Y = 2,

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			action = "enterArena",
			position = Vector3.new(0, 4, 30),
			size = Vector3.new(18, 10, 6),
			color = Color3.fromRGB(255, 90, 70),
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			action = "openBeySelect",
			position = Vector3.new(-35, 4, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			action = "showLeaderboard",
			position = Vector3.new(35, 4, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn", "PlayerSpawn" },
	LEADERBOARD_BOARD_SIZE = Vector2.new(600, 400),
}

return HubConfig
