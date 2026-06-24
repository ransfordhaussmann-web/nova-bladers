local HubConfig = {
	SPAWN = CFrame.new(0, 3.5, -25),
	ARENA_SPAWN_PATH = { "Arena", "Bowl", "Spawn" },

	HUB_SIZE = Vector3.new(80, 1, 80),
	WALL_HEIGHT = 12,
	FLOOR_COLOR = Color3.fromRGB(35, 38, 48),
	WALL_COLOR = Color3.fromRGB(55, 58, 72),

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betritt die Spin-Arena und kämpfe!",
			actionText = "Arena betreten",
			action = "EnterArena",
			position = Vector3.new(0, 2, 25),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 100, 80),
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Nova Bey aus.",
			actionText = "Bey wählen",
			action = "OpenBeySelect",
			position = Vector3.new(-28, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 140, 255),
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Die besten Kämpfer der Nova Liga.",
			actionText = "Leaderboard",
			action = "ShowLeaderboard",
			position = Vector3.new(28, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(28, 6, -4),
		size = Vector3.new(12, 8, 0.5),
		face = Enum.NormalId.Front,
	},
}

return HubConfig
