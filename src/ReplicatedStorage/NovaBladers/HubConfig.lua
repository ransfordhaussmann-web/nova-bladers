local HubConfig = {
	SPAWN_CFRAME = CFrame.new(0, 3.5, -25),
	HUB_FOLDER_NAME = "NovaHub",

	FLOOR_SIZE = Vector3.new(80, 1, 80),
	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			position = Vector3.new(0, 4, -38),
			size = Vector3.new(14, 8, 10),
			color = Color3.fromRGB(80, 140, 255),
			action = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey auswählen",
			position = Vector3.new(-26, 4, -8),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 200, 60),
			action = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Arena",
			position = Vector3.new(26, 4, -8),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(200, 160, 80),
			action = "ViewLeaderboard",
		},
	},
}

return HubConfig
