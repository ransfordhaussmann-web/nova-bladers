--[[
	Layout and styling for the Nova Bladers 3D lobby hub.
	Positions are relative to HubWorld root at Workspace.NovaHub.
]]

local HubWorldConfig = {
	ROOT_NAME = "NovaHub",
	ARENA_SPAWN = Vector3.new(0, 4, 0),

	HUB = {
		FLOOR_SIZE = Vector3.new(96, 1, 96),
		FLOOR_Y = 0,
		SPAWN = Vector3.new(0, 4, 18),
		WALL_HEIGHT = 14,
	},

	ZONES = {
		ArenaPortal = {
			id = "ArenaPortal",
			position = Vector3.new(0, 1, -30),
			size = Vector3.new(14, 0.4, 10),
			radius = 7,
			label = "Arena",
			hint = "Betritt die Spin-Arena",
			color = Color3.fromRGB(80, 160, 255),
		},
		BeySelect = {
			id = "BeySelect",
			position = Vector3.new(-26, 1, 6),
			size = Vector3.new(10, 0.4, 10),
			radius = 6,
			label = "Bey-Wahl",
			hint = "Wähle deinen Bey",
			color = Color3.fromRGB(255, 190, 70),
		},
		Leaderboard = {
			id = "Leaderboard",
			position = Vector3.new(26, 1, 6),
			size = Vector3.new(10, 0.4, 10),
			radius = 6,
			label = "Rangliste",
			hint = "Top-Spieler ansehen",
			color = Color3.fromRGB(120, 220, 140),
		},
	},

	COLORS = {
		Floor = Color3.fromRGB(16, 20, 34),
		FloorAccent = Color3.fromRGB(28, 36, 58),
		Wall = Color3.fromRGB(12, 14, 24),
		Neon = Color3.fromRGB(90, 150, 255),
		Trim = Color3.fromRGB(50, 60, 90),
	},

	LIGHTING = {
		Ambient = Color3.fromRGB(45, 50, 70),
		OutdoorAmbient = Color3.fromRGB(55, 60, 85),
		Brightness = 2.2,
		ClockTime = 17.5,
	},

	PROXIMITY_CHECK_INTERVAL = 0.25,
}

return HubWorldConfig
