local HubConfig = {
	ORIGIN = Vector3.new(0, 0, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	SPAWN = CFrame.new(0, 4, 42),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 2, -38),
			size = Vector3.new(22, 8, 10),
			color = Color3.fromRGB(255, 120, 80),
			action = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey",
			position = Vector3.new(-38, 2, 8),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(80, 160, 255),
			action = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(38, 2, 8),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(255, 210, 80),
			action = "ShowLeaderboard",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(38, 6, 8),
		size = Vector3.new(12, 8, 0.5),
		face = Enum.NormalId.Front,
	},

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.Spawn",
		"Workspace.ArenaSpawn",
	},
}

return HubConfig
