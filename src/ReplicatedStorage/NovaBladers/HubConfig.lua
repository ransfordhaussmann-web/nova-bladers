local HubConfig = {
	-- HubWorld (walkable lobby zones)
	HUB_ORIGIN = Vector3.new(0, 0, 120),
	FLOOR_SIZE = Vector3.new(96, 1, 96),
	WALL_HEIGHT = 6,

	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	ARENA_SPAWN = Vector3.new(0, 6, 0),
	ARENA_FOLDER_NAME = "Arena",

	ZONE_ORDER = { "Arena", "BeySelect", "Leaderboard" },

	ZONES = {
		Arena = {
			id = "Arena",
			label = "Arena-Tor",
			hint = "Drücke E oder nutze das Pad, um zu kämpfen.",
			offset = Vector3.new(0, 0, -34),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(255, 110, 70),
			remote = "EnterArena",
		},
		BeySelect = {
			id = "BeySelect",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey vor dem Kampf.",
			offset = Vector3.new(-32, 0, 18),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(80, 150, 255),
			remote = "OpenBeySelect",
		},
		Leaderboard = {
			id = "Leaderboard",
			label = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga.",
			offset = Vector3.new(32, 0, 18),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	PROXIMITY = {
		ActionText = "Betreten",
		ObjectText = "Zone",
		MaxActivationDistance = 10,
		HoldDuration = 0,
	},

	-- HubBuilder (arena portal pads)
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
