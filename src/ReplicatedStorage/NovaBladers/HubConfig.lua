local HubConfig = {
	ORIGIN = Vector3.new(0, 0, 0),
	SPAWN_CFRAME = CFrame.new(0, 3, 25),
	ARENA_TELEPORT_CFRAME = CFrame.new(0, 5, 0),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	WALL_HEIGHT = 6,

	ZONES = {
		Spawn = {
			id = "Spawn",
			center = Vector3.new(0, 0, 25),
			size = Vector3.new(20, 8, 20),
			hint = "Willkommen im Nova Hub!",
		},
		ArenaGate = {
			id = "ArenaGate",
			center = Vector3.new(0, 0, -30),
			size = Vector3.new(24, 8, 16),
			hint = "Arena-Tor — nutze das Pad zum Betreten",
		},
		BeyLab = {
			id = "BeyLab",
			center = Vector3.new(-35, 0, 0),
			size = Vector3.new(18, 8, 18),
			hint = "Bey-Labor — wähle deinen Kämpfer",
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			center = Vector3.new(35, 0, 0),
			size = Vector3.new(18, 8, 18),
			hint = "Ruhmeshalle — Top-Spieler",
			action = "showStats",
		},
	},

	COLORS = {
		Floor = Color3.fromRGB(35, 38, 55),
		FloorAccent = Color3.fromRGB(50, 55, 80),
		Wall = Color3.fromRGB(28, 30, 42),
		ArenaPad = Color3.fromRGB(80, 140, 255),
		BeyLab = Color3.fromRGB(140, 80, 220),
		HallOfFame = Color3.fromRGB(255, 200, 60),
		Sign = Color3.fromRGB(220, 220, 230),
	},
}

return HubConfig
