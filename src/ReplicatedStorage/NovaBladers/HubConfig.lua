local HubConfig = {
	SPAWN = Vector3.new(0, 3.5, -25),
	FLOOR_SIZE = Vector3.new(120, 1, 90),
	FLOOR_Y = 2,
	WALL_HEIGHT = 14,

	ZONES = {
		{
			id = "arena_gate",
			name = "Arena-Tor",
			hint = "Betrete die Arena",
			action = "enter_arena",
			position = Vector3.new(0, 3.5, 32),
			size = Vector3.new(18, 10, 6),
			color = Color3.fromRGB(255, 120, 60),
		},
		{
			id = "bey_lab",
			name = "Bey-Labor",
			hint = "Wähle deinen Bey",
			action = "open_bey_select",
			position = Vector3.new(-38, 3.5, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 160, 255),
		},
		{
			id = "hall_of_fame",
			name = "Ruhmeshalle",
			hint = "Top-Spieler ansehen",
			action = "none",
			position = Vector3.new(38, 3.5, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 210, 80),
		},
	},

	ARENA_SPAWN_NAMES = { "Spawn", "ArenaSpawn", "PlayerSpawn" },
	ARENA_PATHS = {
		"Workspace.Arena.Bowl.Spawn",
		"Workspace.Arena.Spawn",
		"Workspace.Bowl.Spawn",
	},
}

return HubConfig
