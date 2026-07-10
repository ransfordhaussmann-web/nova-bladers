local BeyConfig = {
	MATCH_COUNTDOWN = 3,
	MAX_HP = 100,
	MAX_SPIN = 100,
	MAX_SPECIAL = 100,

	BASE_SPEED = 22,
	CHARGE_SPEED_MULT = 1.4,
	DODGE_SPEED = 40,
	DODGE_DURATION = 0.28,
	SPIN_DECAY = 0.08,

	-- Spin recovery (C key — like Beyblade Evolution RPM boost)
	SPIN_RECOVERY_AMOUNT = 28,
	SPIN_RECOVERY_COOLDOWN = 2.2,
	SPIN_RECOVERY_MAX_VELOCITY = 14,

	-- 3D arena: jump out of bowl / dive back in
	JUMP_FORCE = 52,
	DIVE_FORCE = 44,
	GRAVITY = 80,
	AIR_CONTROL_MULT = 0.65,
	BOWL_FLOOR_OFFSET = 1.5,
	OUTER_PLATFORM_Y = 8,
	OUTER_PLATFORM_RADIUS = 52,
	LANDING_SLAM_DAMAGE = 22,
	LANDING_SLAM_SPIN_LOSS = 10,
	LANDING_SLAM_MIN_FALL_SPEED = 18,

	-- Burst (explode on heavy hit or spin depletion)
	BURST_DAMAGE_THRESHOLD = 28,
	BURST_SPIN_THRESHOLD = 8,

	-- Stat scaling
	ATTACK_DAMAGE_SCALE = 7,
	DEFENSE_REDUCTION_SCALE = 0.35,
	STAMINA_DECAY_SCALE = 7,

	-- Realistic momentum physics
	ACCEL_FORCE = 90,
	COAST_FRICTION = 24,
	TURN_RATE = 5.2,
	MAX_SPEED_MULT = 1.1,
	WALL_BOUNCE = 0.4,
	WALL_FRICTION = 0.8,
	BOWL_PULL = 16,
	ARENA_RADIUS = 36,
	KNOCKBACK_BASE = 16,
	KNOCKBACK_SCALE = 0.5,
	SPECIAL_RUSH_SPEED = 72,

	HIT_DAMAGE = 9,
	HIT_SPIN_LOSS = 4,
	HIT_SPECIAL_GAIN = 14,
	HIT_COOLDOWN = 0.65,

	SPECIAL_DAMAGE = 35,
	SPECIAL_SPIN_LOSS = 15,
	SPECIAL_DURATION = 0.75,
	SPECIAL_COOLDOWN = 1.8,

	SPECIAL_MOVES = {
		--[[ Nova Striker — Pegasus Meteor Shower / Cyber Star Blast ]]
		NovaMeteorShower = {
			id = "NovaMeteorShower",
			name = "Nova Meteor Shower",
			mode = "meteor",
			duration = 1.35,
			rushSpeed = 78,
			damage = 35,
			spinLoss = 14,
			color = Color3.fromRGB(100, 180, 255),
			phases = {
				{ id = "windup", duration = 0.3 },
				{ id = "launch", duration = 0.25, rushSpeed = 78 },
				{ id = "shower", duration = 0.8, hitInterval = 0.18, hitRadius = 5.5, damage = 11, hits = 4 },
			},
		},
		--[[ Iron Shell — Jail Force Wall / underground burrow ]]
		IronVaultLock = {
			id = "IronVaultLock",
			name = "Iron Vault Lock",
			mode = "fortress",
			duration = 1.85,
			damage = 30,
			spinLoss = 8,
			damageReduction = 0.55,
			color = Color3.fromRGB(70, 210, 110),
			phases = {
				{ id = "burrow", duration = 0.45 },
				{ id = "wall", duration = 0.55 },
				{ id = "pulse", duration = 0.85, interval = 0.32, range = 8, damage = 13 },
			},
		},
		--[[ Volt Dash — Sonic Wave / shockwave orbit ]]
		VoltSonicTempest = {
			id = "VoltSonicTempest",
			name = "Volt Sonic Tempest",
			mode = "sonic",
			duration = 1.75,
			damage = 32,
			spinLoss = 12,
			orbitRadius = 6,
			orbitSpeed = 17,
			color = Color3.fromRGB(255, 220, 70),
			phases = {
				{ id = "charge", duration = 0.35 },
				{ id = "sonic", duration = 0.75, interval = 0.28, damage = 9 },
				{ id = "orbit", duration = 0.65 },
			},
		},
		--[[ Shadow Bite — Darkness Howling / Eagle Dive / Venom Strike ]]
		ShadowEclipseFang = {
			id = "ShadowEclipseFang",
			name = "Shadow Eclipse Fang",
			mode = "eclipse",
			duration = 1.15,
			rushSpeed = 92,
			damage = 42,
			spinLoss = 18,
			color = Color3.fromRGB(150, 70, 230),
			phases = {
				{ id = "aura", duration = 0.25 },
				{ id = "dive", duration = 0.4, rushSpeed = 92, diveSpeed = 48 },
				{ id = "burst", duration = 0.35, range = 6.5, damage = 38 },
			},
		},
		--[[ Frost Prism — Crystal barrier / frost slow / shatter wave ]]
		CrystalLockdown = {
			id = "CrystalLockdown",
			name = "Crystal Lockdown",
			mode = "crystal",
			duration = 1.9,
			damage = 28,
			spinLoss = 10,
			damageReduction = 0.5,
			color = Color3.fromRGB(140, 220, 255),
			phases = {
				{ id = "frost", duration = 0.4, range = 7, slowDuration = 1.2 },
				{ id = "shell", duration = 0.65 },
				{ id = "shatter", duration = 0.85, interval = 0.38, range = 9, damage = 14 },
			},
		},
		--[[ Blaze Ripper — Flame spiral / cyclone rush / inferno burst ]]
		InfernoCyclone = {
			id = "InfernoCyclone",
			name = "Inferno Cyclone",
			mode = "inferno",
			duration = 1.6,
			rushSpeed = 80,
			damage = 40,
			spinLoss = 16,
			color = Color3.fromRGB(255, 120, 40),
			phases = {
				{ id = "ignite", duration = 0.3 },
				{ id = "spiral", duration = 0.75, rushSpeed = 80, spinRate = 14 },
				{ id = "burst", duration = 0.55, range = 7.5, damage = 36 },
			},
		},
	},
	STATS_SYNC_INTERVAL = 0.12,

	DUMMY = {
		SPEED = 12,
		ATTACK = 4,
		DEFENSE = 8,
	},

	PLAYER = {
		SPEED = 7,
		ATTACK = 8,
		DEFENSE = 4,
	},

	SELECTION_TIMEOUT = 20,

	SOUNDS = {
		HIT = "rbxassetid://9119723401",
		SPECIAL = "rbxassetid://12222216",
		VICTORY = "rbxassetid://1843532710",
		DEFEAT = "rbxassetid://4960035809",
		SELECT = "rbxassetid://6895079853",
		BURST = "rbxassetid://9119723401",
		SPIN_RECOVER = "rbxassetid://6895079853",
		JUMP = "rbxassetid://12222216",
	},
}

return BeyConfig
