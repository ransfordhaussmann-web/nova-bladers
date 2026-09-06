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

function SpecialMoveRunner.onPhaseStart(controller, move, phase)
	local folder = SpecialVFX.ensureFolder(controller)
	local color = move.color
	local target = controller.specialTarget

	if move.id == "NovaMeteorShower" then
		if phase.id == "windup" then
			SpecialVFX.chargeAura(controller, color, phase.duration)
		elseif phase.id == "launch" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
		elseif phase.id == "shower" then
			controller.meteorHitsLeft = phase.hits or 4
			controller.meteorTimer = 0
		end
	elseif move.id == "IronVaultLock" then
		if phase.id == "burrow" then
			SpecialVFX.setUnderground(controller, true)
			SpecialVFX.burrowCloud(controller, color)
			controller.velocity = Vector3.zero
		elseif phase.id == "wall" then
			SpecialVFX.setUnderground(controller, false)
			controller.guardReduction = move.damageReduction or 0.55
			SpecialVFX.wallRing(controller, color, phase.duration)
		elseif phase.id == "pulse" then
			controller.pulseTimer = 0
		end
	elseif move.id == "VoltSonicTempest" then
		if phase.id == "charge" then
			SpecialVFX.chargeAura(controller, color, phase.duration)
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
	elseif move.id == "ShadowEclipseFang" then
		if phase.id == "aura" then
			SpecialVFX.darkAura(controller, color, phase.duration)
			controller.verticalVelocity = 18
			controller.airborne = true
		elseif phase.id == "dive" then
			local targetPos = getTargetPos(controller, target)
			SpecialVFX.diveTrail(controller, targetPos, color, folder)
			local dir = (targetPos - controller.part.Position)
			dir = Vector3.new(dir.X, -0.4, dir.Z).Unit
			controller.facing = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
			controller.verticalVelocity = -(phase.diveSpeed or 40)
		elseif phase.id == "burst" then
			SpecialVFX.venomBurst(controller.part.Position, color, folder)
		end
	elseif move.id == "CrimsonBladeCyclone" then
		if phase.id == "windup" then
			SpecialVFX.chargeAura(controller, color, phase.duration)
		elseif phase.id == "cyclone" then
			controller.cycloneTimer = 0
			controller.cycloneAngle = 0
		elseif phase.id == "slash" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
		end
	elseif move.id == "GraniteBastionPulse" then
		if phase.id == "fortify" then
			controller.guardReduction = move.damageReduction or 0.65
			SpecialVFX.bastionShield(controller, color, phase.duration)
			controller.velocity = Vector3.zero
		elseif phase.id == "bastion" then
			controller.bastionTimer = 0
		elseif phase.id == "pulse" then
			SpecialVFX.pulseWave(controller.part.Position, phase.range or 9, color, folder)
			controller.pulsePending = true
		end
	elseif move.id == "SolarFlareDrift" then
		if phase.id == "charge" then
			SpecialVFX.chargeAura(controller, color, phase.duration)
		elseif phase.id == "rings" then
			controller.solarTimer = 0
			controller.solarCount = 0
		elseif phase.id == "drift" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.driftLastPos = controller.part.Position
		end
	elseif move.id == "PhantomEdgeSurge" then
		if phase.id == "vanish" then
			SpecialVFX.setPhantom(controller, true)
		elseif phase.id == "surge" then
			SpecialVFX.setPhantom(controller, false)
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
			controller.surgeDashesLeft = phase.dashes or 3
			controller.surgeLastPos = controller.part.Position
		elseif phase.id == "slash" then
			SpecialVFX.edgeSlash(controller.part.Position, color, folder)
			controller.slashPending = true
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
	controller.phantom = false
	SpecialVFX.setUnderground(controller, false)
	SpecialVFX.setPhantom(controller, false)
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
	local target = controller.specialTarget

	if move.id == "NovaMeteorShower" then
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

	elseif move.id == "IronVaultLock" then
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

	elseif move.id == "VoltSonicTempest" then
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

	elseif move.id == "ShadowEclipseFang" then
		if phase.id == "dive" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 85)
			controller:checkCollisions(allControllers, true)
		elseif phase.id == "burst" then
			controller:areaHit(allControllers, phase.range or 6, phase.damage or 38, true)
		end

	elseif move.id == "CrimsonBladeCyclone" then
		if phase.id == "windup" then
			controller.velocity = Vector3.zero
		elseif phase.id == "cyclone" then
			controller.cycloneTimer = (controller.cycloneTimer or 0) + dt
			controller.cycloneAngle = (controller.cycloneAngle or 0) + dt * 14
			local r = 2.2
			local center = controller.part.Position
			local orbitPos = center + Vector3.new(math.cos(controller.cycloneAngle) * r, 0, math.sin(controller.cycloneAngle) * r)
			controller.part.CFrame = CFrame.new(orbitPos, center)
			controller.velocity = Vector3.zero
			controller.cycloneVfxTimer = (controller.cycloneVfxTimer or 0) + dt
			if controller.cycloneVfxTimer >= 0.08 then
				controller.cycloneVfxTimer = 0
				SpecialVFX.cycloneBlade(controller, move.color, folder)
			end
			if controller.cycloneTimer >= (phase.interval or 0.15) then
				controller.cycloneTimer = 0
				controller:areaHit(allControllers, phase.hitRadius or 5, phase.damage or 10, true)
			end
		elseif phase.id == "slash" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 90)
			controller:checkCollisions(allControllers, true)
			controller.slashVfxTimer = (controller.slashVfxTimer or 0) + dt
			if controller.slashVfxTimer >= 0.12 then
				controller.slashVfxTimer = 0
				local pos = controller.part.Position
				SpecialVFX.bladeSlash(pos - controller.facing * 3, pos, move.color, folder)
			end
		end

	elseif move.id == "GraniteBastionPulse" then
		if phase.id == "fortify" or phase.id == "bastion" then
			controller.velocity = Vector3.zero
		end
		if phase.id == "bastion" then
			controller.bastionTimer = (controller.bastionTimer or 0) + dt
			if controller.bastionTimer >= (phase.interval or 0.28) then
				controller.bastionTimer = 0
				SpecialVFX.pulseWave(controller.part.Position, phase.range or 6, move.color, folder)
				controller:areaHit(allControllers, phase.range or 6, phase.damage or 9, true)
			end
		elseif phase.id == "pulse" then
			controller.velocity = Vector3.zero
			if controller.pulsePending then
				controller.pulsePending = false
				controller:areaHit(allControllers, phase.range or 9, phase.damage or 34, true)
			end
		end

	elseif move.id == "SolarFlareDrift" then
		if phase.id == "charge" then
			controller.velocity *= 0.9
		elseif phase.id == "rings" then
			controller.solarTimer = (controller.solarTimer or 0) + dt
			if controller.solarTimer >= (phase.interval or 0.22) then
				controller.solarTimer = 0
				controller.solarCount = (controller.solarCount or 0) + 1
				local range = 3.5 + controller.solarCount * 1.4
				SpecialVFX.solarRing(controller.part.Position, range, move.color, folder)
				controller:areaHit(allControllers, range, phase.damage or 8, true)
			end
		elseif phase.id == "drift" then
			controller.velocity = controller.facing * (phase.rushSpeed or 65)
			controller.driftVfxTimer = (controller.driftVfxTimer or 0) + dt
			if controller.driftVfxTimer >= 0.1 then
				controller.driftVfxTimer = 0
				local pos = controller.part.Position
				SpecialVFX.solarTrail(controller.driftLastPos or pos, pos, move.color, folder)
				controller.driftLastPos = pos
				controller:areaHit(allControllers, phase.hitRadius or 5, phase.damage or 12, true)
			end
		end

	elseif move.id == "PhantomEdgeSurge" then
		if phase.id == "vanish" then
			controller.velocity = Vector3.zero
		elseif phase.id == "surge" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 105)
			controller:checkCollisions(allControllers, true)
			local pos = controller.part.Position
			if (pos - (controller.surgeLastPos or pos)).Magnitude > 4 then
				SpecialVFX.phantomAfterimage(controller.surgeLastPos, move.color, folder)
				controller.surgeLastPos = pos
				controller.surgeDashesLeft = (controller.surgeDashesLeft or 1) - 1
				if controller.surgeDashesLeft <= 0 then
					controller.surgeDashesLeft = phase.dashes or 3
					local dir = (getTargetPos(controller, target) - pos)
					dir = Vector3.new(dir.X, 0, dir.Z).Unit
					controller.facing = dir
				end
			end
		elseif phase.id == "slash" then
			controller.velocity = Vector3.zero
			if controller.slashPending then
				controller.slashPending = false
				controller:areaHit(allControllers, phase.range or 7, phase.damage or 36, true)
			end
		end
	end

	if now >= controller.specialEndTime then
		SpecialMoveRunner.endMove(controller)
	end
end

return SpecialMoveRunner
