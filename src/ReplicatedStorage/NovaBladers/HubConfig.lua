local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 10),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "arena",
			name = "Arena-Tor",
			hint = "Betritt die Spin-Arena",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(18, 10, 10),
			color = Color3.fromRGB(80, 140, 255),
			action = "enterArena",
		},
		BeyLab = {
			id = "beylab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			position = Vector3.new(-38, 0, 12),
			size = Vector3.new(16, 8, 16),
			color = Color3.fromRGB(255, 200, 60),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "hall",
			name = "Ruhmeshalle",
			hint = "Stats & Leaderboard ansehen",
			position = Vector3.new(38, 0, 12),
			size = Vector3.new(16, 8, 16),
			color = Color3.fromRGB(140, 80, 220),
			action = "openLobbyPanel",
		},
	},
}

return HubConfig
