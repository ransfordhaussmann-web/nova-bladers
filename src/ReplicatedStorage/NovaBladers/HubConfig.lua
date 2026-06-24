local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_CFRAME = CFrame.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Kampf starten",
			action = "enterArena",
			position = Vector3.new(0, 2, 25),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 100, 80),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			action = "openBeySelect",
			position = Vector3.new(-30, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 160, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			action = "viewLeaderboard",
			position = Vector3.new(30, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 215, 80),
		},
	},

	ARENA_SPAWN_PATH = { "Arena", "Bowl", "Spawn" },
	INTERACT_RANGE = 12,
	ZONE_CHECK_INTERVAL = 0.25,
	LEADERBOARD_BOARD_SIZE = Vector2.new(600, 400),
}

return HubConfig
