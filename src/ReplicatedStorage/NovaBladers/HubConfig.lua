local HubConfig = {
	-- An Arena-Position im Place anpassen
	ORIGIN = Vector3.new(0, 0, 0),
	ARENA_SPAWN_OFFSET = Vector3.new(0, 2, -80),

	HUB_SPAWN = Vector3.new(0, 3, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Drücke E zum Kämpfen",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(18, 12, 6),
			color = Color3.fromRGB(80, 140, 255),
			glowColor = Color3.fromRGB(120, 180, 255),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Drücke E für Bey-Auswahl",
			position = Vector3.new(-38, 0, 8),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 180, 60),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Drücke E für Stats & Rangliste",
			position = Vector3.new(38, 0, 8),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(180, 100, 255),
		},
	},

	PROXIMITY = {
		ActionText = "Interagieren",
		HoldDuration = 0,
		MaxActivationDistance = 10,
	},
}

return HubConfig
