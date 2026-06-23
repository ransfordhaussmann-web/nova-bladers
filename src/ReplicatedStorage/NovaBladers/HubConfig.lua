local HubConfig = {
	SPAWN_POSITION = Vector3.new(0, 3.5, -25),
	HUB_FOLDER_NAME = "NovaHub",

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_POSITION = Vector3.new(0, 0, 0),
	WALL_HEIGHT = 12,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Betrete die Arena und kämpfe!",
			actionLabel = "Arena starten",
			position = Vector3.new(0, 2, 30),
			size = Vector3.new(20, 8, 12),
			color = Color3.fromRGB(80, 140, 255),
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey für den nächsten Kampf.",
			actionLabel = "Bey wählen",
			position = Vector3.new(-35, 2, 0),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(255, 200, 60),
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Die besten Kämpfer der Nova Liga.",
			actionLabel = "Leaderboard",
			position = Vector3.new(35, 2, 0),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(140, 80, 220),
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn", "PlayerSpawn" },
	ARENA_FOLDER_NAMES = { "Arena", "Bowl" },
}

return HubConfig
