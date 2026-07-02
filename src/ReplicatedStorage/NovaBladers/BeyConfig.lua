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
		StarfallRush = {
			vfx = "StarfallRush",
			mode = "rush",
			duration = 0.75,
			rushSpeed = 72,
			damage = 35,
			spinLoss = 15,
			color = Color3.fromRGB(120, 200, 255),
		},
		ShellGuard = {
			vfx = "ShellGuard",
			mode = "guard",
			duration = 1.4,
			rushSpeed = 8,
			damage = 14,
			spinLoss = 6,
			damageReduction = 0.5,
			pulseInterval = 0.35,
			pulseRange = 7,
			color = Color3.fromRGB(80, 200, 120),
		},
		ThunderLoop = {
			vfx = "ThunderLoop",
			mode = "orbit",
			duration = 0.9,
			rushSpeed = 58,
			damage = 28,
			spinLoss = 12,
			orbitRadius = 5,
			orbitSpeed = 14,
			color = Color3.fromRGB(255, 220, 80),
		},
		NightFang = {
			vfx = "NightFang",
			mode = "lunge",
			duration = 0.5,
			rushSpeed = 88,
			damage = 42,
			spinLoss = 18,
			color = Color3.fromRGB(160, 80, 240),
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
