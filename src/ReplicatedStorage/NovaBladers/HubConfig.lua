local HubConfig = {
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

	LEADERBOARD_OFFSET = Vector3.new(-18, 0, 14),
	BEY_LAB_OFFSET = Vector3.new(18, 0, 14),
	BEY_LAB_RADIUS = 10,
	WALK_SPEED = 16,
	RETURN_SPAWN_OFFSET = Vector3.new(0, 0, -6),
}

return HubConfig
