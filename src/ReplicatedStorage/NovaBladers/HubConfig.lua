local HubConfig = {
	SPAWN_HEIGHT = 3,
	PLATFORM_RADIUS = 48,
	PLATFORM_THICKNESS = 2,
	RAILING_HEIGHT = 6,

	ZONES = {
		ArenaPortal = Vector3.new(0, 0, -34),
		Leaderboard = Vector3.new(30, 0, 4),
		BeyGallery = Vector3.new(-30, 0, 4),
		SpawnCenter = Vector3.new(0, 0, 14),
	},

	COLORS = {
		Floor = Color3.fromRGB(32, 38, 52),
		FloorAccent = Color3.fromRGB(48, 56, 76),
		Railing = Color3.fromRGB(70, 90, 130),
		Portal = Color3.fromRGB(255, 185, 70),
		PortalGlow = Color3.fromRGB(255, 220, 120),
		Kiosk = Color3.fromRGB(90, 160, 255),
		Gallery = Color3.fromRGB(140, 100, 220),
	},

	PROMPT = {
		Arena = {
			ActionText = "Arena betreten",
			ObjectText = "Spin-Arena",
			MaxActivationDistance = 14,
		},
		Stats = {
			ActionText = "Stats anzeigen",
			ObjectText = "Rang-Board",
			MaxActivationDistance = 12,
		},
	},

	WALK_SPEED = 16,
}

return HubConfig
