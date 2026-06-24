local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_Y = 0,

	WALL_HEIGHT = 16,
	WALL_THICKNESS = 2,

	ARENA_TELEPORT = {
		path = "Workspace.Arena.Bowl.Spawn",
		fallback = CFrame.new(0, 5, 0),
	},

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			action = "enter_arena",
			position = Vector3.new(0, 2, 35),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(80, 140, 255),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			action = "open_bey_select",
			position = Vector3.new(-32, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Globale Top-Spieler",
			action = "view_leaderboard",
			position = Vector3.new(32, 2, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(140, 80, 220),
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(32, 6, -6),
		size = Vector2.new(400, 280),
		face = Enum.NormalId.Front,
	},

	THEME = {
		floor = Color3.fromRGB(28, 32, 48),
		wall = Color3.fromRGB(18, 22, 36),
		accent = Color3.fromRGB(60, 120, 255),
		light = Color3.fromRGB(200, 220, 255),
	},
}

return HubConfig
