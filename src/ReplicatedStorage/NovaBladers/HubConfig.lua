local HubConfig = {
	ORIGIN = Vector3.new(0, 100, 0),
	FLOOR = {
		size = Vector3.new(72, 1, 72),
		color = Color3.fromRGB(35, 40, 55),
		material = Enum.Material.Slate,
	},
	WALL_HEIGHT = 8,
	SPAWN_OFFSET = Vector3.new(0, 3, 0),
	ZONES = {
		Arena = {
			offset = Vector3.new(0, 0.6, -28),
			size = Vector3.new(14, 0.2, 10),
			color = Color3.fromRGB(220, 80, 60),
			label = "Arena-Tor",
			prompt = "Kampf starten",
			promptKey = Enum.KeyCode.E,
		},
		BeyLab = {
			offset = Vector3.new(-28, 0.6, 10),
			size = Vector3.new(12, 0.2, 10),
			color = Color3.fromRGB(80, 140, 255),
			label = "Bey-Labor",
			prompt = "Bey wählen",
			promptKey = Enum.KeyCode.E,
		},
		HallOfFame = {
			offset = Vector3.new(28, 0.6, 10),
			size = Vector3.new(12, 0.2, 10),
			color = Color3.fromRGB(255, 200, 60),
			label = "Ruhmeshalle",
			prompt = "Statistiken",
			promptKey = Enum.KeyCode.E,
		},
	},
}

return HubConfig
