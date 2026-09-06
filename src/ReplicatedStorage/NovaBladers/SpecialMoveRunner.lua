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
			SpecialVFX.cycloneVortex(controller, color, phase.duration)
		elseif phase.id == "slash" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
		end
	elseif move.id == "GraniteBastionPulse" then
		if phase.id == "root" then
			controller.guardReduction = move.damageReduction or 0.65
			SpecialVFX.bastionWall(controller, color, phase.duration)
			controller.velocity = Vector3.zero
		elseif phase.id == "pulse" then
			controller.pulseTimer = 0
		elseif phase.id == "shatter" then
			controller.shatterHitDone = false
			SpecialVFX.graniteShatter(controller.part.Position, color, folder)
		end
	elseif move.id == "SolarFlareDrift" then
		if phase.id == "ignite" then
			SpecialVFX.solarIgnite(controller, color, phase.duration)
		elseif phase.id == "drift" then
			local targetPos = getTargetPos(controller, target)
			controller.orbitCenter = (controller.part.Position + targetPos) / 2
			controller.orbitAngle = math.atan2(
				controller.part.Position.Z - controller.orbitCenter.Z,
				controller.part.Position.X - controller.orbitCenter.X
			)
			controller.orbitRadius = move.orbitRadius or 7
			controller.orbitSpeed = move.orbitSpeed or 14
			controller.driftTimer = 0
		elseif phase.id == "flare" then
			controller.flareHitDone = false
			SpecialVFX.solarFlare(controller.part.Position, color, folder)
		end
	elseif move.id == "PhantomEdgeSurge" then
		if phase.id == "phase" then
			SpecialVFX.phantomPhase(controller, color, phase.duration)
		elseif phase.id == "surge" then
			controller.surgeTimer = 0
			controller.surgeCount = 0
			controller.surgeMax = phase.dashes or 3
		elseif phase.id == "return" then
			local dir = (getTargetPos(controller, target) - controller.part.Position)
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			controller.facing = dir
			controller.velocity = dir * (phase.rushSpeed or move.rushSpeed)
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
			controller.velocity = Vector3.zero
			controller.cycloneTimer = (controller.cycloneTimer or 0) + dt
			if controller.cycloneTimer >= (phase.interval or 0.14) then
				controller.cycloneTimer = 0
				SpecialVFX.bladeSlash(controller.part.Position, controller.facing, move.color, folder)
				controller:areaHit(allControllers, phase.range or 5.5, phase.damage or 10, true)
			end
		elseif phase.id == "slash" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 70)
			controller:checkCollisions(allControllers, true)
		end

	elseif move.id == "GraniteBastionPulse" then
		if phase.id == "root" or phase.id == "shatter" then
			controller.velocity = Vector3.zero
		elseif phase.id == "pulse" then
			controller.velocity = Vector3.zero
			controller.pulseTimer = (controller.pulseTimer or 0) + dt
			if controller.pulseTimer >= (phase.interval or 0.35) then
				controller.pulseTimer = 0
				SpecialVFX.granitePulse(controller.part.Position, phase.range or 9, move.color, folder)
				controller:areaHit(allControllers, phase.range or 9, phase.damage or 12, true)
			end
		end
		if phase.id == "shatter" and not controller.shatterHitDone then
			controller.shatterHitDone = true
			controller:areaHit(allControllers, phase.range or 10, phase.damage or 22, true)
		end

	elseif move.id == "SolarFlareDrift" then
		if phase.id == "ignite" then
			controller.velocity *= 0.85
		elseif phase.id == "drift" then
			controller.driftTimer = (controller.driftTimer or 0) + dt
			controller.orbitAngle = (controller.orbitAngle or 0) + (controller.orbitSpeed or 14) * dt
			local r = controller.orbitRadius or 7
			local center = controller.orbitCenter or controller.part.Position
			local y = controller.part.Position.Y
			local pos = center + Vector3.new(math.cos(controller.orbitAngle) * r, 0, math.sin(controller.orbitAngle) * r)
			controller.part.CFrame = CFrame.new(Vector3.new(pos.X, y, pos.Z), center)
			controller.velocity = Vector3.zero
			if math.floor(controller.driftTimer * 10) % 3 == 0 then
				SpecialVFX.flareTrail(controller.part.Position, move.color, folder)
			end
			controller:checkCollisions(allControllers, true)
		elseif phase.id == "flare" then
			controller.velocity = Vector3.zero
			if not controller.flareHitDone then
				controller.flareHitDone = true
				controller:areaHit(allControllers, phase.range or 7, phase.damage or 36, true)
			end
		end

	elseif move.id == "PhantomEdgeSurge" then
		if phase.id == "surge" then
			controller.surgeTimer = (controller.surgeTimer or 0) + dt
			if controller.surgeTimer >= (phase.interval or 0.22) then
				controller.surgeTimer = 0
				controller.surgeCount = (controller.surgeCount or 0) + 1
				if controller.surgeCount <= (phase.dashes or 3) then
					local targetPos = getTargetPos(controller, target)
					local dir = (targetPos - controller.part.Position)
					dir = Vector3.new(dir.X, 0, dir.Z).Unit
					if dir.Magnitude < 0.01 then
						dir = controller.facing
					end
					controller.facing = dir
					controller.velocity = dir * (move.rushSpeed or 80)
					SpecialVFX.phantomAfterimage(controller.part.Position, color, folder)
					controller:checkCollisions(allControllers, true)
					controller:areaHit(allControllers, 4, phase.damage or 14, true)
				end
			end
		elseif phase.id == "return" then
			controller.velocity = controller.facing * (phase.rushSpeed or move.rushSpeed or 85)
			controller:checkCollisions(allControllers, true)
		end
	end

	if now >= controller.specialEndTime then
		SpecialMoveRunner.endMove(controller)
	end
end

return SpecialMoveRunner
