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
		launch = function(controller, move, phase)
			local target = controller.specialTarget
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
		burrow = function(controller, move, _phase)
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
		orbit = function(controller, move)
			local target = controller.specialTarget
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
		dive = function(controller, move, phase)
			local folder = SpecialVFX.ensureFolder(controller)
			local target = controller.specialTarget
			local targetPos = getTargetPos(controller, target)
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
	cyclone = {
		ignite = function(controller, move, phase)
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		end,
		spiral = function(controller)
			controller.cycloneTimer = 0
			controller.cycloneHits = 0
			controller.cycloneAngle = 0
		end,
		rush = function(controller, move, phase)
			local target = controller.specialTarget
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
		end,
		burst = function(controller, move)
			local folder = SpecialVFX.ensureFolder(controller)
			SpecialVFX.flameBurst(controller.part.Position, move.color, folder)
		end,
	},
	glacier = {
		chill = function(controller, move, phase)
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
			controller.velocity *= 0.3
		end,
		veil = function(controller, move, phase)
			controller.guardReduction = move.damageReduction or 0.6
			SpecialVFX.frostShield(controller, move.color, phase.duration)
		end,
		shatter = function(controller)
			controller.shatterTimer = 0
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
		shower = function(controller, move, phase, dt, allControllers, folder)
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 70)
			controller.meteorTimer = (controller.meteorTimer or 0) + dt
			if controller.meteorTimer >= (phase.hitInterval or 0.18) then
				controller.meteorTimer = 0
				local pos = controller.part.Position
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
		pulse = function(controller, move, phase, dt, allControllers, folder)
			controller.pulseTimer = (controller.pulseTimer or 0) + dt
			if controller.pulseTimer >= (phase.interval or 0.35) then
				controller.pulseTimer = 0
				SpecialVFX.pulseWave(controller.part.Position, phase.range or 8, move.color, folder)
				controller:areaHit(allControllers, phase.range or 8, phase.damage or 13, true)
			end
		end,
	},
	sonic = {
		charge = function(controller)
			controller.velocity *= 0.9
		end,
		sonic = function(controller, move, phase, dt, allControllers, folder)
			controller.sonicTimer = (controller.sonicTimer or 0) + dt
			if controller.sonicTimer >= (phase.interval or 0.28) then
				controller.sonicTimer = 0
				controller.sonicCount = (controller.sonicCount or 0) + 1
				local range = 4 + controller.sonicCount * 1.5
				SpecialVFX.sonicRing(controller.part.Position, range, move.color, folder)
				controller:areaHit(allControllers, range, phase.damage or 9, true)
			end
		end,
		orbit = function(controller, move, _phase, dt, allControllers)
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
	cyclone = {
		ignite = function(controller)
			controller.velocity = Vector3.zero
		end,
		spiral = function(controller, move, phase, dt, allControllers, folder)
			controller.cycloneTimer = (controller.cycloneTimer or 0) + dt
			controller.cycloneAngle = (controller.cycloneAngle or 0) + dt * 14
			local orbitR = 2.5
			local offset = Vector3.new(math.cos(controller.cycloneAngle) * orbitR, 0, math.sin(controller.cycloneAngle) * orbitR)
			controller.velocity = offset * 6

			if controller.cycloneTimer >= (phase.hitInterval or 0.2) then
				controller.cycloneTimer = 0
				controller.cycloneHits = (controller.cycloneHits or 0) + 1
				local range = (phase.hitRadius or 5) + controller.cycloneHits * 0.6
				SpecialVFX.flameRing(controller.part.Position, range, move.color, folder)
				controller:areaHit(allControllers, range, phase.damage or 10, true)
			end
		end,
		rush = function(controller, move, phase, _dt, allControllers)
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 80)
			controller:checkCollisions(allControllers, true)
		end,
		burst = function(controller, move, phase, _dt, allControllers)
			controller:areaHit(allControllers, phase.range or 7, phase.damage or 30, true)
		end,
	},
	glacier = {
		chill = function(controller)
			controller.velocity *= 0.85
		end,
		veil = function(controller)
			controller.velocity = Vector3.zero
		end,
		shatter = function(controller, move, phase, dt, allControllers, folder)
			controller.shatterTimer = (controller.shatterTimer or 0) + dt
			if controller.shatterTimer >= (phase.interval or 0.3) then
				controller.shatterTimer = 0
				SpecialVFX.iceShatter(controller.part.Position, phase.range or 9, move.color, folder)
				controller:areaHit(allControllers, phase.range or 9, phase.damage or 12, true)
			end
		end,
	},
}

function SpecialMoveRunner.onPhaseStart(controller, move, phase)
	local modeHandlers = PHASE_START[move.mode]
	if modeHandlers then
		local handler = modeHandlers[phase.id]
		if handler then
			handler(controller, move, phase)
		end
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

	local folder = SpecialVFX.ensureFolder(controller)
	local modeHandlers = PHASE_UPDATE[move.mode]
	if modeHandlers then
		local handler = modeHandlers[phase.id]
		if handler then
			handler(controller, move, phase, dt, allControllers, folder)
		end
	end

	if now >= controller.specialEndTime then
		SpecialMoveRunner.endMove(controller)
	end
end

return SpecialMoveRunner
