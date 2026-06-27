local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",

	SPAWN = Vector3.new(0, 4, 0),
	SPAWN_LOOK = Vector3.new(0, 4, -20),

	FLOOR_SIZE = Vector3.new(120, 1, 120),
	FLOOR_COLOR = Color3.fromRGB(28, 32, 48),
	FLOOR_MATERIAL = Enum.Material.Slate,

	ARENA_PORTAL = {
		position = Vector3.new(0, 3, -42),
		size = Vector3.new(14, 10, 2),
		color = Color3.fromRGB(80, 140, 255),
		label = "Arena betreten",
	},
	BEY_STATION = {
		position = Vector3.new(-28, 3, -10),
		size = Vector3.new(8, 6, 8),
		color = Color3.fromRGB(255, 200, 60),
		label = "Bey wählen",
	},
	STATS_KIOSK = {
		position = Vector3.new(28, 3, -10),
		size = Vector3.new(8, 6, 8),
		color = Color3.fromRGB(80, 180, 110),
		label = "Statistiken",
	},
	LEADERBOARD_BOARD = {
		position = Vector3.new(0, 6, 18),
		size = Vector3.new(20, 10, 1),
		color = Color3.fromRGB(140, 80, 220),
		label = "Top Spieler",
	},

	INTERACT_RANGE = 10,
	PORTAL_COOLDOWN = 2,

	REMOTE_NAMES = {
		"EnterArena",
		"LobbyReady",
		"OpenBeySelect",
		"HubState",
		"RefreshHubStats",
	},
}

return HubConfig
