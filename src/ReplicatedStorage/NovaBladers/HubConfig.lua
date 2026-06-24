local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	SPAWN_FACING = Vector3.new(0, 0, 1),

	FLOOR_SIZE = Vector3.new(120, 1, 80),
	FLOOR_CENTER = Vector3.new(0, 2.5, 0),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena und kämpfe!",
			actionLabel = "Arena betreten",
			position = Vector3.new(0, 3.5, 28),
			size = Vector3.new(22, 8, 8),
			color = Color3.fromRGB(255, 110, 70),
			action = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey für den nächsten Kampf.",
			actionLabel = "Bey wählen",
			position = Vector3.new(-38, 3.5, 0),
			size = Vector3.new(16, 8, 16),
			color = Color3.fromRGB(70, 150, 255),
			action = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Die besten Kämpfer der Nova Arena.",
			actionLabel = "Leaderboard",
			position = Vector3.new(38, 3.5, 0),
			size = Vector3.new(16, 8, 16),
			color = Color3.fromRGB(255, 195, 50),
			action = "ViewLeaderboard",
		},
	},

	ARENA_SPAWN_PATH = { "Arena", "Bowl", "Spawn" },
	LEADERBOARD_TOP_COUNT = 5,
}

return HubConfig
