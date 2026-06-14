--[[
	Layout for the Nova Bladers 3D lobby hub.
	Coordinates are relative to HubOrigin (center of the plaza).
]]

local HubConfig = {
	ORIGIN = Vector3.new(0, 0, -120),

	FLOOR_SIZE = Vector2.new(96, 96),
	FLOOR_HEIGHT = 1,
	WALL_HEIGHT = 14,

	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	ZONES = {
		ArenaPortal = {
			offset = Vector3.new(0, 0, -38),
			size = Vector3.new(14, 12, 6),
			label = "Arena",
			prompt = "Kampf starten",
		},
		BeyBooth = {
			offset = Vector3.new(-32, 0, 0),
			size = Vector3.new(10, 10, 10),
			label = "Bey-Wahl",
			prompt = "Bey auswählen",
		},
		StatsKiosk = {
			offset = Vector3.new(0, 0, 32),
			size = Vector3.new(8, 8, 8),
			label = "Statistik",
			prompt = "Stats anzeigen",
		},
		Leaderboard = {
			offset = Vector3.new(32, 0, 0),
			size = Vector3.new(10, 12, 4),
			label = "Rangliste",
			prompt = "Top 5 anzeigen",
		},
	},

	ARENA_SPAWN_OFFSET = Vector3.new(0, 6, 0),

	COLORS = {
		Floor = Color3.fromRGB(28, 32, 48),
		FloorAccent = Color3.fromRGB(45, 55, 80),
		Wall = Color3.fromRGB(18, 22, 36),
		Neon = Color3.fromRGB(80, 180, 255),
		Portal = Color3.fromRGB(120, 200, 255),
		Booth = Color3.fromRGB(255, 180, 60),
		Kiosk = Color3.fromRGB(140, 220, 160),
		Board = Color3.fromRGB(200, 120, 255),
	},

	AMBIENT = Color3.fromRGB(55, 65, 90),
	OUTDOOR_AMBIENT = Color3.fromRGB(90, 100, 130),
	FOG_COLOR = Color3.fromRGB(35, 40, 60),
	FOG_START = 80,
	FOG_END = 220,
}

return HubConfig
