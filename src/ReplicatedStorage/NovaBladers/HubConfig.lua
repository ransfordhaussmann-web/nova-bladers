local HubConfig = {
	HUB_NAME = "NovaBladersHub",
	SPAWN_NAME = "HubSpawn",

	FLOOR_SIZE = Vector3.new(120, 1, 80),
	FLOOR_POSITION = Vector3.new(0, 0.5, 0),
	FLOOR_COLOR = Color3.fromRGB(35, 38, 48),

	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,
	WALL_COLOR = Color3.fromRGB(55, 60, 75),

	SPAWN_OFFSET = Vector3.new(0, 4, -8),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Match starten",
			action = "EnterArena",
			size = Vector3.new(14, 10, 6),
			position = Vector3.new(0, 5, 34),
			color = Color3.fromRGB(90, 140, 255),
			lightColor = Color3.fromRGB(120, 180, 255),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Bey wählen",
			action = "OpenBeySelect",
			size = Vector3.new(12, 8, 12),
			position = Vector3.new(-38, 4, 0),
			color = Color3.fromRGB(80, 200, 140),
			lightColor = Color3.fromRGB(100, 230, 160),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Stats & Rangliste",
			action = "ShowHubPanel",
			size = Vector3.new(12, 8, 12),
			position = Vector3.new(38, 4, 0),
			color = Color3.fromRGB(255, 190, 70),
			lightColor = Color3.fromRGB(255, 210, 100),
		},
	},

	PROMPT = {
		ActionText = "Interagieren",
		MaxActivationDistance = 10,
		HoldDuration = 0,
	},
}

return HubConfig
