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
	sonic = function(controller, move, phase, target)
		if phase.id == "charge" then
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		elseif phase.id == "sonic" then
			controller.sonicTimer = 0
			controller.sonicCount = 0
		elseif phase.id == "orbit" and target and target.part then
			controller.orbitCenter = target.part.Position
			controller.orbitAngle = math.atan2(
				controller.part.Position.Z - target.part.Position.Z,
				controller.part.Position.X - target.part.Position.X
			)
			controller.orbitRadius = move.orbitRadius or 6
			controller.orbitSpeed = move.orbitSpeed or 16
		end
	end,
	eclipse = function(controller, move, phase, target)
		local folder = SpecialVFX.ensureFolder(controller)
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
	flurry = function(controller, move, phase, target)
		if phase.id == "windup" then
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
		elseif phase.id == "dash" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
		elseif phase.id == "flurry" then
			controller.flurryTimer = 0
			controller.flurryLastPos = controller.part.Position
		end
	end,
	glacier = function(controller, move, phase)
		if phase.id == "freeze" then
			SpecialVFX.chargeAura(controller, move.color, phase.duration)
			controller.velocity *= 0.5
		elseif phase.id == "dome" then
			controller.guardReduction = move.damageReduction or 0.6
			SpecialVFX.iceDome(controller, move.color, phase.duration)
			controller.velocity = Vector3.zero
		elseif phase.id == "shatter" then
			controller.shatterDone = false
		end
	end,
}

local PHASE_UPDATE = {
	meteor = function(controller, move, phase, dt, allControllers)
		local folder = SpecialVFX.ensureFolder(controller)
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
	fortress = function(controller, move, phase, dt, allControllers)
		local folder = SpecialVFX.ensureFolder(controller)
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
	sonic = function(controller, move, phase, dt, allControllers)
		local folder = SpecialVFX.ensureFolder(controller)
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
	end,
	eclipse = function(controller, move, phase, dt, allControllers)
		if phase.id == "dive" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 85)
			controller:checkCollisions(allControllers, true)
		elseif phase.id == "burst" then
			controller:areaHit(allControllers, phase.range or 6, phase.damage or 38, true)
		end
	end,
	flurry = function(controller, move, phase, dt, allControllers)
		local folder = SpecialVFX.ensureFolder(controller)
		if phase.id == "windup" then
			controller.velocity = Vector3.zero
		elseif phase.id == "dash" or phase.id == "flurry" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 80)
		end
		if phase.id == "flurry" then
			controller.flurryTimer = (controller.flurryTimer or 0) + dt
			if controller.flurryTimer >= (phase.hitInterval or 0.14) then
				controller.flurryTimer = 0
				local pos = controller.part.Position
				SpecialVFX.fangSlash(controller.flurryLastPos, pos, move.color, folder)
				controller.flurryLastPos = pos
				controller:areaHit(allControllers, phase.hitRadius or 4.5, phase.damage or 10, true)
			end
		end
	end,
	glacier = function(controller, move, phase, dt, allControllers)
		local folder = SpecialVFX.ensureFolder(controller)
		if phase.id == "freeze" then
			controller.velocity *= 0.85
		elseif phase.id == "dome" then
			controller.velocity = Vector3.zero
		elseif phase.id == "shatter" and not controller.shatterDone then
			controller.shatterDone = true
			SpecialVFX.frostShatter(controller.part.Position, phase.range or 9, move.color, folder)
			controller:areaHit(allControllers, phase.range or 9, phase.damage or 16, true)
		end
	end,
}

function SpecialMoveRunner.onPhaseStart(controller, move, phase)
	local handler = PHASE_START[move.mode]
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

	local handler = PHASE_UPDATE[move.mode]
	if handler then
		handler(controller, move, phase, dt, allControllers)
	end

	if now >= controller.specialEndTime then
		SpecialMoveRunner.endMove(controller)
	end
end

return SpecialMoveRunner
