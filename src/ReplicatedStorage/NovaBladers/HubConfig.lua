local HubConfig = {
	USE_3D_HUB = true,
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",
	HUB_SPAWN = Vector3.new(0, 4, 0),
	ARENA_SPAWN_OFFSET = Vector3.new(0, 3, 0),
	FLOOR_SIZE = Vector3.new(72, 1, 72),
	LEADERBOARD_DISPLAY_COUNT = 5,
	ZONES = {
		{
			id = "Arena",
			name = "Arena Gate",
			prompt = "Kampf starten",
			color = Color3.fromRGB(255, 90, 60),
			offset = Vector3.new(24, 0.5, 0),
			action = "EnterArena",
		},
		{
			id = "BeySelect",
			name = "Bey Garage",
			prompt = "Bey wählen",
			color = Color3.fromRGB(80, 140, 255),
			offset = Vector3.new(-12, 0.5, 20),
			action = "OpenBeySelect",
		},
		{
			id = "Leaderboard",
			name = "Hall of Fame",
			prompt = "Rangliste ansehen",
			color = Color3.fromRGB(255, 200, 60),
			offset = Vector3.new(-12, 0.5, -20),
			action = "ShowLeaderboard",
		},
	},
}

return HubConfig
