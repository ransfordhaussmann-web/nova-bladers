local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 20),
	ARENA_SPAWN = Vector3.new(0, 4, 200),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_CENTER = Vector3.new(0, 0.5, 0),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	INTERACT_DISTANCE = 12,
	ZONE_HINT_DISTANCE = 20,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			position = Vector3.new(0, 2, -42),
			radius = 10,
			action = "enter_arena",
			color = Color3.fromRGB(255, 95, 75),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-42, 2, 0),
			radius = 10,
			action = "open_bey_select",
			color = Color3.fromRGB(75, 150, 255),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Drücke E — Stats anzeigen",
			position = Vector3.new(42, 2, 0),
			radius = 10,
			action = "show_stats",
			color = Color3.fromRGB(255, 205, 55),
		},
	},
}

return HubConfig
