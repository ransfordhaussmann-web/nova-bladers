local HubConfig = {
	HUB_ORIGIN = Vector3.new(0, 0, 120),
	FLOOR_SIZE = Vector3.new(96, 1, 96),
	WALL_HEIGHT = 6,

	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	ARENA_SPAWN = Vector3.new(0, 6, 0),
	ARENA_FOLDER_NAME = "Arena",

	PLAYER_ATTR_IN_HUB = "NovaInHub",
	PLAYER_ATTR_IN_ARENA = "NovaInArena",

	ZONE_ORDER = { "Arena", "BeySelect", "Leaderboard" },

	ZONES = {
		Arena = {
			id = "Arena",
			label = "Arena-Tor",
			hint = "Drücke E oder nutze das Pad, um zu kämpfen.",
			offset = Vector3.new(0, 0, -34),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(255, 110, 70),
			remote = "EnterArena",
		},
		BeySelect = {
			id = "BeySelect",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey vor dem Kampf.",
			offset = Vector3.new(-32, 0, 18),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(80, 150, 255),
			remote = "OpenBeySelect",
		},
		Leaderboard = {
			id = "Leaderboard",
			label = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Liga.",
			offset = Vector3.new(32, 0, 18),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	PROXIMITY = {
		ActionText = "Betreten",
		ObjectText = "Zone",
		MaxActivationDistance = 10,
		HoldDuration = 0,
	},
}

return HubConfig
