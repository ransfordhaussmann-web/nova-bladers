local HubConfig = {
	HUB_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(72, 1, 72),
	WALL_HEIGHT = 14,
	SPAWN_OFFSET = Vector3.new(0, 4, 24),

	ARENA_FALLBACK = CFrame.new(0, 6, 120),

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			subtitle = "Training / PvP / FFA",
			position = Vector3.new(0, 0, -28),
			size = Vector3.new(14, 10, 8),
			color = Color3.fromRGB(255, 90, 90),
			promptText = "Arena betreten",
			action = "enterArena",
		},
		{
			id = "beyLab",
			name = "Bey-Labor",
			subtitle = "Bey auswählen",
			position = Vector3.new(-26, 0, 0),
			size = Vector3.new(10, 10, 10),
			color = Color3.fromRGB(80, 160, 255),
			promptText = "Bey wählen",
			action = "openBeySelect",
		},
		{
			id = "hall",
			name = "Ruhmeshalle",
			subtitle = "Stats & Leaderboard",
			position = Vector3.new(26, 0, 0),
			size = Vector3.new(10, 10, 10),
			color = Color3.fromRGB(255, 200, 60),
			promptText = "Stats anzeigen",
			action = "showHall",
		},
	},
}

return HubConfig
