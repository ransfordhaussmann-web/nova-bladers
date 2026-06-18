local HubConfig = {
	-- Offset from arena center so hub and bowl stay separate in Studio.
	ORIGIN = Vector3.new(0, 48, -140),
	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	FLOOR = {
		size = Vector3.new(104, 2, 104),
		color = Color3.fromRGB(28, 32, 48),
		material = Enum.Material.Slate,
	},

	RIM_HEIGHT = 6,
	RIM_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			offset = Vector3.new(0, 0, 38),
			size = Vector3.new(18, 1, 10),
			color = Color3.fromRGB(255, 120, 60),
			label = "Arena Betreten",
			prompt = "Spiel starten",
			action = "enterArena",
		},
		BeySelect = {
			offset = Vector3.new(-32, 0, -10),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(80, 140, 255),
			label = "Bey-Werkstatt",
			prompt = "Bey wählen",
			action = "openBeySelect",
		},
		StatsBoard = {
			offset = Vector3.new(32, 0, -10),
			size = Vector3.new(14, 1, 10),
			color = Color3.fromRGB(120, 220, 140),
			label = "Rang-Board",
			prompt = "Stats anzeigen",
			action = "openStats",
		},
	},

	ARENA_SPAWN = Vector3.new(0, 6, 0),
	PROXIMITY_MAX = 12,

	LANDMARKS = {
		{ offset = Vector3.new(-42, 0, 42), height = 14, color = Color3.fromRGB(120, 200, 255) },
		{ offset = Vector3.new(42, 0, 42), height = 14, color = Color3.fromRGB(255, 200, 80) },
		{ offset = Vector3.new(0, 0, -42), height = 10, color = Color3.fromRGB(160, 80, 240) },
	},
}

return HubConfig
