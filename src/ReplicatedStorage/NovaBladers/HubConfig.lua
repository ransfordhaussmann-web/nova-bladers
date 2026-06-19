local HubConfig = {
	HUB_FOLDER = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	SPAWN_OFFSET = Vector3.new(0, 3, 0),
	WALL_HEIGHT = 16,
	INTERACT_RANGE = 10,

	ARENA_SPAWN_PATHS = {
		{ "Arena", "ArenaSpawn" },
		{ "ArenaSpawn" },
	},

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			hint = "Drücke E — Arena betreten",
			position = Vector3.new(0, 1, -45),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(255, 90, 70),
			action = "EnterArena",
		},
		{
			id = "beylab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-40, 1, 20),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 160, 255),
			action = "OpenBeySelect",
		},
		{
			id = "hall",
			name = "Ruhmeshalle",
			hint = "Drücke E — Stats anzeigen",
			position = Vector3.new(40, 1, 20),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 200, 60),
			action = "ShowHallPanel",
		},
	},
}

return HubConfig
