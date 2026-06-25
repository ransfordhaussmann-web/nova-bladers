local HubConfig = {
	ORIGIN = Vector3.new(0, 0, -150),
	SPAWN = Vector3.new(0, 4, -150),
	PLATFORM_RADIUS = 50,
	PLATFORM_HEIGHT = 1.2,

	ZONES = {
		ArenaGate = {
			position = Vector3.new(0, 0, -108),
			size = Vector3.new(14, 12, 4),
		},
		Leaderboard = {
			position = Vector3.new(-22, 0, -142),
			size = Vector3.new(12, 10, 1.5),
			rotation = 18,
		},
		StatsBoard = {
			position = Vector3.new(22, 0, -142),
			size = Vector3.new(12, 10, 1.5),
			rotation = -18,
		},
		BeyShowcase = {
			position = Vector3.new(0, 0, -178),
			radius = 14,
		},
	},

	COLORS = {
		Platform = Color3.fromRGB(32, 36, 52),
		PlatformAccent = Color3.fromRGB(48, 54, 78),
		Rim = Color3.fromRGB(80, 140, 255),
		Gate = Color3.fromRGB(255, 190, 70),
		GateGlow = Color3.fromRGB(255, 220, 120),
		Pedestal = Color3.fromRGB(55, 60, 80),
	},

	LABELS = {
		HubTitle = "Nova Bladers Hub",
		ArenaPrompt = "Arena betreten",
		ModeTraining = "Modus: Training (allein)",
		ModePvP = "Modus: 1v1 PvP",
		ModeFFA = "Modus: FFA (%d Spieler)",
	},
}

function HubConfig.worldPosition(localOffset)
	return HubConfig.ORIGIN + localOffset
end

return HubConfig
