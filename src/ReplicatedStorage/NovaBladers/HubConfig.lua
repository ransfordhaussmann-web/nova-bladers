local HubConfig = {
	HUB_FOLDER_NAME = "NovaBladersHub",
	ARENA_FOLDER_NAME = "Arena",
	HUB_SPAWN = Vector3.new(0, 4, 0),
	ARENA_SPAWN_OFFSET = Vector3.new(0, 3, 0),
	BUILD_HUB_IF_MISSING = true,

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_COLOR = Color3.fromRGB(45, 50, 65),

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(42, 0.5, 0),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(220, 90, 70),
			action = "enterArena",
			promptText = "Arena betreten",
		},
		{
			id = "beySelect",
			name = "Bey-Werkstatt",
			hint = "Wähle deinen Bey",
			position = Vector3.new(-42, 0.5, 0),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(70, 140, 220),
			action = "openBeySelect",
			promptText = "Bey wählen",
		},
		{
			id = "stats",
			name = "Statuen-Halle",
			hint = "Sieh Stats & Rangliste",
			position = Vector3.new(0, 0.5, 42),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(200, 170, 60),
			action = "showLobby",
			promptText = "Stats anzeigen",
		},
	},
}

return HubConfig
