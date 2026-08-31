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

local function startOrbit(controller, move, target)
	if not (target and target.part) then
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

local PHASE_START = {
	meteor = function(controller, move, phase, target)
		if phase.id == "windup" then
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		elseif phase.id == "launch" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
		elseif phase.id == "shower" then
			controller.meteorHitsLeft = phase.hits or 4
			controller.meteorTimer = 0
		end
	end,
	feather = function(controller, move, phase, target)
		if phase.id == "windup" then
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		elseif phase.id == "launch" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
		elseif phase.id == "shower" then
			controller.meteorHitsLeft = phase.hits or 5
			controller.meteorTimer = 0
		end
	end,
	fortress = function(controller, move, phase)
		if phase.id == "burrow" then
			SpecialVFX.setUnderground(controller, true)
			SpecialVFX.burrowCloud(controller, move.color)
			controller.velocity = Vector3.zero
		elseif phase.id == "wall" then
			SpecialVFX.setUnderground(controller, false)
			controller.guardReduction = move.damageReduction or 0.55
			SpecialVFX.wallRing(controller, move.color, phase.duration)
		elseif phase.id == "pulse" then
			controller.pulseTimer = 0
		end
	end,
	rampart = function(controller, move, phase)
		if phase.id == "fortify" then
			controller.guardReduction = move.damageReduction or 0.6
			SpecialVFX.wallRing(controller, move.color, phase.duration)
		elseif phase.id == "pulse" then
			controller.pulseTimer = 0
		end
	end,
	sonic = function(controller, move, phase, target)
		if phase.id == "charge" then
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		elseif phase.id == "sonic" then
			controller.sonicTimer = 0
			controller.sonicCount = 0
		elseif phase.id == "orbit" then
			startOrbit(controller, move, target)
		end
	end,
	solar = function(controller, move, phase, target)
		if phase.id == "charge" then
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		elseif phase.id == "flare" then
			controller.sonicTimer = 0
			controller.sonicCount = 0
		elseif phase.id == "orbit" then
			startOrbit(controller, move, target)
		end
	end,
	eclipse = function(controller, move, phase, target, folder)
		if phase.id == "aura" then
			SpecialVFX.darkAura(controller, move.color, phase.duration)
			controller.verticalVelocity = 18
			controller.airborne = true
		elseif phase.id == "dive" then
			local targetPos = getTargetPos(controller, target)
			SpecialVFX.diveTrail(controller, targetPos, move.color, folder)
			local dir = (targetPos - controller.part.Position)
			dir = Vector3.new(dir.X, -0.4, dir.Z).Unit
			controller.facing = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
			controller.verticalVelocity = -(phase.diveSpeed or 40)
		elseif phase.id == "burst" then
			SpecialVFX.venomBurst(controller.part.Position, move.color, folder)
		end
	end,
	anchor = function(controller, move, phase)
		if phase.id == "surge" then
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		elseif phase.id == "pull" then
			controller.pullTimer = 0
		elseif phase.id == "slam" then
			controller.velocity = Vector3.zero
		end
	end,
	rend = function(controller, move, phase, target)
		if phase.id == "stance" then
			SpecialVFX.chargeAura(controller, move.color, phase.duration * 0.8)
		elseif phase.id == "lunge" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
		elseif phase.id == "slash" then
			controller.meteorHitsLeft = phase.hits or 3
			controller.meteorTimer = 0
		end
	end,
	phase = function(controller, move, phase, target, folder)
		if phase.id == "vanish" then
			SpecialVFX.setPhased(controller, true)
		elseif phase.id == "dash" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
			SpecialVFX.phaseTrail(controller, move.color, folder)
		elseif phase.id == "slash" then
			SpecialVFX.setPhased(controller, false)
			SpecialVFX.phaseSlash(controller.part.Position, controller.facing, move.color, folder)
		end
	end,
}

local PHASE_UPDATE = {
	meteor = function(controller, move, phase, dt, allControllers, folder)
		if phase.id == "windup" then
			controller.velocity = Vector3.zero
		elseif phase.id == "launch" or phase.id == "shower" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 70)
		end
		if phase.id == "shower" then
			controller.meteorTimer = (controller.meteorTimer or 0) + dt
			if controller.meteorTimer >= (phase.hitInterval or 0.18) then
				controller.meteorTimer = 0
				local pos = controller.part.Position
				SpecialVFX.meteorTrail(controller.meteorLastPos, pos, move.color, folder)
				SpecialVFX.meteorImpact(pos, move.color, folder)
				controller.meteorLastPos = pos
				controller:areaHit(allControllers, phase.hitRadius or 5, phase.damage or 11, true)
			end
		end
	end,
	feather = function(controller, move, phase, dt, allControllers, folder)
		if phase.id == "windup" then
			controller.velocity = Vector3.zero
		elseif phase.id == "launch" or phase.id == "shower" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 70)
		end
		if phase.id == "shower" then
			controller.meteorTimer = (controller.meteorTimer or 0) + dt
			if controller.meteorTimer >= (phase.hitInterval or 0.16) then
				controller.meteorTimer = 0
				local pos = controller.part.Position
				SpecialVFX.featherBurst(pos, move.color, folder)
				controller.meteorLastPos = pos
				controller:areaHit(allControllers, phase.hitRadius or 5, phase.damage or 10, true)
			end
		end
	end,
	fortress = function(controller, move, phase, dt, allControllers, folder)
		if phase.id == "burrow" then
			controller.velocity = Vector3.zero
			local pos = controller.part.Position
			controller.part.CFrame = CFrame.new(Vector3.new(pos.X, controller.floorY - 1.2, pos.Z))
				* (controller.part.CFrame - controller.part.CFrame.Position)
		elseif phase.id == "wall" then
			controller.velocity = Vector3.zero
		elseif phase.id == "pulse" then
			controller.pulseTimer = (controller.pulseTimer or 0) + dt
			if controller.pulseTimer >= (phase.interval or 0.35) then
				controller.pulseTimer = 0
				SpecialVFX.pulseWave(controller.part.Position, phase.range or 8, move.color, folder)
				controller:areaHit(allControllers, phase.range or 8, phase.damage or 13, true)
			end
		end
	end,
	rampart = function(controller, move, phase, dt, allControllers, folder)
		if phase.id == "fortify" then
			controller.velocity *= 0.85
		elseif phase.id == "pulse" then
			controller.pulseTimer = (controller.pulseTimer or 0) + dt
			if controller.pulseTimer >= (phase.interval or 0.35) then
				controller.pulseTimer = 0
				SpecialVFX.stonePulse(controller.part.Position, phase.range or 7.5, move.color, folder)
				controller:areaHit(allControllers, phase.range or 7.5, phase.damage or 12, true)
			end
		end
	end,
	sonic = function(controller, move, phase, dt, allControllers, folder)
		if phase.id == "charge" then
			controller.velocity *= 0.9
		elseif phase.id == "sonic" then
			controller.sonicTimer = (controller.sonicTimer or 0) + dt
			if controller.sonicTimer >= (phase.interval or 0.28) then
				controller.sonicTimer = 0
				controller.sonicCount = (controller.sonicCount or 0) + 1
				local range = 4 + controller.sonicCount * 1.5
				SpecialVFX.sonicRing(controller.part.Position, range, move.color, folder)
				controller:areaHit(allControllers, range, phase.damage or 9, true)
			end
		elseif phase.id == "orbit" and controller.orbitCenter then
			SpecialMoveRunner.updateOrbit(controller, dt, allControllers)
		end
	end,
	solar = function(controller, move, phase, dt, allControllers, folder)
		if phase.id == "charge" then
			controller.velocity *= 0.9
		elseif phase.id == "flare" then
			controller.sonicTimer = (controller.sonicTimer or 0) + dt
			if controller.sonicTimer >= (phase.interval or 0.25) then
				controller.sonicTimer = 0
				controller.sonicCount = (controller.sonicCount or 0) + 1
				local range = 3.5 + controller.sonicCount * 1.2
				SpecialVFX.solarFlare(controller.part.Position, range, move.color, folder)
				controller:areaHit(allControllers, range, phase.damage or 8, true)
			end
		elseif phase.id == "orbit" and controller.orbitCenter then
			SpecialMoveRunner.updateOrbit(controller, dt, allControllers)
		end
	end,
	eclipse = function(controller, move, phase, dt, allControllers)
		if phase.id == "dive" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 85)
			controller:checkCollisions(allControllers, true)
		elseif phase.id == "burst" then
			controller:areaHit(allControllers, phase.range or 6, phase.damage or 38, true)
		end
	end,
	anchor = function(controller, move, phase, dt, allControllers, folder)
		if phase.id == "surge" then
			controller.velocity *= 0.8
		elseif phase.id == "pull" then
			controller.pullTimer = (controller.pullTimer or 0) + dt
			local origin = controller.part.Position
			local range = phase.range or 14
			local strength = phase.pullStrength or 28
			for _, other in allControllers do
				if other ~= controller and other.alive and other.part then
					local delta = origin - other.part.Position
					local flat = Vector3.new(delta.X, 0, delta.Z)
					local dist = flat.Magnitude
					if dist > 0.5 and dist <= range then
						local pull = flat.Unit * strength * dt
						other.velocity = other.velocity + pull
					end
				end
			end
			SpecialVFX.tideRipple(origin, range * 0.5, move.color, folder)
		elseif phase.id == "slam" then
			controller.velocity = Vector3.zero
			SpecialVFX.anchorSlam(controller.part.Position, phase.range or 7, move.color, folder)
			controller:areaHit(allControllers, phase.range or 7, phase.damage or 40, true)
		end
	end,
	rend = function(controller, move, phase, dt, allControllers, folder)
		if phase.id == "stance" then
			controller.velocity = Vector3.zero
		elseif phase.id == "lunge" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 85)
			controller:checkCollisions(allControllers, true)
		elseif phase.id == "slash" then
			controller.meteorTimer = (controller.meteorTimer or 0) + dt
			if controller.meteorTimer >= (phase.hitInterval or 0.15) then
				controller.meteorTimer = 0
				SpecialVFX.rendSlash(controller.part.Position, controller.facing, move.color, folder)
				controller:areaHit(allControllers, phase.hitRadius or 4.5, phase.damage or 14, true)
			end
		end
	end,
	phase = function(controller, move, phase, dt, allControllers)
		if phase.id == "dash" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 90)
			controller:checkCollisions(allControllers, true)
		elseif phase.id == "slash" then
			controller:areaHit(allControllers, phase.range or 7, phase.damage or 42, true)
		end
	end,
}

function SpecialMoveRunner.updateOrbit(controller, dt, allControllers)
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

function SpecialMoveRunner.onPhaseStart(controller, move, phase)
	local folder = SpecialVFX.ensureFolder(controller)
	local target = controller.specialTarget
	local handler = PHASE_START[move.mode]
	if handler then
		handler(controller, move, phase, target, folder)
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
	controller.phased = false
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

	local folder = SpecialVFX.ensureFolder(controller)
	local handler = PHASE_UPDATE[move.mode]
	if handler then
		handler(controller, move, phase, dt, allControllers, folder)
	end

	if now >= controller.specialEndTime then
		SpecialMoveRunner.endMove(controller)
	end
end

return SpecialMoveRunner
