local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",
	HUB_CENTER = Vector3.new(0, 0, 0),
	HUB_SPAWN = Vector3.new(0, 3, 12),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	ARENA_FALLBACK_SPAWN = Vector3.new(0, 8, 0),

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 0.5, -48),
			size = Vector3.new(16, 1, 12),
			color = Color3.fromRGB(255, 95, 75),
			label = "Arena-Tor",
			actionText = "Betreten",
			signText = "⚔ Arena",
		},
		BeyShop = {
			position = Vector3.new(-42, 0.5, 0),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(80, 160, 255),
			label = "Bey-Shop",
			actionText = "Auswählen",
			signText = "🌀 Bey-Shop",
		},
		StatsBoard = {
			position = Vector3.new(42, 0.5, 0),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(255, 200, 70),
			label = "Ruhmeshalle",
			actionText = "Ansehen",
			signText = "🏆 Ruhmeshalle",
		},
	},
}

return HubConfig
