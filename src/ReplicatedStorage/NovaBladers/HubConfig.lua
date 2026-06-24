local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	SPAWN_LOOK = Vector3.new(0, 0, 1),

	FLOOR_SIZE = Vector3.new(120, 1, 80),
	WALL_HEIGHT = 12,
	HUB_FOLDER_NAME = "NovaHub",

	ZONE_ACTION_RANGE = 10,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			actionLabel = "[E] Arena starten",
			position = Vector3.new(0, 0, 18),
			size = Vector3.new(22, 10, 10),
			color = Color3.fromRGB(80, 140, 255),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			actionLabel = "[E] Bey wählen",
			position = Vector3.new(-32, 0, 0),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(255, 200, 60),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			actionLabel = "[E] Leaderboard",
			position = Vector3.new(32, 0, 0),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(255, 180, 80),
		},
	},
}

return HubConfig
