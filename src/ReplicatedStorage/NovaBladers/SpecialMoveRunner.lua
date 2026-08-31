local BeyConfig = require(script.Parent.BeyConfig)
local SpecialVFX = require(script.Parent.SpecialVFX)

local SpecialMoveRunner = {}

local function getTargetPos(controller, target)
	if target and target.part then
		return target.part.Position
	end
	return controller.part.Position + controller.facing * 12
end

local function advancePhase(controller, move)
	local phases = move.phases
	local nextIdx = (controller.specialPhaseIdx or 1) + 1
	if nextIdx > #phases then
		return false
	end
	controller.specialPhaseIdx = nextIdx
	local phase = phases[nextIdx]
	controller.specialPhaseEnd = os.clock() + phase.duration
	controller.specialPhase = phase
	SpecialMoveRunner.onPhaseStart(controller, move, phase)
	return true
end

local function aimAtTarget(controller, target, rushSpeed)
	local dir = (getTargetPos(controller, target) - controller.part.Position)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	controller.facing = dir
	controller.velocity = dir * rushSpeed
end

local function startOrbit(controller, move, target)
	if not target or not target.part then
		return
	end
	controller.orbitCenter = target.part.Position
	controller.orbitAngle = math.atan2(
		controller.part.Position.Z - target.part.Position.Z,
		controller.part.Position.X - target.part.Position.X
	)
	controller.orbitRadius = move.orbitRadius or 6
	controller.orbitSpeed = move.orbitSpeed or 16
end

local function updateOrbit(controller, dt, allControllers)
	if not controller.orbitCenter then
		return
	end
	controller.orbitAngle += (controller.orbitSpeed or 16) * dt
	local r = controller.orbitRadius or 6
	local center = controller.orbitCenter
	if controller.specialTarget and controller.specialTarget.part then
		center = controller.specialTarget.part.Position
		controller.orbitCenter = center
	end
	local y = controller.part.Position.Y
	local pos = center + Vector3.new(math.cos(controller.orbitAngle) * r, 0, math.sin(controller.orbitAngle) * r)
	controller.part.CFrame = CFrame.new(Vector3.new(pos.X, y, pos.Z), center)
	controller.velocity = Vector3.zero
	controller:checkCollisions(allControllers, true)
end

local PHASE_START = {
	meteor = {
		windup = function(controller, move, phase)
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		end,
		launch = function(controller, move, phase, target)
			aimAtTarget(controller, target, phase.rushSpeed or move.rushSpeed)
		end,
		shower = function(controller, move, phase)
			controller.meteorHitsLeft = phase.hits or 4
			controller.meteorTimer = 0
		end,
	},
	fortress = {
		burrow = function(controller, move)
			SpecialVFX.setUnderground(controller, true)
			SpecialVFX.burrowCloud(controller, move.color)
			controller.velocity = Vector3.zero
		end,
		wall = function(controller, move, phase)
			SpecialVFX.setUnderground(controller, false)
			controller.guardReduction = move.damageReduction or 0.55
			SpecialVFX.wallRing(controller, move.color, phase.duration)
		end,
		pulse = function(controller)
			controller.pulseTimer = 0
		end,
	},
	sonic = {
		charge = function(controller, move, phase)
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		end,
		sonic = function(controller)
			controller.sonicTimer = 0
			controller.sonicCount = 0
		end,
		orbit = function(controller, move, _, target)
			startOrbit(controller, move, target)
		end,
	},
	eclipse = {
		aura = function(controller, move, phase)
			SpecialVFX.darkAura(controller, move.color, phase.duration)
			controller.verticalVelocity = 18
			controller.airborne = true
		end,
		dive = function(controller, move, phase, target)
			local targetPos = getTargetPos(controller, target)
			SpecialVFX.diveTrail(controller, targetPos, move.color, SpecialVFX.ensureFolder(controller))
			local dir = (targetPos - controller.part.Position)
			dir = Vector3.new(dir.X, -0.4, dir.Z).Unit
			controller.facing = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
			controller.verticalVelocity = -(phase.diveSpeed or 40)
		end,
		burst = function(controller, move)
			SpecialVFX.venomBurst(controller.part.Position, move.color, SpecialVFX.ensureFolder(controller))
		end,
	},
	feather = {
		windup = function(controller, move, phase)
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		end,
		spiral = function(controller, move, phase)
			controller.featherTimer = 0
			controller.featherHitsLeft = phase.hits or 4
			controller.featherAngle = 0
		end,
		burst = function(controller, move)
			SpecialVFX.featherBurst(controller.part.Position, move.color, SpecialVFX.ensureFolder(controller))
		end,
	},
	slam = {
		rise = function(controller, _, phase)
			controller.velocity = Vector3.zero
			controller.verticalVelocity = phase.riseSpeed or 38
			controller.airborne = true
		end,
		hang = function(controller)
			controller.velocity = Vector3.zero
			controller.verticalVelocity = 0
		end,
		slam = function(controller, move, phase, target)
			local targetPos = getTargetPos(controller, target)
			local dir = (targetPos - controller.part.Position)
			dir = Vector3.new(dir.X, -1, dir.Z).Unit
			controller.facing = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.velocity = controller.facing * (phase.slamSpeed or 50)
			controller.verticalVelocity = -(phase.slamSpeed or 65)
		end,
		wave = function(controller)
			controller.waveTriggered = false
		end,
	},
	rush = {
		focus = function(controller, move, phase)
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		end,
		lunge = function(controller, move, phase, target)
			aimAtTarget(controller, target, phase.rushSpeed or move.rushSpeed)
		end,
		rend = function(controller)
			controller.rendTimer = 0
		end,
	},
	rampart = {
		roots = function(controller, move, phase)
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		end,
		wall = function(controller, move, phase)
			controller.guardReduction = move.damageReduction or 0.5
			SpecialVFX.stoneRampart(controller, move.color, phase.duration)
		end,
		shatter = function(controller)
			controller.shatterTimer = 0
		end,
	},
	flare = {
		charge = function(controller, move, phase)
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		end,
		loop = function(controller, move, _, target)
			startOrbit(controller, move, target)
			controller.flareTimer = 0
		end,
		flare = function(controller)
			controller.flareBurstDone = false
		end,
	},
	phantom = {
		phase = function(controller, move, phase)
			SpecialVFX.setPhased(controller, true)
			SpecialVFX.darkAura(controller, move.color, phase.duration)
		end,
		dash = function(controller, move, phase, target)
			aimAtTarget(controller, target, phase.rushSpeed or move.rushSpeed)
		end,
		slash = function(controller, move)
			SpecialVFX.setPhased(controller, false)
			SpecialVFX.phaseSlash(controller.part.Position, move.color, SpecialVFX.ensureFolder(controller))
		end,
		fade = function(controller)
			SpecialVFX.setPhased(controller, false)
		end,
	},
}

local PHASE_UPDATE = {
	meteor = {
		windup = function(controller)
			controller.velocity = Vector3.zero
		end,
		launch = function(controller, move, phase)
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 70)
		end,
		shower = function(controller, move, phase, dt, allControllers)
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 70)
			controller.meteorTimer = (controller.meteorTimer or 0) + dt
			if controller.meteorTimer >= (phase.hitInterval or 0.18) then
				controller.meteorTimer = 0
				local pos = controller.part.Position
				local folder = SpecialVFX.ensureFolder(controller)
				SpecialVFX.meteorTrail(controller.meteorLastPos, pos, move.color, folder)
				SpecialVFX.meteorImpact(pos, move.color, folder)
				controller.meteorLastPos = pos
				controller:areaHit(allControllers, phase.hitRadius or 5, phase.damage or 11, true)
			end
		end,
	},
	fortress = {
		burrow = function(controller)
			controller.velocity = Vector3.zero
			local pos = controller.part.Position
			controller.part.CFrame = CFrame.new(Vector3.new(pos.X, controller.floorY - 1.2, pos.Z))
				* (controller.part.CFrame - controller.part.CFrame.Position)
		end,
		wall = function(controller)
			controller.velocity = Vector3.zero
		end,
		pulse = function(controller, move, phase, dt, allControllers)
			controller.pulseTimer = (controller.pulseTimer or 0) + dt
			if controller.pulseTimer >= (phase.interval or 0.35) then
				controller.pulseTimer = 0
				local folder = SpecialVFX.ensureFolder(controller)
				SpecialVFX.pulseWave(controller.part.Position, phase.range or 8, move.color, folder)
				controller:areaHit(allControllers, phase.range or 8, phase.damage or 13, true)
			end
		end,
	},
	sonic = {
		charge = function(controller)
			controller.velocity *= 0.9
		end,
		sonic = function(controller, move, phase, dt, allControllers)
			controller.sonicTimer = (controller.sonicTimer or 0) + dt
			if controller.sonicTimer >= (phase.interval or 0.28) then
				controller.sonicTimer = 0
				controller.sonicCount = (controller.sonicCount or 0) + 1
				local range = 4 + controller.sonicCount * 1.5
				SpecialVFX.sonicRing(controller.part.Position, range, move.color, SpecialVFX.ensureFolder(controller))
				controller:areaHit(allControllers, range, phase.damage or 9, true)
			end
		end,
		orbit = function(controller, _, _, dt, allControllers)
			updateOrbit(controller, dt, allControllers)
		end,
	},
	eclipse = {
		dive = function(controller, move, phase, _, allControllers)
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 85)
			controller:checkCollisions(allControllers, true)
		end,
		burst = function(controller, move, phase, _, allControllers)
			controller:areaHit(allControllers, phase.range or 6, phase.damage or 38, true)
		end,
	},
	feather = {
		windup = function(controller)
			controller.velocity = Vector3.zero
		end,
		spiral = function(controller, move, phase, dt, allControllers)
			controller.featherAngle = (controller.featherAngle or 0) + dt * 8
			local dir = Vector3.new(math.cos(controller.featherAngle), 0, math.sin(controller.featherAngle))
			controller.facing = dir
			controller.velocity = dir * 55
			controller.featherTimer = (controller.featherTimer or 0) + dt
			if controller.featherTimer >= (phase.hitInterval or 0.2) then
				controller.featherTimer = 0
				SpecialVFX.featherBurst(controller.part.Position, move.color, SpecialVFX.ensureFolder(controller))
				controller:areaHit(allControllers, phase.hitRadius or 5, phase.damage or 10, true)
			end
		end,
		burst = function(controller, move, phase, _, allControllers)
			controller:areaHit(allControllers, phase.range or 6, phase.damage or 18, true)
		end,
	},
	slam = {
		rise = function(controller)
			controller.velocity = Vector3.zero
		end,
		hang = function(controller)
			controller.velocity = Vector3.zero
			controller.verticalVelocity = 0
		end,
		slam = function(controller, _, _, _, allControllers)
			controller:checkCollisions(allControllers, true)
		end,
		wave = function(controller, move, phase, _, allControllers)
			if not controller.waveTriggered and controller.verticalVelocity <= 0
				and controller.part.Position.Y <= controller.floorY + 1.5 then
				controller.waveTriggered = true
				controller.verticalVelocity = 0
				controller.velocity = Vector3.zero
				SpecialVFX.slamShockwave(controller.part.Position, phase.range or 9, move.color, SpecialVFX.ensureFolder(controller))
				controller:areaHit(allControllers, phase.range or 9, phase.damage or 22, true)
			end
		end,
	},
	rush = {
		focus = function(controller)
			controller.velocity *= 0.85
		end,
		lunge = function(controller, move, phase, _, allControllers)
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 80)
			controller:checkCollisions(allControllers, true)
		end,
		rend = function(controller, move, phase, dt, allControllers)
			controller.rendTimer = (controller.rendTimer or 0) + dt
			if controller.rendTimer >= (phase.interval or 0.15) then
				controller.rendTimer = 0
				SpecialVFX.bleedSlash(controller.part.Position, move.color, SpecialVFX.ensureFolder(controller))
				controller:areaHit(allControllers, phase.range or 4, phase.damage or 12, true)
			end
		end,
	},
	rampart = {
		roots = function(controller)
			controller.velocity = Vector3.zero
		end,
		wall = function(controller)
			controller.velocity = Vector3.zero
		end,
		shatter = function(controller, move, phase, dt, allControllers)
			controller.shatterTimer = (controller.shatterTimer or 0) + dt
			if controller.shatterTimer >= (phase.interval or 0.3) then
				controller.shatterTimer = 0
				SpecialVFX.pulseWave(controller.part.Position, phase.range or 7, move.color, SpecialVFX.ensureFolder(controller))
				controller:areaHit(allControllers, phase.range or 7, phase.damage or 11, true)
			end
		end,
	},
	flare = {
		charge = function(controller)
			controller.velocity *= 0.9
		end,
		loop = function(controller, move, phase, dt, allControllers)
			updateOrbit(controller, dt, allControllers)
			controller.flareTimer = (controller.flareTimer or 0) + dt
			if controller.flareTimer >= (phase.interval or 0.25) then
				controller.flareTimer = 0
				SpecialVFX.sonicRing(controller.part.Position, 4, move.color, SpecialVFX.ensureFolder(controller))
				controller:areaHit(allControllers, 4, phase.damage or 8, true)
			end
		end,
		flare = function(controller, move, phase, _, allControllers)
			if not controller.flareBurstDone then
				controller.flareBurstDone = true
				SpecialVFX.solarFlare(controller.part.Position, phase.range or 8, move.color, SpecialVFX.ensureFolder(controller))
				controller:areaHit(allControllers, phase.range or 8, phase.damage or 24, true)
			end
		end,
	},
	phantom = {
		phase = function(controller)
			controller.velocity *= 0.7
		end,
		dash = function(controller, move, phase, _, allControllers)
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 90)
			controller:checkCollisions(allControllers, true)
		end,
		slash = function(controller, move, phase, _, allControllers)
			controller:areaHit(allControllers, phase.range or 6, phase.damage or 42, true)
		end,
	},
}

function SpecialMoveRunner.onPhaseStart(controller, move, phase)
	local mode = move.mode
	local handlers = PHASE_START[mode]
	if not handlers then
		return
	end
	local handler = handlers[phase.id]
	if handler then
		handler(controller, move, phase, controller.specialTarget)
	end
end

function SpecialMoveRunner.run(controller, moveId, targetController)
	local move = BeyConfig.SPECIAL_MOVES[moveId]
	if not move then
		return false
	end

	controller.specialActive = true
	controller.specialMove = move
	controller.specialTarget = targetController
	controller.specialPhaseIdx = 1
	controller.specialPhase = move.phases[1]
	controller.specialPhaseEnd = os.clock() + move.phases[1].duration
	controller.specialEndTime = os.clock() + move.duration
	controller.guardReduction = 0
	controller.underground = false
	controller.phased = false
	controller.meteorLastPos = controller.part.Position

	SpecialVFX.spawnCallout(controller, move.name, move.color)
	SpecialMoveRunner.onPhaseStart(controller, move, move.phases[1])
	return true
end

function SpecialMoveRunner.endMove(controller)
	controller.specialActive = false
	controller.specialMove = nil
	controller.specialPhase = nil
	controller.guardReduction = 0
	controller.orbitCenter = nil
	controller.underground = false
	SpecialVFX.setUnderground(controller, false)
	SpecialVFX.setPhased(controller, false)
	SpecialVFX.cleanup(controller)
end

function SpecialMoveRunner.update(controller, dt, allControllers)
	local move = controller.specialMove
	if not move or not controller.specialActive then
		return
	end

	local now = os.clock()

	if controller.specialPhase and now >= controller.specialPhaseEnd then
		if not advancePhase(controller, move) then
			SpecialMoveRunner.endMove(controller)
			return
		end
	end

	local phase = controller.specialPhase
	if not phase then
		return
	end

	local modeHandlers = PHASE_UPDATE[move.mode]
	if modeHandlers then
		local updater = modeHandlers[phase.id]
		if updater then
			updater(controller, move, phase, dt, allControllers)
		end
	end

	if now >= controller.specialEndTime then
		SpecialMoveRunner.endMove(controller)
	end
end

return SpecialMoveRunner
