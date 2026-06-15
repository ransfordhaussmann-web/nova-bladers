local HubConfig = {
	ROOT_NAME = "NovaBladersHub",

	SPAWN = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(120, 2, 120),
	FLOOR_COLOR = Color3.fromRGB(28, 32, 48),
	FLOOR_MATERIAL = Enum.Material.Slate,

	RIM_HEIGHT = 6,
	RIM_THICKNESS = 4,

	ARENA_GATE = {
		position = Vector3.new(0, 6, -42),
		size = Vector3.new(18, 12, 4),
		color = Color3.fromRGB(90, 180, 255),
		promptText = "Arena betreten",
		promptKey = Enum.KeyCode.E,
	},

	LEADERBOARD = {
		position = Vector3.new(38, 10, -10),
		size = Vector3.new(6, 14, 6),
		color = Color3.fromRGB(255, 210, 80),
	},

	BEY_PODS = {
		{ name = "Nova Striker", color = Color3.fromRGB(80, 140, 255), offset = Vector3.new(-28, 0, 18) },
		{ name = "Iron Shell", color = Color3.fromRGB(80, 180, 110), offset = Vector3.new(-10, 0, 28) },
		{ name = "Volt Dash", color = Color3.fromRGB(255, 200, 60), offset = Vector3.new(10, 0, 28) },
		{ name = "Shadow Bite", color = Color3.fromRGB(140, 80, 220), offset = Vector3.new(28, 0, 18) },
	},

	LIGHTING = {
		ambient = Color3.fromRGB(70, 75, 95),
		brightness = 2.4,
		clockTime = 15.5,
	},

	HUB_WALK_SPEED = 16,
	RETURN_SPAWN_OFFSET = Vector3.new(0, 3, 0),
}

return HubConfig
