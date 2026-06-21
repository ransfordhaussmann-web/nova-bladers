local HubConfig = {
	ORIGIN = Vector3.new(0, 0, 120),

	FLOOR = {
		size = Vector3.new(80, 1, 80),
		color = Color3.fromRGB(35, 40, 55),
		material = Enum.Material.Slate,
	},

	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,

	SPAWN = Vector3.new(0, 4, 120),

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 2, 152),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(80, 140, 255),
			action = "enterArena",
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			position = Vector3.new(-28, 2, 120),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 180, 60),
			action = "openBeySelect",
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler & deine Stats",
			position = Vector3.new(28, 2, 120),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(200, 160, 80),
			action = "showStats",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(28, 6, 108),
		size = Vector3.new(10, 6, 0.5),
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn" },

	PLAYER_WALK_SPEED = 16,
	PLAYER_JUMP_POWER = 50,

	ZONE_COOLDOWN = 2,
}

return HubConfig
