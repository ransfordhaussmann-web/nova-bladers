local HubConfig = {
	USE_3D_HUB = true,

	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	HUB_SPAWN = CFrame.new(0, 4, 10),
	HUB_FLOOR_SIZE = Vector3.new(72, 1, 72),
	HUB_FLOOR_COLOR = Color3.fromRGB(35, 40, 55),

	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	ZONES = {
		Arena = {
			position = Vector3.new(0, 1.5, -22),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(220, 90, 70),
			label = "Arena-Tor",
			promptText = "Arena betreten",
			promptAction = "EnterArena",
		},
		BeySelect = {
			position = Vector3.new(-22, 1.5, 0),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(80, 140, 255),
			label = "Bey-Labor",
			promptText = "Bey wählen",
			promptAction = "OpenBeySelect",
		},
		Leaderboard = {
			position = Vector3.new(22, 1.5, 0),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(255, 200, 60),
			label = "Ruhmeshalle",
			promptText = "Rangliste anzeigen",
			promptAction = "ShowLeaderboard",
		},
	},
}

return HubConfig
