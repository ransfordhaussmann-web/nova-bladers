local HubConfig = {
	-- Hub-Mitte; in Studio an die Arena-Position anpassen
	ORIGIN = Vector3.new(0, 0, 0),

	SPAWN_CFRAME = CFrame.new(0, 4, 0),
	ARENA_ENTRY_CFRAME = CFrame.new(0, 4, 120),

	MAP_SIZE = Vector3.new(96, 1, 96),
	WALL_HEIGHT = 12,

	ZONES = {
		Spawn = {
			id = "Spawn",
			label = "Nova Hub",
			center = Vector3.new(0, 0, 0),
			size = Vector3.new(18, 1, 18),
			color = Color3.fromRGB(55, 65, 90),
		},
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			prompt = "Arena betreten",
			center = Vector3.new(0, 0, -38),
			size = Vector3.new(14, 1, 10),
			color = Color3.fromRGB(255, 120, 60),
			glowColor = Color3.fromRGB(255, 160, 80),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			prompt = "Bey wählen",
			center = Vector3.new(34, 0, 0),
			size = Vector3.new(16, 1, 16),
			color = Color3.fromRGB(80, 140, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			prompt = "Statistiken anzeigen",
			center = Vector3.new(-34, 0, 0),
			size = Vector3.new(16, 1, 16),
			color = Color3.fromRGB(200, 170, 60),
		},
	},

	SHOW_LOBBY_PANEL_ZONES = {
		HallOfFame = true,
		Spawn = true,
	},
}

return HubConfig
