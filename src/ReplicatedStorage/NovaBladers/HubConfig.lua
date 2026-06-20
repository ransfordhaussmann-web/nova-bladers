local HubConfig = {
	HUB_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 12,
	SPAWN_OFFSET = Vector3.new(0, 3, -40),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Arena und kämpfe!",
			action = "EnterArena",
			position = Vector3.new(0, 0, 45),
			size = Vector3.new(16, 1, 8),
			color = Color3.fromRGB(255, 80, 80),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey aus.",
			action = "OpenBeySelect",
			position = Vector3.new(-40, 0, 0),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(80, 140, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers.",
			action = "ViewLeaderboard",
			position = Vector3.new(40, 0, 0),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
	ARENA_FALLBACK = Vector3.new(0, 5, 0),
}

return HubConfig
