local HubWorldConfig = {
	-- Hub sits north of the bowl arena so both can coexist in one place.
	ORIGIN = Vector3.new(0, 0, -120),
	FLOOR_SIZE = Vector3.new(88, 1, 88),
	WALL_HEIGHT = 14,

	SPAWN_OFFSET = Vector3.new(0, 4, 8),
	ARENA_PORTAL_OFFSET = Vector3.new(0, 1.5, -28),
	ARENA_SPAWN = Vector3.new(0, 6, 0),

	BEY_PEDESTAL_RADIUS = 24,
	BEY_PEDESTAL_HEIGHT = 3,

	COLORS = {
		Floor = Color3.fromRGB(22, 26, 42),
		Accent = Color3.fromRGB(90, 160, 255),
		Portal = Color3.fromRGB(255, 190, 70),
		Wall = Color3.fromRGB(14, 16, 28),
		Neon = Color3.fromRGB(120, 200, 255),
	},

	LIGHTING = {
		Ambient = Color3.fromRGB(55, 60, 85),
		Brightness = 2.4,
		ClockTime = 17.5,
	},
}

function HubWorldConfig.getSpawnPosition()
	return HubWorldConfig.ORIGIN + HubWorldConfig.SPAWN_OFFSET
end

function HubWorldConfig.getPortalPosition()
	return HubWorldConfig.ORIGIN + HubWorldConfig.ARENA_PORTAL_OFFSET
end

return HubWorldConfig
