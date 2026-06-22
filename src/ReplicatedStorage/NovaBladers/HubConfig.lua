local HubConfig = {
	FLOOR_SIZE = Vector2.new(120, 120),
	WALL_HEIGHT = 16,
	SPAWN_POSITION = Vector3.new(0, 3, 0),
	ZONE_ACTION_RANGE = 10,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			position = Vector3.new(0, 0, -45),
			size = Vector3.new(22, 12, 10),
			hint = "Betritt die Spin-Arena",
			action = "EnterArena",
			color = Color3.fromRGB(80, 140, 255),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(-42, 0, 0),
			size = Vector3.new(18, 10, 18),
			hint = "Wähle deinen Bey",
			action = "OpenBeySelect",
			color = Color3.fromRGB(255, 200, 60),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(42, 0, 0),
			size = Vector3.new(18, 10, 18),
			hint = "Top-Spieler ansehen",
			action = "ViewLeaderboard",
			color = Color3.fromRGB(255, 180, 80),
		},
	},
}

return HubConfig
