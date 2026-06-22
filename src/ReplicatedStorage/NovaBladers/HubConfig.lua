local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	SPAWN_POSITION = Vector3.new(0, 3, 0),
	INTERACT_DISTANCE = 12,

	ARENA_SPAWN_NAMES = { "Arena.Spawn", "ArenaSpawn", "Arena" },

	ZONES = {
		ArenaGate = {
			name = "Arena-Tor",
			hint = "Arena betreten",
			position = Vector3.new(0, 2, -45),
			size = Vector3.new(18, 8, 6),
			color = Color3.fromRGB(255, 90, 70),
			action = "enterArena",
		},
		BeyLab = {
			name = "Bey-Labor",
			hint = "Bey wählen",
			position = Vector3.new(-40, 2, 0),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			position = Vector3.new(40, 2, 0),
			size = Vector3.new(14, 8, 14),
			color = Color3.fromRGB(255, 210, 60),
			action = "viewLeaderboard",
		},
	},
}

return HubConfig
