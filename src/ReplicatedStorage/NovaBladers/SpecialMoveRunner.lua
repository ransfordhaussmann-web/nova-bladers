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

local PHASE_START = {
	meteor = {
		windup = function(controller, move, phase)
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		end,
		launch = function(controller, move, phase, target)
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
		end,
		shower = function(controller, _move, phase)
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
		orbit = function(controller, move, _phase, target)
			if target and target.part then
				controller.orbitCenter = target.part.Position
				controller.orbitAngle = math.atan2(
					controller.part.Position.Z - target.part.Position.Z,
					controller.part.Position.X - target.part.Position.X
				)
				controller.orbitRadius = move.orbitRadius or 6
				controller.orbitSpeed = move.orbitSpeed or 16
			end
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
			local folder = SpecialVFX.ensureFolder(controller)
			SpecialVFX.diveTrail(controller, targetPos, move.color, folder)
			local dir = (targetPos - controller.part.Position)
			dir = Vector3.new(dir.X, -0.4, dir.Z).Unit
			controller.facing = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
			controller.verticalVelocity = -(phase.diveSpeed or 40)
		end,
		burst = function(controller, move)
			local folder = SpecialVFX.ensureFolder(controller)
			SpecialVFX.venomBurst(controller.part.Position, move.color, folder)
		end,
	},
	flurry = {
		windup = function(controller, move, phase)
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		end,
		rush = function(controller, move, phase, target)
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
		end,
		flurry = function(controller, _move, phase)
			controller.flurryHitsLeft = phase.hits or 6
			controller.flurryTimer = 0
		end,
	},
	glacier = {
		freeze = function(controller, move, phase)
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		end,
		dome = function(controller, move, phase)
			controller.guardReduction = phase.damageReduction or move.damageReduction or 0.6
			SpecialVFX.iceDome(controller, move.color, phase.duration)
		end,
		shatter = function(controller)
			controller.frostTimer = 0
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
				local folder = SpecialVFX.ensureFolder(controller)
				SpecialVFX.sonicRing(controller.part.Position, range, move.color, folder)
				controller:areaHit(allControllers, range, phase.damage or 9, true)
			end
		end,
		orbit = function(controller, _move, _phase, _dt, allControllers)
			if not controller.orbitCenter then
				return
			end
			controller.orbitAngle += (controller.orbitSpeed or 16) * (_dt or 0)
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
		end,
	},
	eclipse = {
		dive = function(controller, move, phase, _dt, allControllers)
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 85)
			controller:checkCollisions(allControllers, true)
		end,
		burst = function(controller, move, phase, _dt, allControllers)
			controller:areaHit(allControllers, phase.range or 6, phase.damage or 38, true)
		end,
	},
	flurry = {
		windup = function(controller)
			controller.velocity = Vector3.zero
		end,
		rush = function(controller, move, phase)
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 85)
		end,
		flurry = function(controller, move, phase, dt, allControllers)
			controller.velocity = controller.facing * (move.rushSpeed or 70) * 0.35
			controller.flurryTimer = (controller.flurryTimer or 0) + dt
			if controller.flurryTimer >= (phase.hitInterval or 0.12) then
				controller.flurryTimer = 0
				local folder = SpecialVFX.ensureFolder(controller)
				SpecialVFX.flurrySlash(controller.part.Position, move.color, folder)
				controller:areaHit(allControllers, phase.hitRadius or 4.5, phase.damage or 9, true)
			end
		end,
	},
	glacier = {
		freeze = function(controller)
			controller.velocity *= 0.85
		end,
		dome = function(controller)
			controller.velocity = Vector3.zero
		end,
		shatter = function(controller, move, phase, dt, allControllers)
			controller.frostTimer = (controller.frostTimer or 0) + dt
			if controller.frostTimer >= (phase.interval or 0.25) then
				controller.frostTimer = 0
				local folder = SpecialVFX.ensureFolder(controller)
				SpecialVFX.frostPulse(controller.part.Position, phase.range or 7, move.color, folder)
				controller:areaHit(allControllers, phase.range or 7, phase.damage or 12, true)
			end
		end,
	},
}

function SpecialMoveRunner.onPhaseStart(controller, move, phase)
	local modeHandlers = PHASE_START[move.mode]
	if not modeHandlers then
		return
	end
	local handler = modeHandlers[phase.id]
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
		local handler = modeHandlers[phase.id]
		if handler then
			handler(controller, move, phase, dt, allControllers)
		end
	end

	if now >= controller.specialEndTime then
		SpecialMoveRunner.endMove(controller)
	end
end

return SpecialMoveRunner
