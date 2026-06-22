local HubConfig = {
	SPAWN = Vector3.new(0, 4, 200),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_CENTER = Vector3.new(0, 0.5, 200),
	WALL_HEIGHT = 16,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Drücke E um die Arena zu betreten",
			action = "enter_arena",
			position = Vector3.new(0, 2, 240),
			size = Vector3.new(18, 10, 6),
			color = Color3.fromRGB(255, 90, 70),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Drücke E um deinen Bey zu wählen",
			action = "open_bey_select",
			position = Vector3.new(-35, 2, 200),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers Liga",
			action = "none",
			position = Vector3.new(35, 2, 200),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Spawn", "BowlSpawn" },
	ARENA_FOLDER_NAMES = { "Arena", "Bowl" },
}

return HubConfig
