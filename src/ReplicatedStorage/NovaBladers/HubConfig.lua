local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ORIGIN = Vector3.new(0, 0, 0),
	SPAWN_OFFSET = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(100, 2, 100),
	WALL_HEIGHT = 14,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			actionText = "Kämpfen",
			position = Vector3.new(0, 0, -42),
			size = Vector3.new(18, 1, 10),
			color = Color3.fromRGB(255, 90, 70),
			remote = "EnterArena",
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			actionText = "Auswählen",
			position = Vector3.new(-38, 0, 0),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(70, 150, 255),
			remote = "OpenBeySelect",
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			actionText = "Ansehen",
			position = Vector3.new(38, 0, 0),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(255, 200, 60),
			remote = "HallOfFame",
		},
	},
}

return HubConfig
