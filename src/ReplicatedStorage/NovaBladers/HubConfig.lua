local HubConfig = {
	HUB_FOLDER = "NovaHub",
	ARENA_FOLDER = "NovaArena",

	SPAWN_POSITION = Vector3.new(0, 4, 25),
	ARENA_SPAWN = Vector3.new(0, 5, 0),

	FLOOR_SIZE = Vector3.new(100, 1, 80),
	WALL_HEIGHT = 16,
	INTERACT_RANGE = 10,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten",
			position = Vector3.new(0, 0, -28),
			size = Vector3.new(18, 1, 10),
			markerSize = Vector3.new(14, 8, 2),
			action = "enterArena",
			color = Color3.fromRGB(70, 130, 255),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E für die Bey-Auswahl",
			position = Vector3.new(32, 0, 8),
			size = Vector3.new(14, 1, 14),
			markerSize = Vector3.new(10, 7, 10),
			action = "openBeySelect",
			color = Color3.fromRGB(255, 190, 50),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Drücke E für Stats & Leaderboard",
			position = Vector3.new(-32, 0, 8),
			size = Vector3.new(14, 1, 14),
			markerSize = Vector3.new(10, 7, 10),
			action = "showLobby",
			color = Color3.fromRGB(150, 90, 230),
		},
	},
}

return HubConfig
