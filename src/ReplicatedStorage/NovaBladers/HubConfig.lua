local HubConfig = {
	-- Hub floor (walkable plaza)
	FLOOR_SIZE = Vector3.new(120, 2, 120),
	FLOOR_POSITION = Vector3.new(0, 0, -80),
	SPAWN_OFFSET = Vector3.new(0, 4, -80),

	-- Arena portal (walk here to start a match)
	ARENA_PORTAL_POSITION = Vector3.new(0, 3, -50),
	ARENA_PORTAL_SIZE = Vector3.new(14, 10, 3),
	ARENA_PROMPT_RANGE = 10,

	-- Bey selection kiosk
	BEY_KIOSK_POSITION = Vector3.new(-28, 3, -70),
	BEY_KIOSK_SIZE = Vector3.new(8, 6, 8),

	-- Leaderboard display pillar
	LEADERBOARD_POSITION = Vector3.new(28, 3, -70),
	LEADERBOARD_SIZE = Vector3.new(6, 10, 6),

	-- Training info sign
	INFO_SIGN_POSITION = Vector3.new(0, 3, -105),

	-- Decorative ring pillars
	PILLAR_COUNT = 8,
	PILLAR_RADIUS = 48,

	-- Hub lighting tint
	ACCENT_COLOR = Color3.fromRGB(80, 140, 255),
	FLOOR_COLOR = Color3.fromRGB(30, 32, 42),
	PILLAR_COLOR = Color3.fromRGB(50, 55, 70),

	-- Zone detection radius for client hints
	ZONE_RADIUS = 12,
}

return HubConfig
