local HubConfig = {
	SPAWN = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(96, 1, 96),
	FLOOR_COLOR = Color3.fromRGB(28, 32, 48),
	ACCENT_COLOR = Color3.fromRGB(90, 150, 255),

	ZONES = {
		ArenaPortal = {
			position = Vector3.new(0, 2, -34),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(255, 120, 80),
			label = "Arena Portal",
			hint = "Betreten und kämpfen",
			proximity = 10,
		},
		BeyVault = {
			position = Vector3.new(34, 2, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 140, 255),
			label = "Bey Vault",
			hint = "Bey auswählen",
			proximity = 10,
		},
		StatsTerminal = {
			position = Vector3.new(0, 2, 34),
			size = Vector3.new(12, 6, 10),
			color = Color3.fromRGB(120, 200, 140),
			label = "Stats Terminal",
			hint = "Deine Statistik",
			proximity = 10,
		},
		LeaderboardMonument = {
			position = Vector3.new(-34, 2, 0),
			size = Vector3.new(12, 10, 10),
			color = Color3.fromRGB(255, 210, 80),
			label = "Rangliste",
			hint = "Top 5 Spieler",
			proximity = 12,
		},
	},

	ARENA_SPAWN = Vector3.new(0, 6, 0),
	ARENA_FOLDER = "Arena",
	HUB_FOLDER = "Hub",
	HUB_ZONE_TAG = "NovaHubZone",
}

return HubConfig
