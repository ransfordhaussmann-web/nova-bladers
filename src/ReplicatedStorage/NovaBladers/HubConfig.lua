local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	SPAWN_LOOK_AT = Vector3.new(0, 3.5, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 100),
	FLOOR_CENTER = Vector3.new(0, 2.5, 0),

	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	ZONE_RADIUS = 10,
	INTERACT_DISTANCE = 12,

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			action = "EnterArena",
			position = Vector3.new(0, 3.5, 28),
			color = Color3.fromRGB(80, 140, 255),
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			action = "OpenBeySelect",
			position = Vector3.new(-32, 3.5, 0),
			color = Color3.fromRGB(255, 200, 60),
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			action = "ViewLeaderboard",
			position = Vector3.new(32, 3.5, 0),
			color = Color3.fromRGB(140, 80, 220),
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn", "PlayerSpawn" },
	ARENA_PATHS = {
		{ "Arena", "Bowl" },
		{ "Arena" },
	},

	LEADERBOARD_BOARD_SIZE = Vector2.new(600, 400),
	LEADERBOARD_TOP_COUNT = 5,
}

return HubConfig
