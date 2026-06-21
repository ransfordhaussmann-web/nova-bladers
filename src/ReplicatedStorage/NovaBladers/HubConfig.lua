local HubConfig = {
	ROOT_NAME = "NovaHub",
	SPAWN_OFFSET = Vector3.new(0, 3, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		Wall = Color3.fromRGB(45, 52, 72),
		Accent = Color3.fromRGB(90, 160, 255),
		ArenaGate = Color3.fromRGB(255, 90, 90),
		BeyLab = Color3.fromRGB(90, 220, 140),
		HallOfFame = Color3.fromRGB(255, 200, 80),
	},

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Kampf starten",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(18, 1, 10),
			colorKey = "ArenaGate",
			action = "EnterArena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-38, 0, 10),
			size = Vector3.new(14, 1, 14),
			colorKey = "BeyLab",
			action = "OpenBeySelect",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(38, 0, 10),
			size = Vector3.new(14, 1, 14),
			colorKey = "HallOfFame",
			action = nil,
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
	ARENA_FOLDER = "Arena",
}

return HubConfig
