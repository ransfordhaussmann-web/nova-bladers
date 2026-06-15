local HubConfig = {
	-- Hub world anchor (arena lives elsewhere in the place)
	ORIGIN = Vector3.new(0, 0, 0),

	SPAWN = Vector3.new(0, 4, -8),
	SPAWN_LOOK = Vector3.new(0, 4, 20),

	FLOOR = {
		size = Vector3.new(96, 1, 96),
		color = Color3.fromRGB(28, 32, 48),
		material = Enum.Material.Slate,
	},

	RIM = {
		height = 3,
		thickness = 2,
		color = Color3.fromRGB(60, 120, 220),
	},

	-- Walkable zones (center + half-size on XZ plane)
	ZONES = {
		ArenaGate = {
			center = Vector3.new(0, 0.5, 32),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(255, 180, 60),
			label = "Arena",
			prompt = "Arena betreten",
			action = "enterArena",
		},
		BeyStation = {
			center = Vector3.new(-28, 0.5, 0),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(80, 140, 255),
			label = "Bey-Wahl",
			prompt = "Bey wählen",
			action = "openBeySelect",
		},
		Leaderboard = {
			center = Vector3.new(28, 0.5, 0),
			size = Vector3.new(12, 1, 12),
			color = Color3.fromRGB(255, 215, 80),
			label = "Rangliste",
			prompt = nil,
			action = nil,
		},
		Stats = {
			center = Vector3.new(0, 0.5, -28),
			size = Vector3.new(20, 1, 10),
			color = Color3.fromRGB(120, 200, 160),
			label = "Deine Stats",
			prompt = nil,
			action = nil,
		},
	},

	-- Teleport target when leaving hub (arena bowl center; place-specific)
	ARENA_SPAWN = Vector3.new(0, 6, 200),

	PROXIMITY_RANGE = 10,
}

return HubConfig
