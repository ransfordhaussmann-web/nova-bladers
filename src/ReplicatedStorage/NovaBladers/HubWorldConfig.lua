local HubWorldConfig = {
	HUB_FOLDER_NAME = "NovaBladersHub",
	ARENA_FOLDER_NAME = "Arena",

	HUB_SPAWN = Vector3.new(0, 6, 25),
	ARENA_SPAWN_NAME = "Spawn",

	PLATFORM_SIZE = Vector3.new(100, 2, 80),
	PLATFORM_POSITION = Vector3.new(0, 0, 0),

	ARENA_GATE_POSITION = Vector3.new(0, 5, -30),
	BEY_SELECT_POSITION = Vector3.new(-22, 5, -8),
	LEADERBOARD_POSITION = Vector3.new(22, 5, -8),
	STATS_BOARD_POSITION = Vector3.new(0, 5, 8),

	PROMPT_RANGE = 10,
	PROMPT_HOLD = 0,

	PROMPT_ACTION_TEXT = {
		ARENA = "Arena betreten",
		BEY_SELECT = "Bey wählen",
		STATS = "Statistiken",
	},

	COLORS = {
		Platform = Color3.fromRGB(45, 50, 65),
		Accent = Color3.fromRGB(80, 140, 255),
		Gate = Color3.fromRGB(255, 180, 60),
		Pedestal = Color3.fromRGB(140, 80, 220),
		Board = Color3.fromRGB(60, 70, 90),
	},
}

return HubWorldConfig
