local HubConfig = {
	FOLDER_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	SPAWN_LOOK = Vector3.new(0, 0, 1),

	FLOOR_SIZE = Vector3.new(120, 1, 90),
	FLOOR_CENTER = Vector3.new(0, 0.5, 0),
	WALL_HEIGHT = 14,

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			action = "EnterArena",
			position = Vector3.new(0, 1, 32),
			size = Vector3.new(18, 10, 6),
			color = Color3.fromRGB(80, 140, 255),
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			action = "OpenBeySelect",
			position = Vector3.new(-38, 1, -8),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 180, 60),
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Globales Leaderboard",
			action = "ShowLeaderboard",
			position = Vector3.new(38, 1, -8),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(200, 160, 255),
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn", "PlayerSpawn" },
}

return HubConfig
