local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",
	HUB_ORIGIN = Vector3.new(0, 0, -220),

	SPAWN_OFFSET = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(120, 2, 120),
	FLOOR_COLOR = Color3.fromRGB(35, 42, 58),
	WALL_HEIGHT = 6,

	ZONE_ORDER = { "ArenaGate", "BeyLab", "HallOfFame" },

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena und kämpfe!",
			offset = Vector3.new(0, 1, 42),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(255, 120, 80),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey und passe dein Loadout an.",
			offset = Vector3.new(-42, 1, 0),
			size = Vector3.new(14, 1, 18),
			color = Color3.fromRGB(80, 160, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Sieh deine Stats und das globale Leaderboard.",
			offset = Vector3.new(42, 1, 0),
			size = Vector3.new(14, 1, 18),
			color = Color3.fromRGB(255, 210, 70),
			action = "openStats",
		},
	},

	PROXIMITY = {
		ActionText = "Öffnen",
		ObjectText = "",
		MaxActivationDistance = 10,
		HoldDuration = 0,
	},
}

return HubConfig
