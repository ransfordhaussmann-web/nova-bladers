local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 0),

	FLOOR_SIZE = Vector3.new(72, 1, 72),
	FLOOR_COLOR = Color3.fromRGB(32, 36, 48),
	ACCENT_COLOR = Color3.fromRGB(80, 140, 255),
	RIM_COLOR = Color3.fromRGB(55, 65, 90),

	ZONES = {
		ArenaGate = {
			offset = Vector3.new(0, 0, -28),
			size = Vector3.new(14, 10, 2),
			color = Color3.fromRGB(90, 120, 200),
			promptAction = "EnterArena",
			promptText = "Arena betreten",
		},
		BeyPedestal = {
			offset = Vector3.new(-22, 0, 8),
			size = Vector3.new(6, 1.2, 6),
			color = Color3.fromRGB(70, 90, 130),
			promptAction = "OpenBeySelect",
			promptText = "Bey wählen",
		},
		LeaderboardBoard = {
			offset = Vector3.new(22, 0, 8),
			size = Vector3.new(10, 8, 0.6),
			color = Color3.fromRGB(45, 50, 65),
		},
		StatsBoard = {
			offset = Vector3.new(0, 0, 28),
			size = Vector3.new(10, 6, 0.6),
			color = Color3.fromRGB(45, 50, 65),
		},
	},

	PROMPT_MAX_DISTANCE = 10,
	PROMPT_HOLD_DURATION = 0,

	ARENA_TELEPORT = Vector3.new(0, 6, 120),
}

return HubConfig
