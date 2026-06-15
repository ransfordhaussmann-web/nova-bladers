local HubConfig = {
	HUB_FOLDER_NAME = "NovaBladersHub",
	ARENA_FOLDER_NAME = "Arena",

	SPAWN_POSITION = Vector3.new(0, 4, 35),
	FALLBACK_ARENA_SPAWN = Vector3.new(0, 12, 0),

	PLATFORM_SIZE = Vector3.new(100, 2, 100),
	PLATFORM_CENTER = Vector3.new(0, 0, 0),

	BOUNDARY_HEIGHT = 14,
	BOUNDARY_THICKNESS = 2,

	ZONES = {
		{
			id = "ArenaPortal",
			title = "Arena-Tor",
			label = "Arena betreten",
			action = "EnterArena",
			position = Vector3.new(0, 3, -38),
			size = Vector3.new(14, 10, 6),
			color = Color3.fromRGB(255, 95, 75),
		},
		{
			id = "BeySelect",
			title = "Werkstatt",
			label = "Bey wählen",
			action = "OpenBeySelect",
			position = Vector3.new(-38, 3, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 150, 255),
		},
		{
			id = "HallOfFame",
			title = "Ruhmeshalle",
			label = "Statistiken",
			action = "ShowStats",
			position = Vector3.new(38, 3, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	AMBIENT = {
		Brightness = 2.2,
		ClockTime = 15.5,
		FogEnd = 500,
		FogColor = Color3.fromRGB(120, 140, 180),
	},
}

return HubConfig
