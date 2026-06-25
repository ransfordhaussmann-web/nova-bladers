local HubConfig = {
	USE_3D_HUB = true,
	HUB_FOLDER_NAME = "NovaHub",
	SPAWN_POSITION = Vector3.new(0, 4, 0),
	HUB_SIZE = Vector3.new(72, 1, 72),
	WALL_HEIGHT = 14,

	ZONES = {
		ArenaGate = {
			id = "ArenaGate",
			label = "Arena-Tor",
			hint = "Betrete die Spin-Arena und kämpfe!",
			action = "EnterArena",
			position = Vector3.new(0, 0, -28),
			size = Vector3.new(14, 8, 6),
			color = Color3.fromRGB(255, 90, 70),
		},
		BeyLab = {
			id = "BeyLab",
			label = "Bey-Labor",
			hint = "Wähle deinen Bey und passe dein Loadout an.",
			action = "OpenBeySelect",
			position = Vector3.new(-26, 0, 12),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(80, 160, 255),
		},
		HallOfFame = {
			id = "HallOfFame",
			label = "Ruhmeshalle",
			hint = "Sieh dir die Top-Spieler und deine Stats an.",
			action = "ShowStats",
			position = Vector3.new(26, 0, 12),
			size = Vector3.new(12, 8, 12),
			color = Color3.fromRGB(255, 200, 60),
		},
	},
}

return HubConfig
