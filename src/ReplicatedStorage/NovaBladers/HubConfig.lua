local HubConfig = {
	ArenaFolderName = "Arena",
	HubFolderName = "NovaHub",

	FloorSize = Vector3.new(120, 2, 120),
	FloorPosition = Vector3.new(0, 0, -80),

	SpawnOffset = Vector3.new(0, 4, 0),

	Zones = {
		ArenaGate = {
			id = "arena",
			name = "Arena-Tor",
			hint = "Betritt die Arena und kämpfe!",
			position = Vector3.new(0, 3, -30),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 100, 80),
			action = "enterArena",
		},
		BeySelect = {
			id = "beyselect",
			name = "Bey-Werkstatt",
			hint = "Wähle deinen Bey aus",
			position = Vector3.new(-35, 3, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 140, 255),
			action = "openBeySelect",
		},
		Leaderboard = {
			id = "leaderboard",
			name = "Rangliste",
			hint = "Sieh die Top-Spieler",
			position = Vector3.new(35, 3, 0),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 200, 60),
			action = "showLeaderboard",
		},
	},

	WallHeight = 12,
	WallThickness = 2,

	PromptHoldDuration = 0,
	PromptMaxDistance = 10,

	HubLighting = {
		Ambient = Color3.fromRGB(120, 130, 160),
		Brightness = 2,
		ClockTime = 14,
	},
}

return HubConfig
