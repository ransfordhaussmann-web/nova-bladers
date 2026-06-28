-- Hub layout constants. Adjust ORIGIN and ARENA_SPAWN_OFFSET to match your Place.
local HubConfig = {
	ORIGIN = Vector3.new(0, 0, 0),
	ARENA_SPAWN_OFFSET = Vector3.new(0, 5, 200),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	SPAWN_OFFSET = Vector3.new(0, 3, 0),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			name = "Arena-Tor",
			subtitle = "Betrete die Arena",
			position = Vector3.new(0, 0, -45),
			size = Vector3.new(16, 12, 4),
			color = Color3.fromRGB(255, 100, 60),
			action = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			name = "Bey-Labor",
			subtitle = "Wähle deinen Bey",
			position = Vector3.new(-35, 0, 10),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 140, 255),
			action = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			name = "Ruhmeshalle",
			subtitle = "Stats & Rangliste",
			position = Vector3.new(35, 0, 10),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 80),
			action = "OpenLobby",
		},
	},

	GATE_GLOW_COLOR = Color3.fromRGB(255, 140, 60),
	ZONE_CHECK_INTERVAL = 0.35,
}

return HubConfig
