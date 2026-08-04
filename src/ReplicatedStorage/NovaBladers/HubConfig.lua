local HubConfig = {
	-- Nova Plaza (HubWorldBuilder)
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

	-- Legacy walkable hub (HubBuilder)
	HUB_SIZE = 96,
	FLOOR_HEIGHT = 1,
	SPAWN_Y = 4,
	PORTAL_OFFSET = 32,
	PORTAL_SIZE = Vector3.new(14, 12, 3),

	MODE_PADS = {
		Training = {
			id = "training",
			label = "Training",
			desc = "1 Spieler — Dummy-Gegner",
			offset = Vector3.new(-28, 0, 0),
			color = Color3.fromRGB(100, 180, 255),
		},
		PvP = {
			id = "pvp",
			label = "1v1 PvP",
			desc = "2 Spieler — Duell",
			offset = Vector3.new(28, 0, 0),
			color = Color3.fromRGB(255, 140, 80),
		},
		FFA = {
			id = "ffa",
			label = "FFA",
			desc = "3+ Spieler — Free-for-All",
			offset = Vector3.new(0, 0, -28),
			color = Color3.fromRGB(180, 100, 255),
		},
	},

	WALK_SPEED = 16,
	RETURN_SPAWN_OFFSET = Vector3.new(0, 0, -6),
}

return HubConfig
