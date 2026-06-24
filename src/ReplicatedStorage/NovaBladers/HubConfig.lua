local HubConfig = {
	ROOT_NAME = "NovaHub",

	SPAWN = Vector3.new(0, 3.5, -25),
	SPAWN_LOOK = Vector3.new(0, 3.5, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 80),
	FLOOR_CENTER = Vector3.new(0, 2.5, 0),

	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	THEME = {
		Floor = Color3.fromRGB(28, 32, 48),
		Wall = Color3.fromRGB(18, 22, 36),
		Accent = Color3.fromRGB(90, 160, 255),
		Arena = Color3.fromRGB(255, 120, 80),
		BeyLab = Color3.fromRGB(80, 200, 140),
		Hall = Color3.fromRGB(220, 180, 60),
	},

	ZONES = {
		{
			id = "arena_gate",
			label = "Arena-Tor",
			hint = "Drücke E — Kampf starten",
			action = "enterArena",
			position = Vector3.new(0, 4, 28),
			size = Vector3.new(18, 10, 6),
			colorKey = "Arena",
		},
		{
			id = "bey_lab",
			label = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			action = "openBeySelect",
			position = Vector3.new(-32, 4, -8),
			size = Vector3.new(14, 10, 14),
			colorKey = "BeyLab",
		},
		{
			id = "hall_of_fame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			action = "viewLeaderboard",
			position = Vector3.new(32, 4, -8),
			size = Vector3.new(14, 10, 14),
			colorKey = "Hall",
		},
	},

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.Bowl.Spawn",
		"Workspace.Arena.Spawn",
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(32, 7, -14),
		size = Vector3.new(12, 8, 0.4),
		face = Enum.NormalId.Back,
	},
}

return HubConfig
