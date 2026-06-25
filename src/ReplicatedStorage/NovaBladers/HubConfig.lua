local HubConfig = {
	HUB_ORIGIN = Vector3.new(0, 80, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	SPAWN_OFFSET = Vector3.new(0, 4, 35),
	INTERACT_DISTANCE = 11,
	ZONE_CHECK_INTERVAL = 0.25,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke [E] — Kampf starten",
			position = Vector3.new(0, 0.5, -42),
			size = Vector3.new(22, 1, 14),
			color = Color3.fromRGB(255, 95, 75),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke [E] — Bey wählen",
			position = Vector3.new(-38, 0.5, 8),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(75, 150, 255),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Drücke [E] — Statistiken & Rangliste",
			position = Vector3.new(38, 0.5, 8),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(255, 205, 70),
			action = "showLobby",
		},
	},
}

return HubConfig
