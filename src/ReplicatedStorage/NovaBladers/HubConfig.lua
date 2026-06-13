local HubConfig = {
	HUB_FOLDER_NAME = "NovaHub",
	ARENA_FOLDER_NAME = "Arena",

	-- Hub geometry (studs)
	FLOOR_SIZE = Vector3.new(120, 2, 120),
	SPAWN_POSITION = Vector3.new(0, 4, 0),

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena",
			position = Vector3.new(0, 2, -42),
			size = Vector3.new(18, 1, 14),
			color = Color3.fromRGB(255, 90, 70),
			promptAction = "EnterArena",
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Nova-Blader",
			position = Vector3.new(-38, 2, 18),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(80, 160, 255),
			promptAction = "OpenBeySelect",
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Sieh deine Stats & das Leaderboard",
			position = Vector3.new(38, 2, 18),
			size = Vector3.new(14, 1, 14),
			color = Color3.fromRGB(255, 200, 60),
			promptAction = "ShowLobbyStats",
		},
	},

	-- Where players land when leaving the arena
	RETURN_SPAWN_OFFSET = Vector3.new(0, 4, 8),

	-- Arena spawn offset from arena center (used when arena exists)
	ARENA_SPAWN_OFFSET = Vector3.new(0, 6, 0),
}

return HubConfig
