local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAMES = { "Arena", "BowlArena", "BattleArena" },

	-- Circular plaza layout (studs)
	PLAZA_RADIUS = 42,
	FLOOR_Y = 0,
	SPAWN_Y = 3.5,

	ZONES = {
		Arena = { angle = 0, distance = 32, label = "Arena-Tor", prompt = "Arena betreten" },
		BeySelect = { angle = 90, distance = 30, label = "Bey-Garage", prompt = "Bey wählen" },
		Stats = { angle = 180, distance = 28, label = "Statistik", prompt = "Stats ansehen" },
		Leaderboard = { angle = 270, distance = 28, label = "Rangliste", prompt = "Top 5 ansehen" },
	},

	BOARD_SIZE = Vector2.new(8, 5),
	LEADERBOARD_SIZE = Vector2.new(8, 6),

	COLORS = {
		Floor = Color3.fromRGB(18, 22, 36),
		FloorAccent = Color3.fromRGB(35, 45, 72),
		Neon = Color3.fromRGB(80, 160, 255),
		NeonAlt = Color3.fromRGB(140, 90, 255),
		Pillar = Color3.fromRGB(28, 32, 48),
		SpawnPad = Color3.fromRGB(45, 55, 90),
	},

	TELEPORT_OFFSET = Vector3.new(0, 4, 0),
}

function HubConfig.getZonePosition(zoneKey)
	local zone = HubConfig.ZONES[zoneKey]
	if not zone then
		return Vector3.new(0, HubConfig.SPAWN_Y, 0)
	end
	local rad = math.rad(zone.angle)
	local x = math.sin(rad) * zone.distance
	local z = -math.cos(rad) * zone.distance
	return Vector3.new(x, HubConfig.SPAWN_Y, z)
end

function HubConfig.getSpawnCFrame()
	return CFrame.new(0, HubConfig.SPAWN_Y, 0)
end

return HubConfig
