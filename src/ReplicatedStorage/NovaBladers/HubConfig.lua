local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_OFFSET = Vector3.new(0, 0, 500),

	SPAWN = Vector3.new(0, 4, 0),
	FLOOR_SIZE = Vector3.new(120, 1, 100),
	WALL_HEIGHT = 16,

	ZONE_CHECK_INTERVAL = 0.35,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Drücke E um in die Arena zu gehen",
			color = Color3.fromRGB(255, 120, 80),
			center = Vector3.new(0, 1, -38),
			size = Vector3.new(28, 8, 18),
			action = "enterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Drücke E um deinen Bey zu wählen",
			color = Color3.fromRGB(80, 160, 255),
			center = Vector3.new(-42, 1, 18),
			size = Vector3.new(22, 8, 22),
			action = "openBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Deine Stats und das Leaderboard",
			color = Color3.fromRGB(255, 200, 80),
			center = Vector3.new(42, 1, 18),
			size = Vector3.new(22, 8, 22),
			action = "showStats",
		},
	},
}

function HubConfig.isInsideZone(zone, position)
	local half = zone.size * 0.5
	local delta = position - zone.center
	return math.abs(delta.X) <= half.X
		and math.abs(delta.Y) <= half.Y + 4
		and math.abs(delta.Z) <= half.Z
end

return HubConfig
