local HubConfig = {
	SPAWN = Vector3.new(0, 3, 20),
	FLOOR_SIZE = Vector3.new(80, 1, 80),
	FLOOR_Y = 0,

	Colors = {
		Floor = Color3.fromRGB(28, 32, 48),
		Wall = Color3.fromRGB(18, 22, 36),
		Accent = Color3.fromRGB(80, 140, 255),
		Arena = Color3.fromRGB(255, 90, 70),
		BeyLab = Color3.fromRGB(90, 220, 140),
		Hall = Color3.fromRGB(255, 200, 80),
	},

	Zones = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			position = Vector3.new(0, 1, -28),
			size = Vector3.new(14, 8, 6),
			colorKey = "Arena",
			hint = "Betrete die Arena und starte einen Kampf.",
			action = "arena",
			promptText = "Arena betreten",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			position = Vector3.new(-26, 1, 0),
			size = Vector3.new(10, 8, 10),
			colorKey = "BeyLab",
			hint = "Wähle deinen Bey vor dem Kampf.",
			action = "beySelect",
			promptText = "Bey auswählen",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			position = Vector3.new(26, 1, 0),
			size = Vector3.new(10, 8, 10),
			colorKey = "Hall",
			hint = "Die besten Kämpfer der Nova-Arena.",
			action = "leaderboard",
			promptText = "Rangliste ansehen",
		},
	},
}

return HubConfig
