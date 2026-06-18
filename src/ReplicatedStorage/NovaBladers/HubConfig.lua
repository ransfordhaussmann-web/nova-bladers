local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,
	SPAWN_POSITION = Vector3.new(0, 3, -42),

	ZONES = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			subtitle = "Training / PvP / FFA",
			position = Vector3.new(0, 0, 38),
			size = Vector3.new(16, 12, 8),
			color = Color3.fromRGB(255, 95, 75),
			action = "EnterArena",
			promptText = "Arena betreten",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			subtitle = "Bey wählen & anpassen",
			position = Vector3.new(-38, 0, 0),
			size = Vector3.new(12, 10, 12),
			color = Color3.fromRGB(75, 150, 255),
			action = "OpenBeySelect",
			promptText = "Bey wählen",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			subtitle = "Stats & Leaderboard",
			position = Vector3.new(38, 0, 0),
			size = Vector3.new(12, 10, 12),
			color = Color3.fromRGB(255, 195, 55),
			action = "ShowLobbyStats",
			promptText = "Stats ansehen",
		},
	},

	PROXIMITY_DISTANCE = 10,
	PROXIMITY_HOLD = 0,
}

return HubConfig
