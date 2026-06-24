local HubConfig = {
	HUB_NAME = "NovaHub",
	SPAWN_CFRAME = CFrame.new(0, 3.5, -25),

	FLOOR = {
		size = Vector3.new(80, 1, 80),
		position = Vector3.new(0, 0.5, 0),
		color = Color3.fromRGB(35, 40, 55),
		material = Enum.Material.Slate,
	},

	WALL_HEIGHT = 12,
	WALL_THICKNESS = 2,
	WALL_COLOR = Color3.fromRGB(25, 28, 38),

	ZONES = {
		{
			id = "arena",
			name = "Arena-Tor",
			hint = "Kampf betreten",
			subtitle = "Training · 1v1 · FFA",
			position = Vector3.new(0, 3, 28),
			size = Vector3.new(18, 10, 6),
			color = Color3.fromRGB(220, 70, 70),
			promptAction = "EnterArena",
		},
		{
			id = "beylab",
			name = "Bey-Labor",
			hint = "Bey wählen",
			subtitle = "Loadout anpassen",
			position = Vector3.new(-28, 3, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(80, 140, 255),
			promptAction = "OpenBeySelect",
		},
		{
			id = "halloffame",
			name = "Ruhmeshalle",
			hint = "Rangliste ansehen",
			subtitle = "Top 5 Spieler",
			position = Vector3.new(28, 3, 0),
			size = Vector3.new(14, 10, 14),
			color = Color3.fromRGB(255, 200, 60),
			promptAction = "ViewLeaderboard",
		},
	},

	LEADERBOARD_BOARD = {
		position = Vector3.new(34, 6, 0),
		size = Vector3.new(12, 8, 0.4),
		rotation = CFrame.Angles(0, math.rad(-90), 0),
	},

	SPAWN_SIGN = {
		position = Vector3.new(0, 5, -18),
		text = "Nova Bladers Hub",
		subtitle = "Wähle eine Zone",
	},
}

return HubConfig
