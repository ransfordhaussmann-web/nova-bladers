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
		if phase.id == "spin" then
			SpecialVFX.chargeAura(controller, color, phase.duration)
		elseif phase.id == "cyclone" then
			SpecialVFX.bladeCyclone(controller, color, phase.duration)
			controller.cycloneTimer = 0
		elseif phase.id == "finisher" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
		end
	elseif move.id == "GraniteBastionPulse" then
		if phase.id == "anchor" then
			controller.guardReduction = move.damageReduction or 0.6
			SpecialVFX.stoneAnchor(controller, color, phase.duration)
			controller.velocity = Vector3.zero
		elseif phase.id == "quake" then
			controller.quakeTimer = 0
		elseif phase.id == "collapse" then
			SpecialVFX.quakeCrack(controller.part.Position, phase.range or 9, color, folder)
		end
	elseif move.id == "SolarFlareDrift" then
		if phase.id == "flare" then
			SpecialVFX.chargeAura(controller, color, phase.duration)
		elseif phase.id == "drift" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			if dir.Magnitude < 0.01 then
				dir = controller.facing
			end
			controller.facing = dir
			controller.driftSpeed = phase.driftSpeed or move.rushSpeed or 70
			controller.driftTimer = 0
			controller.driftLastPos = controller.part.Position
		elseif phase.id == "nova" then
			SpecialVFX.solarNova(controller.part.Position, color, folder)
		end
	elseif move.id == "PhantomEdgeSurge" then
		if phase.id == "fade" then
			SpecialVFX.setPhantomFade(controller, true)
		elseif phase.id == "surge" then
			controller.dashCount = 0
			controller.dashTimer = 0
			controller.dashInterval = phase.dashInterval or 0.14
			controller.dashSpeed = phase.dashSpeed or move.rushSpeed
			controller.dashesLeft = phase.dashes or 3
		elseif phase.id == "echo" then
			SpecialVFX.setPhantomFade(controller, false)
			SpecialVFX.phantomEcho(controller.part.Position, color, folder)
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
	controller.collapseHitDone = false
	controller.novaHitDone = false
	controller.echoHitDone = false
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
	controller.collapseHitDone = false
	controller.novaHitDone = false
	controller.echoHitDone = false
	SpecialVFX.setUnderground(controller, false)
	SpecialVFX.setPhantomFade(controller, false)
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
		if phase.id == "spin" then
			controller.velocity = Vector3.zero
		elseif phase.id == "cyclone" then
			controller.velocity = Vector3.zero
			controller.cycloneTimer = (controller.cycloneTimer or 0) + dt
			if controller.cycloneTimer >= (phase.interval or 0.22) then
				controller.cycloneTimer = 0
				SpecialVFX.bladeCyclone(controller, move.color, 0.18)
				controller:areaHit(allControllers, phase.hitRadius or 5, phase.damage or 10, true)
			end
		elseif phase.id == "finisher" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 85)
			controller:checkCollisions(allControllers, true)
		end

	elseif move.id == "GraniteBastionPulse" then
		if phase.id == "anchor" or phase.id == "collapse" then
			controller.velocity = Vector3.zero
		elseif phase.id == "quake" then
			controller.quakeTimer = (controller.quakeTimer or 0) + dt
			if controller.quakeTimer >= (phase.interval or 0.3) then
				controller.quakeTimer = 0
				SpecialVFX.quakeCrack(controller.part.Position, phase.range or 7, move.color, folder)
				controller:areaHit(allControllers, phase.range or 7, phase.damage or 12, true)
			end
		end
		if phase.id == "collapse" and not controller.collapseHitDone then
			controller.collapseHitDone = true
			controller:areaHit(allControllers, phase.range or 9, phase.damage or 24, true)
		end

	elseif move.id == "SolarFlareDrift" then
		if phase.id == "flare" then
			controller.velocity *= 0.92
		elseif phase.id == "drift" then
			local speed = controller.driftSpeed or phase.driftSpeed or 70
			controller.velocity = controller.facing * speed
			controller.driftTimer = (controller.driftTimer or 0) + dt
			if controller.driftTimer >= (phase.tickInterval or 0.15) then
				controller.driftTimer = 0
				local pos = controller.part.Position
				SpecialVFX.solarTrail(controller.driftLastPos or pos, pos, move.color, folder)
				controller.driftLastPos = pos
				controller:areaHit(allControllers, 4.5, phase.tickDamage or 7, true)
			end
			controller:checkCollisions(allControllers, true)
		elseif phase.id == "nova" then
			controller.velocity = Vector3.zero
			if not controller.novaHitDone then
				controller.novaHitDone = true
				controller:areaHit(allControllers, phase.range or 7.5, phase.damage or 32, true)
			end
		end

	elseif move.id == "PhantomEdgeSurge" then
		if phase.id == "surge" then
			controller.dashTimer = (controller.dashTimer or 0) + dt
			if controller.dashTimer >= (controller.dashInterval or 0.14) then
				controller.dashTimer = 0
				if (controller.dashesLeft or 0) > 0 then
					controller.dashesLeft -= 1
					local targetPos = getTargetPos(controller, target)
					local dir = (targetPos - controller.part.Position)
					dir = Vector3.new(dir.X, 0, dir.Z).Unit
					if dir.Magnitude < 0.01 then
						dir = controller.facing
					end
					controller.facing = dir
					controller.velocity = dir * (controller.dashSpeed or move.rushSpeed or 95)
					SpecialVFX.phantomDashMark(controller.part.Position, move.color, folder)
					controller:checkCollisions(allControllers, true)
				end
			end
		elseif phase.id == "echo" then
			controller.velocity = Vector3.zero
			if not controller.echoHitDone then
				controller.echoHitDone = true
				controller:areaHit(allControllers, phase.range or 6, phase.damage or 28, true)
			end
		end
	end

	if now >= controller.specialEndTime then
		SpecialMoveRunner.endMove(controller)
	end
end

return SpecialMoveRunner
