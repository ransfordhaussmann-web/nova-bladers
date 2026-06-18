local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ORIGIN = Vector3.new(0, 50, 0),

	FLOOR = {
		size = Vector2.new(72, 72),
		thickness = 1,
		color = Color3.fromRGB(45, 48, 58),
	},

	WALLS = {
		height = 10,
		thickness = 2,
		color = Color3.fromRGB(60, 65, 80),
	},

	SPAWN = Vector3.new(0, 3, 28),
	SPAWN_LOOK = Vector3.new(0, 3, 0),

	ARENA_FOLDER = "Arena",
	ARENA_SPAWN = "Spawn",

	ZONES = {
		{
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Kampf starten",
			position = Vector3.new(0, 0, -28),
			size = Vector3.new(14, 10, 4),
			color = Color3.fromRGB(220, 90, 70),
			action = "EnterArena",
		},
		{
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Bey auswählen",
			position = Vector3.new(-28, 0, 0),
			size = Vector3.new(8, 8, 8),
			color = Color3.fromRGB(70, 130, 255),
			action = "OpenBeySelect",
		},
		{
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Bestenliste",
			position = Vector3.new(28, 0, 0),
			size = Vector3.new(8, 8, 8),
			color = Color3.fromRGB(240, 190, 50),
			action = "ShowHallOfFame",
		},
	},
}

return HubConfig
