local HubConfig = {
	ROOT_NAME = "NovaBladersHub",

	SPAWN = Vector3.new(0, 4, 8),
	ARENA_GATE = Vector3.new(0, 3, -42),
	LEADERBOARD = Vector3.new(28, 6, -10),
	BEY_SHOWCASE = Vector3.new(-28, 4, -10),

	FLOOR_RADIUS = 52,
	FLOOR_THICKNESS = 1.2,

	ZONE_RADIUS = 7,
	GATE_SIZE = Vector3.new(14, 10, 3),

	COLORS = {
		Floor = Color3.fromRGB(24, 28, 42),
		FloorAccent = Color3.fromRGB(40, 48, 72),
		Neon = Color3.fromRGB(90, 160, 255),
		Gate = Color3.fromRGB(255, 190, 70),
		Training = Color3.fromRGB(90, 200, 140),
		PvP = Color3.fromRGB(255, 110, 110),
		FFA = Color3.fromRGB(180, 120, 255),
	},

	MODE_ZONES = {
		{
			id = "Training",
			label = "Training",
			position = Vector3.new(-18, 2.5, -18),
			colorKey = "Training",
		},
		{
			id = "PvP",
			label = "1v1 PvP",
			position = Vector3.new(0, 2.5, -24),
			colorKey = "PvP",
		},
		{
			id = "FFA",
			label = "FFA",
			position = Vector3.new(18, 2.5, -18),
			colorKey = "FFA",
		},
	},
}

return HubConfig
