local HubConfig = {
	ROOT_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_CENTER = Vector3.new(0, 0.5, -80),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,
	SPAWN_OFFSET = Vector3.new(0, 4, -95),

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			subtitle = "Kampf starten",
			position = Vector3.new(0, 4, -55),
			size = Vector3.new(16, 10, 10),
			color = Color3.fromRGB(255, 95, 75),
			action = "showLobby",
			promptText = "Arena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			subtitle = "Bey auswählen",
			position = Vector3.new(-38, 4, -80),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 140, 255),
			action = "openBeySelect",
			promptText = "Bey wählen",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			subtitle = "Rangliste & Stats",
			position = Vector3.new(38, 4, -80),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
			action = "showLobby",
			promptText = "Stats",
		},
	},

	PROMPT_MAX_DISTANCE = 12,
	PROMPT_HOLD = 0.4,
}

return HubConfig
