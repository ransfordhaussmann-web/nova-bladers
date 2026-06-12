local HubConfig = {
	-- Hub world origin (floor center)
	HUB_ORIGIN = Vector3.new(0, 8, 0),

	-- Player spawn above the hub floor
	SPAWN_OFFSET = Vector3.new(0, 4, 10),

	-- Arena bowl entry (separate from hub; GameManager teleports here on match start)
	ARENA_ENTRY = Vector3.new(0, 12, 120),

	FLOOR_SIZE = Vector3.new(100, 1, 80),
	WALL_HEIGHT = 14,

	ZONE_TOUCH_COOLDOWN = 1.2,

	ZONES = {
		Arena = {
			id = "Arena",
			label = "Arena",
			hint = "Betreten zum Kämpfen",
			position = Vector3.new(0, 0, -28),
			size = Vector3.new(22, 1, 22),
			color = Color3.fromRGB(80, 140, 255),
			lightColor = Color3.fromRGB(100, 160, 255),
		},
		BeySelect = {
			id = "BeySelect",
			label = "Bey Bay",
			hint = "Bey wählen",
			position = Vector3.new(-30, 0, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(255, 180, 60),
			lightColor = Color3.fromRGB(255, 200, 80),
		},
		Leaderboard = {
			id = "Leaderboard",
			label = "Rangtafel",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(30, 0, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(140, 80, 220),
			lightColor = Color3.fromRGB(160, 100, 240),
		},
	},
}

return HubConfig
