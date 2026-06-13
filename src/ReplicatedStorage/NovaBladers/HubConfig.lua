local HubConfig = {
	HUB_FOLDER_NAME = "HubWorld",
	ARENA_FOLDER_NAME = "Arena",

	HUB_SPAWN = Vector3.new(0, 4, 12),
	ARENA_ENTRY_OFFSET = Vector3.new(0, 4, -28),
	ARENA_SPAWN_NAME = "Spawn",

	HUB_RADIUS = 42,
	FLOOR_THICKNESS = 2,

	GATE_PROMPT_ACTION = "Arena betreten",
	GATE_PROMPT_DISTANCE = 10,

	-- Nova Bladers hub palette
	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		FloorAccent = Color3.fromRGB(45, 55, 85),
		Neon = Color3.fromRGB(90, 160, 255),
		Portal = Color3.fromRGB(120, 200, 255),
		Pillar = Color3.fromRGB(38, 42, 58),
	},
}

return HubConfig
