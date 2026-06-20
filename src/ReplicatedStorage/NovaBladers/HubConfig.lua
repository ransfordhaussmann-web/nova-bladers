local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	WALL_HEIGHT = 12,
	SPAWN_POSITION = Vector3.new(0, 3, 0),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			displayName = "Arena-Tor",
			hint = "Betreten — Kampf starten",
			position = Vector3.new(0, 0, -30),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 100, 80),
			action = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			displayName = "Bey-Labor",
			hint = "Bey auswählen",
			position = Vector3.new(-28, 0, 10),
			size = Vector3.new(12, 6, 12),
			color = Color3.fromRGB(80, 160, 255),
			action = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			displayName = "Ruhmeshalle",
			hint = "Stats & Rangliste",
			position = Vector3.new(28, 0, 10),
			size = Vector3.new(12, 6, 12),
			color = Color3.fromRGB(255, 200, 80),
			action = "ShowHallPanel",
		},
	},

	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Arena.ArenaSpawn" },
}

return HubConfig
