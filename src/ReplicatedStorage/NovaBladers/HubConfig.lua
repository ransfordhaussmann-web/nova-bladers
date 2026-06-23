local HubConfig = {
	FOLDER_NAME = "NovaHub",
	SPAWN = Vector3.new(0, 3.5, -25),

	FLOOR_SIZE = Vector3.new(120, 1, 80),
	FLOOR_CENTER = Vector3.new(0, 0, 0),
	WALL_HEIGHT = 16,

	ZONES = {
		ArenaGate = {
			id = "arena_gate",
			label = "Arena-Tor",
			hint = "Drücke E um die Arena zu betreten",
			action = "enter_arena",
			center = Vector3.new(0, 1, 25),
			size = Vector3.new(20, 8, 12),
			color = Color3.fromRGB(255, 90, 70),
		},
		BeyLab = {
			id = "bey_lab",
			label = "Bey-Labor",
			hint = "Drücke E um deinen Bey zu wählen",
			action = "open_bey_select",
			center = Vector3.new(-35, 1, 0),
			size = Vector3.new(16, 8, 16),
			color = Color3.fromRGB(80, 160, 255),
		},
		HallOfFame = {
			id = "hall_of_fame",
			label = "Ruhmeshalle",
			hint = "Top-Spieler der Nova Bladers Liga",
			action = "none",
			center = Vector3.new(35, 1, 0),
			size = Vector3.new(16, 8, 16),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	LEADERBOARD_BOARD = {
		partCFrame = CFrame.new(35, 8, -8) * CFrame.Angles(0, math.rad(-90), 0),
		partSize = Vector3.new(0.5, 10, 14),
		guiSize = Vector2.new(600, 400),
	},
}

return HubConfig
