local HubWorldConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	HUB_ORIGIN = Vector3.new(0, 0, 120),
	HUB_FLOOR_SIZE = Vector3.new(80, 1, 80),
	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	ARENA_GATE_OFFSET = Vector3.new(0, 0, -28),
	BEY_SELECT_OFFSET = Vector3.new(-22, 0, 10),
	STATS_BOARD_OFFSET = Vector3.new(22, 0, 10),

	ARENA_SPAWN_OFFSET = Vector3.new(0, 4, 0),
	RETURN_HUB_DELAY = 2.5,

	PROMPT = {
		ARENA_ACTION = "Arena betreten",
		BEY_ACTION = "Bey wählen",
		STATS_ACTION = "Stats anzeigen",
		MAX_DISTANCE = 12,
		HOLD_DURATION = 0,
	},
}

return HubWorldConfig
