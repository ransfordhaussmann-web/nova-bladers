local HubConfig = {
	FOLDER_NAME = "NovaHub",
	SPAWN_CFRAME = CFrame.new(0, 4, 25),
	FLOOR_SIZE = Vector3.new(100, 1, 100),
	WALL_HEIGHT = 14,
	WALL_THICKNESS = 2,

	COLORS = {
		Floor = Color3.fromRGB(35, 40, 55),
		Wall = Color3.fromRGB(50, 55, 75),
		Accent = Color3.fromRGB(90, 160, 255),
	},

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 0.5, -35),
			size = Vector3.new(18, 1, 12),
			color = Color3.fromRGB(255, 90, 70),
			label = "Arena-Tor",
			promptAction = "Arena betreten",
			promptObject = "Arena-Tor",
		},
		BeyLab = {
			position = Vector3.new(-32, 0.5, 0),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(80, 200, 255),
			label = "Bey-Labor",
			promptAction = "Bey wählen",
			promptObject = "Bey-Labor",
		},
		HallOfFame = {
			position = Vector3.new(32, 0.5, 0),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(255, 200, 60),
			label = "Ruhmeshalle",
			promptAction = "Stats ansehen",
			promptObject = "Ruhmeshalle",
		},
	},
}

return HubConfig
