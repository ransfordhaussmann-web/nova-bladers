local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	FLOOR_SIZE = Vector3.new(80, 1, 80),
	FLOOR_POSITION = Vector3.new(0, 0, 0),
	SPAWN_POSITION = Vector3.new(0, 4, 0),

	ARENA_ENTRY_OFFSET = Vector3.new(0, 3, -30),
	BEY_SELECT_OFFSET = Vector3.new(-28, 3, 0),
	LEADERBOARD_OFFSET = Vector3.new(28, 3, 0),

	ZONE_SIZE = Vector3.new(14, 0.5, 14),
	PROMPT_DISTANCE = 10,
	PROMPT_HOLD = 0,

	ZONE_COLORS = {
		Arena = Color3.fromRGB(80, 140, 255),
		BeySelect = Color3.fromRGB(255, 200, 60),
		Leaderboard = Color3.fromRGB(140, 80, 220),
	},

	ZONE_LABELS = {
		Arena = "Arena",
		BeySelect = "Bey Auswahl",
		Leaderboard = "Rangliste",
	},

	ZONE_ACTIONS = {
		Arena = "EnterArena",
		BeySelect = "OpenBeySelect",
		Leaderboard = "ShowLeaderboard",
	},
}

return HubConfig
