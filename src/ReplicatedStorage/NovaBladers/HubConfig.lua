local HubConfig = {
	HUB_FOLDER = "NovaBladersHub",
	ARENA_FOLDER = "NovaBladersArena",

	-- Hub spawn (character feet on platform)
	SPAWN = Vector3.new(0, 4, 0),
	ARENA_SPAWN = Vector3.new(0, 6, 0),

	PLATFORM_RADIUS = 58,
	PLATFORM_HEIGHT = 2,
	RIM_HEIGHT = 1.2,

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 0, -48),
			radius = 10,
			label = "Arena-Tor",
			prompt = "Arena betreten",
		},
		BeyGarage = {
			position = Vector3.new(48, 0, 0),
			radius = 14,
			label = "Bey-Garage",
			prompt = "Bey wählen",
		},
		HallOfFame = {
			position = Vector3.new(-48, 0, 0),
			radius = 10,
			label = "Hall of Fame",
			prompt = "Rangliste ansehen",
		},
	},

	COLORS = {
		platform = Color3.fromRGB(32, 36, 48),
		platformAccent = Color3.fromRGB(48, 54, 72),
		rim = Color3.fromRGB(70, 110, 200),
		arenaGate = Color3.fromRGB(255, 110, 50),
		beyGarage = Color3.fromRGB(90, 180, 255),
		hallOfFame = Color3.fromRGB(255, 210, 70),
		spawnGlow = Color3.fromRGB(120, 200, 255),
	},

	BEY_PEDESTAL_RADIUS = 22,
	BEY_PEDESTAL_COUNT = 4,

	LEADERBOARD_HEIGHT = 14,
}

return HubConfig
