local HubConfig = {
	HubFolderName = "NovaHub",
	SpawnName = "HubSpawn",

	FloorSize = Vector3.new(120, 1, 120),
	FloorPosition = Vector3.new(0, 0, 0),
	WallHeight = 12,
	WallThickness = 2,

	Colors = {
		Floor = Color3.fromRGB(35, 40, 55),
		Wall = Color3.fromRGB(50, 55, 75),
		Accent = Color3.fromRGB(80, 140, 255),
	},

	Zones = {
		{
			id = "ArenaGate",
			name = "Arena-Tor",
			hint = "Drücke E — Kampf starten",
			position = Vector3.new(0, 1, -42),
			size = Vector3.new(18, 8, 6),
			color = Color3.fromRGB(255, 90, 70),
			action = "EnterArena",
		},
		{
			id = "BeyLab",
			name = "Bey-Labor",
			hint = "Drücke E — Bey wählen",
			position = Vector3.new(-42, 1, 0),
			size = Vector3.new(6, 8, 18),
			color = Color3.fromRGB(80, 200, 255),
			action = "OpenBeySelect",
		},
		{
			id = "HallOfFame",
			name = "Ruhmeshalle",
			hint = "Drücke E — Stats anzeigen",
			position = Vector3.new(42, 1, 0),
			size = Vector3.new(6, 8, 18),
			color = Color3.fromRGB(255, 200, 60),
			action = "ShowHallPanel",
		},
	},

	ArenaSpawnPaths = {
		"Workspace.ArenaSpawn",
		"Workspace.Arena.ArenaSpawn",
	},
	ArenaFallback = Vector3.new(0, 5, 80),
}

return HubConfig
