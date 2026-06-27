local HubConfig = {
	MODEL_NAME = "NovaHub",
	ARENA_MODEL_NAME = "Arena",

	-- Hub floor center (world space)
	ORIGIN = Vector3.new(0, 0, 0),
	SPAWN_OFFSET = Vector3.new(0, 4, -18),

	-- Arena entry teleport (offset from arena model pivot)
	ARENA_SPAWN_OFFSET = Vector3.new(0, 4, 0),

	FLOOR_SIZE = Vector3.new(120, 2, 90),
	FLOOR_COLOR = Color3.fromRGB(28, 32, 48),
	FLOOR_MATERIAL = Enum.Material.Slate,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			promptAction = "Betreten",
			promptObjectText = "Arena",
			offset = Vector3.new(0, 0, 28),
			size = Vector3.new(18, 14, 6),
			color = Color3.fromRGB(90, 140, 255),
			glowColor = Color3.fromRGB(120, 180, 255),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			promptAction = "Öffnen",
			promptObjectText = "Bey-Auswahl",
			offset = Vector3.new(-32, 0, -8),
			size = Vector3.new(16, 10, 14),
			color = Color3.fromRGB(70, 200, 140),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			promptAction = "Ansehen",
			promptObjectText = "Leaderboard",
			offset = Vector3.new(32, 0, -8),
			size = Vector3.new(16, 10, 14),
			color = Color3.fromRGB(220, 180, 60),
		},
	},

	BOARD = {
		size = Vector3.new(10, 6, 0.4),
		offset = Vector3.new(0, 5, -5.5),
	},

	PROMPT = {
		maxActivationDistance = 12,
		holdDuration = 0,
	},
}

return HubConfig
