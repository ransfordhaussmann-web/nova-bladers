local HubConfig = {
	SPAWN = Vector3.new(0, 4, 0),
	INTERACT_DISTANCE = 9,
	INTERACT_KEY = Enum.KeyCode.E,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E, um die Arena zu betreten",
			position = Vector3.new(0, 1, -42),
			radius = 11,
			color = Color3.fromRGB(255, 95, 75),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E, um deinen Bey zu wählen",
			position = Vector3.new(-42, 1, 0),
			radius = 11,
			color = Color3.fromRGB(75, 140, 255),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Drücke E für die Top-Spieler",
			position = Vector3.new(42, 1, 0),
			radius = 11,
			color = Color3.fromRGB(255, 200, 55),
		},
	},

	WORLD = {
		FLOOR_SIZE = Vector3.new(130, 1, 130),
		FLOOR_CENTER = Vector3.new(0, 0, 0),
		WALL_HEIGHT = 14,
		WALL_THICKNESS = 2,
	},
}

return HubConfig
