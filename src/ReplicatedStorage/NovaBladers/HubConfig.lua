local HubConfig = {
	ORIGIN = Vector3.new(0, 50, 0),
	FLOOR = {
		SIZE = Vector3.new(120, 2, 120),
		COLOR = Color3.fromRGB(35, 40, 55),
		MATERIAL = Enum.Material.Slate,
	},
	SPAWN_OFFSET = Vector3.new(0, 4, 0),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			displayName = "Arena-Tor",
			hint = "Betrete die Spin-Arena!",
			position = Vector3.new(0, 5, -45),
			size = Vector3.new(22, 10, 10),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			displayName = "Bey-Labor",
			hint = "Wähle deinen Bey!",
			position = Vector3.new(-42, 5, 18),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(80, 140, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			displayName = "Ruhmeshalle",
			hint = "Die besten Kämpfer der Nova Liga",
			position = Vector3.new(42, 5, 18),
			size = Vector3.new(18, 10, 18),
			color = Color3.fromRGB(255, 200, 60),
			action = "hallOfFame",
		},
	},

	LEADERBOARD = {
		position = Vector3.new(42, 12, 30),
		size = Vector3.new(14, 9, 0.4),
		face = Enum.NormalId.Front,
		topCount = 5,
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn", "ArenaSpawnLocation" },
	ARENA_FALLBACK_NAMES = { "Bowl", "Arena", "ArenaFloor" },

	ZONE_COOLDOWN = 1.2,
	HUB_FOLDER_NAME = "NovaHub",
}

return HubConfig
