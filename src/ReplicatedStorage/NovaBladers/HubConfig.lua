local HubConfig = {
	HUB_FOLDER_NAME = "NovaBladersHub",
	SPAWN_POSITION = Vector3.new(0, 4, 12),
	SPAWN_LOOK_AT = Vector3.new(0, 4, -20),

	FLOOR_SIZE = Vector3.new(96, 2, 96),
	WALL_HEIGHT = 8,

	ZONES = {
		arena_gate = {
			id = "arena_gate",
			label = "Arena-Tor",
			prompt = "Arena betreten",
			position = Vector3.new(0, 4, -32),
			size = Vector3.new(14, 10, 4),
			color = Color3.fromRGB(255, 90, 70),
		},
		bey_lab = {
			id = "bey_lab",
			label = "Bey-Labor",
			prompt = "Bey wählen",
			position = Vector3.new(-30, 4, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(80, 140, 255),
		},
		hall_of_fame = {
			id = "hall_of_fame",
			label = "Ruhmeshalle",
			prompt = "Bestenliste ansehen",
			position = Vector3.new(30, 4, 0),
			size = Vector3.new(10, 8, 10),
			color = Color3.fromRGB(255, 200, 60),
		},
	},

	INTERACT_DISTANCE = 14,
}

return HubConfig
