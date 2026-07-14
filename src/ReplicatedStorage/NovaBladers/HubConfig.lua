local HubConfig = {
	-- Walkable hub world (HubWorldBuilder)
	SPAWN = Vector3.new(0, 4, 0),
	INTERACT_DISTANCE = 9,
	INTERACT_KEY = Enum.KeyCode.E,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten",
			position = Vector3.new(0, 1, -42),
			radius = 11,
			color = Color3.fromRGB(255, 95, 75),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Bey zu wählen",
			position = Vector3.new(-42, 1, 0),
			radius = 11,
			color = Color3.fromRGB(75, 140, 255),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Drücke E für die Top-Spieler",
			position = Vector3.new(42, 1, 0),
			radius = 11,
			color = Color3.fromRGB(255, 200, 55),
		},
	},

	WORLD = {
		FLOOR_SIZE = Vector3.new(130, 1, 130),
		FLOOR_CENTER = Vector3.new(0, 0, 0),
		WALL_HEIGHT = 14,
		WALL_THICKNESS = 2,
	},

	-- Legacy hub pads (HubBuilder)
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
	WALK_SPEED = 16,
	RETURN_SPAWN_OFFSET = Vector3.new(0, 0, -6),
}

return HubConfig
