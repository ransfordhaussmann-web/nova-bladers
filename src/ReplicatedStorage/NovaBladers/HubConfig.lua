--[[
	3D-Hub-Welt: Layout und Zonen für die begehbare Lobby.
	Wird von HubWorldBuilder (Geometrie) und HubManager (Logik) genutzt.
]]

local HubConfig = {
	-- Abseits der Arena, damit Hub und Match nicht kollidieren
	ORIGIN = Vector3.new(0, 0, -220),

	SPAWN_OFFSET = Vector3.new(0, 4, 0),

	FLOOR = {
		size = Vector3.new(96, 2, 96),
		color = Color3.fromRGB(32, 36, 52),
		material = Enum.Material.Slate,
	},

	PLAZA = {
		radius = 18,
		height = 0.6,
		color = Color3.fromRGB(48, 54, 78),
		material = Enum.Material.SmoothPlastic,
	},

	RING = {
		innerRadius = 22,
		outerRadius = 28,
		height = 0.4,
		color = Color3.fromRGB(56, 62, 88),
	},

	PILLAR = {
		height = 14,
		radius = 1.2,
		color = Color3.fromRGB(70, 78, 110),
	},

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Drücke E — Match starten",
			offset = Vector3.new(0, 0, -34),
			padSize = Vector3.new(14, 1, 10),
			padColor = Color3.fromRGB(90, 140, 255),
			action = "EnterArena",
			prompt = "Arena betreten",
		},
		StatsTerminal = {
			id = "StatsTerminal",
			label = "Statistik-Terminal",
			hint = "Drücke E — Stats & Rangliste",
			offset = Vector3.new(34, 0, 0),
			padSize = Vector3.new(10, 1, 10),
			padColor = Color3.fromRGB(255, 190, 80),
			action = "OpenLobbyUI",
			prompt = "Stats anzeigen",
		},
		TrainingPad = {
			id = "TrainingPad",
			label = "Trainings-Plattform",
			hint = "Solo-Training gegen Dummy",
			offset = Vector3.new(0, 0, 34),
			padSize = Vector3.new(12, 1, 12),
			padColor = Color3.fromRGB(80, 200, 120),
			action = "EnterTraining",
			prompt = "Training starten",
		},
		BeyGallery = {
			id = "BeyGallery",
			label = "Bey-Galerie",
			hint = "Beys ansehen & auswählen",
			offset = Vector3.new(-34, 0, 0),
			padSize = Vector3.new(10, 1, 10),
			padColor = Color3.fromRGB(160, 90, 240),
			action = "OpenBeySelect",
			prompt = "Bey wählen",
		},
	},

	AMBIENT = {
		brightness = 2.4,
		clockTime = 17.5,
		fogColor = Color3.fromRGB(24, 28, 42),
		fogEnd = 400,
		fogStart = 80,
	},

	NEON_ACCENT = Color3.fromRGB(120, 180, 255),
}

function HubConfig.getSpawnCFrame()
	return CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET)
end

function HubConfig.getZoneWorldPosition(zoneKey)
	local zone = HubConfig.ZONES[zoneKey]
	if not zone then
		return HubConfig.ORIGIN
	end
	return HubConfig.ORIGIN + zone.offset
end

return HubConfig
