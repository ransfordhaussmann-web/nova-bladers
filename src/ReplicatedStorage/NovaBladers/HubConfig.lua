local HubConfig = {
	SPAWN = Vector3.new(0, 4, 200),
	HUB_FOLDER = "NovaHub",

	FLOOR_SIZE = Vector3.new(120, 1, 80),
	FLOOR_COLOR = Color3.fromRGB(35, 40, 55),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	ZONE_HINT_RANGE = 10,
	ACTION_KEY = Enum.KeyCode.E,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			position = Vector3.new(0, 1, 170),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(255, 90, 70),
			hint = "Drücke E — Arena betreten",
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			position = Vector3.new(-28, 1, 200),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(80, 140, 255),
			hint = "Drücke E — Bey auswählen",
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			position = Vector3.new(28, 1, 200),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(255, 200, 60),
			hint = "Drücke E — Ruhmeshalle",
			action = "showLeaderboard",
		},
	},

	ARENA_SPAWN_PATHS = {
		"Workspace.Arena.Bowl.Spawn",
		"Workspace.Arena.Spawn",
		"Workspace.Bowl.Spawn",
	},
	ARENA_FALLBACK = Vector3.new(0, 6, 0),

	LEADERBOARD_BOARD = {
		position = Vector3.new(28, 6, 194),
		size = Vector3.new(10, 6, 0.5),
		face = Enum.NormalId.Back,
	},
}

return HubConfig
