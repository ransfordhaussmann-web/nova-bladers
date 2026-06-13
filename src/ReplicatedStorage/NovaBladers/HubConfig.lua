local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	HUB_ORIGIN = Vector3.new(0, 0, -200),
	HUB_SPAWN = Vector3.new(0, 6, -200),
	ARENA_SPAWN = Vector3.new(0, 6, 0),

	HUB_PLATFORM_SIZE = Vector3.new(96, 2, 96),
	TERMINAL_OFFSET = Vector3.new(-18, 5, -12),
	PORTAL_OFFSET = Vector3.new(18, 5, -12),
	BEY_STATION_OFFSET = Vector3.new(0, 5, 22),

	PLAYER_ATTR_IN_HUB = "NovaInHub",
	PLAYER_ATTR_IN_ARENA = "NovaInArena",
}

return HubConfig
