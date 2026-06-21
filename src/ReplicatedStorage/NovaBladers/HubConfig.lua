local HubConfig = {
	MODEL_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 3, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		Wall = Color3.fromRGB(18, 20, 32),
		Accent = Color3.fromRGB(80, 140, 255),
		ArenaGate = Color3.fromRGB(255, 90, 70),
		BeyLab = Color3.fromRGB(70, 200, 140),
		HallOfFame = Color3.fromRGB(255, 200, 60),
	},

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			position = Vector3.new(0, 1, -42),
			size = Vector3.new(18, 10, 6),
			hint = "Betritt die Spin-Arena",
			action = "EnterArena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(-38, 1, 10),
			size = Vector3.new(14, 10, 14),
			hint = "Wähle deinen Bey",
			action = "OpenBeySelect",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(38, 1, 10),
			size = Vector3.new(14, 10, 14),
			hint = "Top-Spieler der Nova Liga",
			action = nil,
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(38, 8, 10),
		size = Vector3.new(12, 8, 0.5),
		face = Enum.NormalId.Front,
	},
}

return HubConfig
