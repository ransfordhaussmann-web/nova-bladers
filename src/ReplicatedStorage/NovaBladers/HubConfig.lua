local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAMES = { "Arena", "BattleArena" },
	ARENA_SPAWN_NAMES = { "ArenaSpawn", "Spawn" },

	FLOOR_SIZE = Vector3.new(120, 2, 120),
	FLOOR_COLOR = Color3.fromRGB(28, 32, 48),
	WALL_HEIGHT = 18,
	WALL_THICKNESS = 2,
	SPAWN_OFFSET = Vector3.new(0, 4, -30),

	ZONES = {
		ArenaGate = {
			label = "Arena-Tor",
			hint = "Betreten",
			position = Vector3.new(0, 1, 48),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 120, 80),
			holdDuration = 0,
		},
		BeyLab = {
			label = "Bey-Labor",
			hint = "Bey wählen",
			position = Vector3.new(-46, 1, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 160, 255),
			holdDuration = 0,
		},
		HallOfFame = {
			label = "Ruhmeshalle",
			hint = "Stats ansehen",
			position = Vector3.new(46, 1, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 210, 80),
			holdDuration = 0,
		},
	},
}

return HubConfig
