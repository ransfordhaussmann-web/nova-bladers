local HubConfig = {
	ARENA_FOLDER_NAME = "Arena",
	HUB_FOLDER_NAME = "NovaHub",

	SPAWN_POSITION = Vector3.new(0, 3, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 120),

	ZONES = {
		ArenaGate = {
			name = "Arena Gate",
			position = Vector3.new(0, 1, -42),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(80, 140, 255),
			promptAction = "EnterArena",
			promptText = "Arena betreten",
		},
		BeyGarage = {
			name = "Bey Garage",
			position = Vector3.new(-38, 1, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
			promptAction = "OpenBeySelect",
			promptText = "Bey wählen",
		},
		HallOfFame = {
			name = "Hall of Fame",
			position = Vector3.new(38, 1, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(140, 80, 220),
			promptAction = "ShowLeaderboard",
			promptText = "Rangliste ansehen",
		},
	},

	USE_3D_HUB = true,
}

return HubConfig
