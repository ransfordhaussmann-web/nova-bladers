local HubConfig = {
	HUB_ORIGIN = Vector3.new(0, 50, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 12,
	SPAWN_OFFSET = Vector3.new(0, 4, -30),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Drücke E, um in die Arena zu gehen",
			position = Vector3.new(0, 54, 42),
			size = Vector3.new(22, 10, 14),
			color = Color3.fromRGB(255, 120, 80),
			action = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Drücke E, um deinen Bey zu wählen",
			position = Vector3.new(-38, 54, -12),
			size = Vector3.new(20, 10, 20),
			color = Color3.fromRGB(80, 140, 255),
			action = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Drücke E für Stats und Leaderboard",
			position = Vector3.new(38, 54, -12),
			size = Vector3.new(20, 10, 20),
			color = Color3.fromRGB(255, 200, 60),
			action = "OpenLobby",
		},
	},
}

return HubConfig
