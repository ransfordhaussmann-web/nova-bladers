local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 0),
	SPAWN_LOOK = Vector3.new(0, 0, -1),

	FLOOR_SIZE = Vector3.new(128, 1, 128),
	FLOOR_CENTER = Vector3.new(0, 0, 0),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	INTERACT_RADIUS = 10,
	INTERACT_COOLDOWN = 0.6,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			action = "enter_arena",
			hint = "[E] Arena betreten",
			position = Vector3.new(0, 0, -48),
			size = Vector3.new(22, 1, 14),
			color = Color3.fromRGB(255, 95, 75),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			action = "open_bey_select",
			hint = "[E] Bey wählen",
			position = Vector3.new(48, 0, 0),
			size = Vector3.new(14, 1, 18),
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			action = "show_stats",
			hint = "[E] Stats & Rangliste",
			position = Vector3.new(-48, 0, 0),
			size = Vector3.new(14, 1, 18),
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubConfig
