local HubConfig = {
	ORIGIN = Vector3.new(0, 0, 0),
	SPAWN_OFFSET = Vector3.new(0, 4, 28),

	FLOOR = {
		size = Vector3.new(96, 2, 96),
		color = Color3.fromRGB(32, 36, 48),
		material = Enum.Material.Slate,
	},

	THEME = {
		accent = Color3.fromRGB(80, 140, 255),
		glow = Color3.fromRGB(120, 180, 255),
		trim = Color3.fromRGB(55, 62, 82),
		path = Color3.fromRGB(45, 50, 68),
	},

	ARENA_GATE = {
		position = Vector3.new(0, 0, -40),
		radius = 9,
		promptText = "Arena betreten",
	},

	STATS_BOARD = {
		position = Vector3.new(-38, 0, 0),
	},

	LEADERBOARD = {
		position = Vector3.new(38, 0, 0),
	},

	BEY_SHOWCASE_OFFSETS = {
		Vector3.new(-18, 0, -12),
		Vector3.new(-18, 0, 4),
		Vector3.new(18, 0, 4),
		Vector3.new(18, 0, -12),
	},

	INTERACT_RANGE = 12,
}

return HubConfig
