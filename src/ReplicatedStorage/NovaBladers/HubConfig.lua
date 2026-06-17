local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	SPAWN_POSITION = Vector3.new(0, 4, 10),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_COLOR = Color3.fromRGB(45, 50, 65),

	PROMPT_DISTANCE = 12,
	PROMPT_HOLD = 0,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Drücke E — in die Arena!",
			position = Vector3.new(0, 5, -42),
			size = Vector3.new(14, 10, 5),
			color = Color3.fromRGB(220, 90, 70),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-38, 5, 0),
			size = Vector3.new(12, 10, 12),
			color = Color3.fromRGB(70, 130, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Drücke E — Top-Spieler ansehen",
			position = Vector3.new(38, 5, 0),
			size = Vector3.new(12, 10, 12),
			color = Color3.fromRGB(240, 190, 50),
			action = "showStats",
		},
	},
}

return HubConfig
