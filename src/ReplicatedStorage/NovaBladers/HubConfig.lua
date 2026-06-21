local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 3, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Arena und kämpfe!",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(18, 12, 6),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey aus.",
			position = Vector3.new(-38, 0, 10),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Sieh dir deine Stats und das Leaderboard an.",
			position = Vector3.new(38, 0, 10),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
			action = "showStats",
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },
	INTERACT_DISTANCE = 10,
	HINT_COOLDOWN = 2,
}

return HubConfig
