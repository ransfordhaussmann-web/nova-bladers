local HubConfig = {
	ORIGIN = Vector3.new(0, 0, 200),
	SPAWN_OFFSET = Vector3.new(0, 3, 0),
	ARENA_PORTAL_OFFSET = Vector3.new(0, 0, -28),
	LEADERBOARD_OFFSET = Vector3.new(-22, 0, 8),
	BEY_SELECT_OFFSET = Vector3.new(22, 0, 8),
	TRAINING_SIGN_OFFSET = Vector3.new(0, 0, 18),
	PLAZA_RADIUS = 48,
	WALL_HEIGHT = 12,

	FLOOR_COLOR = Color3.fromRGB(22, 26, 38),
	FLOOR_ACCENT = Color3.fromRGB(35, 42, 62),
	ACCENT_COLOR = Color3.fromRGB(80, 140, 255),
	PORTAL_COLOR = Color3.fromRGB(120, 80, 255),
	SIGN_COLOR = Color3.fromRGB(18, 20, 30),

	PORTAL_ACTION = "Arena betreten",
	BEY_SELECT_ACTION = "Bey wählen",
}

return HubConfig
