local BeyConfig = require(script.Parent.BeyConfig)

local SpecialMoveRunner = {}

function SpecialMoveRunner.run(controller, moveId, targetController)
	local move = BeyConfig.SPECIAL_MOVES[moveId]
	if not move then
		return false
	end

	controller.specialActive = true
	controller.specialEndTime = os.clock() + move.duration
	controller.specialMove = move
	controller.specialTarget = targetController

	if move.mode == "guard" then
		controller.guardReduction = move.damageReduction or 0.5
	elseif move.mode == "rush" or move.mode == "lunge" then
		local dir = controller.facing
		if targetController and targetController.part then
			dir = (targetController.part.Position - controller.part.Position).Unit
		end
		controller.velocity = dir * move.rushSpeed
		controller.facing = dir
	elseif move.mode == "orbit" and targetController and targetController.part then
		controller.orbitCenter = targetController.part.Position
		controller.orbitAngle = math.atan2(
			controller.part.Position.Z - targetController.part.Position.Z,
			controller.part.Position.X - targetController.part.Position.X
		)
		controller.orbitRadius = move.orbitRadius or 5
		controller.orbitSpeed = move.orbitSpeed or 14
	end

	controller:spawnVfx(move)
	return true
end

function SpecialMoveRunner.update(controller, dt)
	local move = controller.specialMove
	if not move or not controller.specialActive then
		return
	end

	if os.clock() >= controller.specialEndTime then
		controller.specialActive = false
		controller.specialMove = nil
		controller.guardReduction = 0
		controller.orbitCenter = nil
		return
	end

	if move.mode == "orbit" and controller.orbitCenter then
		controller.orbitAngle += (controller.orbitSpeed or 14) * dt
		local r = controller.orbitRadius or 5
		local center = controller.orbitCenter
		local pos = center + Vector3.new(math.cos(controller.orbitAngle) * r, 1.5, math.sin(controller.orbitAngle) * r)
		controller.part.CFrame = CFrame.new(pos, center)
		controller.velocity = Vector3.zero
	elseif move.mode == "rush" or move.mode == "lunge" then
		controller.velocity = controller.facing * move.rushSpeed
	end

	if move.mode == "guard" and move.pulseInterval then
		controller.pulseTimer = (controller.pulseTimer or 0) + dt
		if controller.pulseTimer >= move.pulseInterval then
			controller.pulseTimer = 0
			controller:pulseHit(move.pulseRange or 7, move.damage)
		end
	end
end

return SpecialMoveRunner
