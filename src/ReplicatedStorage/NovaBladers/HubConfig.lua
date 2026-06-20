local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 0),

	FLOOR_SIZE = Vector3.new(88, 1, 88),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	INTERACT_DISTANCE = 12,
	ZONE_COOLDOWN = 1.5,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			position = Vector3.new(-28, 0, -18),
			size = Vector3.new(14, 12, 10),
			color = Color3.fromRGB(235, 95, 75),
			action = "EnterArena",
			hint = "Drücke E — Arena betreten",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(28, 0, -18),
			size = Vector3.new(14, 12, 10),
			color = Color3.fromRGB(75, 130, 255),
			action = "OpenBeySelect",
			hint = "Drücke E — Bey wählen",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(0, 0, 30),
			size = Vector3.new(24, 12, 10),
			color = Color3.fromRGB(255, 195, 55),
			action = "HallOfFame",
			hint = "Top-Spieler ansehen",
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
	ARENA_FOLDER_NAMES = { "Arena", "BattleArena" },
}

return HubConfig
