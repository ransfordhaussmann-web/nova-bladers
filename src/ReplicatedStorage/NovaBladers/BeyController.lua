local BeyConfig = require(script.Parent.BeyConfig)
local BeyModelBuilder = require(script.Parent.BeyModelBuilder)
local SpecialMoveRunner = require(script.Parent.SpecialMoveRunner)

local BeyController = {}
BeyController.__index = BeyController

local HIT_RADIUS = 3.2

function BeyController.new(props)
	local self = setmetatable({}, BeyController)

	self.player = props.player
	self.beyData = props.beyData
	self.arenaOrigin = props.arenaOrigin
	self.arenaRadius = props.arenaRadius
	self.outerRadius = props.outerRadius or BeyConfig.OUTER_PLATFORM_RADIUS
	self.floorY = props.floorY or (props.arenaOrigin.Y + BeyConfig.BOWL_FLOOR_OFFSET)
	self.platformY = props.platformY or (props.arenaOrigin.Y + BeyConfig.OUTER_PLATFORM_Y)
	self.isDummy = props.isDummy or false
	self.onHit = props.onHit

	self.hp = BeyConfig.MAX_HP
	self.spin = BeyConfig.MAX_SPIN
	self.special = 0
	self.alive = true
	self.bursted = false
	self.airborne = false
	self.verticalVelocity = 0
	self.landingSlam = false

	self.velocity = Vector3.zero
	self.facing = Vector3.new(0, 0, -1)
	self.inputDir = Vector3.zero
	self.charging = false
	self.dodgeUntil = 0
	self.spinRecoverUntil = 0
	self.jumpUntil = 0
	self.hitCooldowns = {}
	self.specialCooldownUntil = 0
	self.specialActive = false
	self.guardReduction = 0
	self._spinAngle = 0

	local arena = workspace:FindFirstChild("Arena") or workspace
	local built = BeyModelBuilder.build(props.beyData, props.spawnCFrame)
	self.model = built.model
	self.part = built.part
	self.spinRing = built.spinRing
	self.spinVisuals = built.spinVisuals or { built.spinRing }
	self.model.Name = "Bey_" .. (self.player and self.player.Name or "Dummy")
	self.model.Parent = arena

	self.bodyVelocity = Instance.new("BodyVelocity")
	self.bodyVelocity.Name = "BeyVelocity"
	self.bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	self.bodyVelocity.Velocity = Vector3.zero
	self.bodyVelocity.Parent = self.part

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(140, 44)
	label.StudsOffset = Vector3.new(0, 3.5, 0)
	label.AlwaysOnTop = true
	label.Parent = self.part

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = props.beyData.name
	nameLabel.Parent = label

	return self
end

function BeyController:getAttackMult()
	return (self.beyData.stats.Attack or 7) / BeyConfig.ATTACK_DAMAGE_SCALE
end

function BeyController:getDefenseMult()
	local def = self.beyData.stats.Defense or 5
	return 1 - (def / 10) * BeyConfig.DEFENSE_REDUCTION_SCALE
end

function BeyController:getStaminaMult()
	local stamina = self.beyData.stats.Stamina or 6
	local base = stamina / BeyConfig.STAMINA_DECAY_SCALE
	return base * (self.beyData.stats.SpinDecayMult or 1)
end

function BeyController:isInBowl()
	local rel = self.part.Position - self.arenaOrigin
	local flat = Vector3.new(rel.X, 0, rel.Z)
	return flat.Magnitude < self.arenaRadius - 2 and not self.airborne
end

function BeyController:getState()
	return {
		id = self.beyData.id,
		name = self.beyData.name,
		beyType = self.beyData.beyType,
		hp = self.hp,
		spin = math.floor(self.spin),
		special = math.floor(self.special),
		energyReady = self.special >= BeyConfig.MAX_SPECIAL,
		alive = self.alive,
		bursted = self.bursted,
		airborne = self.airborne,
		inBowl = self:isInBowl(),
		playerName = self.player and self.player.Name or "Dummy",
		stats = self.beyData.stats,
		specialName = self.beyData.special,
	}
end

function BeyController:setInput(input)
	if not self.alive or self.specialActive then
		return false
	end

	self.inputDir = input.moveDir or Vector3.zero
	self.charging = input.charging or false

	if input.dodge and os.clock() >= self.dodgeUntil then
		self.dodgeUntil = os.clock() + BeyConfig.DODGE_DURATION
		local dir = self.inputDir.Magnitude > 0.1 and self.inputDir.Unit or self.facing
		self.velocity = dir * BeyConfig.DODGE_SPEED
	end

	if input.spinRecover and os.clock() >= self.spinRecoverUntil then
		local flat = Vector3.new(self.velocity.X, 0, self.velocity.Z)
		if flat.Magnitude <= BeyConfig.SPIN_RECOVERY_MAX_VELOCITY and self.spin < BeyConfig.MAX_SPIN then
			self.spin = math.min(BeyConfig.MAX_SPIN, self.spin + BeyConfig.SPIN_RECOVERY_AMOUNT)
			self.spinRecoverUntil = os.clock() + BeyConfig.SPIN_RECOVERY_COOLDOWN
			self:playSound("SPIN_RECOVER")
			self:spawnSpinBurst()
		end
	end

	if input.jump and os.clock() >= self.jumpUntil then
		self.jumpUntil = os.clock() + 0.35
		if self.airborne then
			-- Dive back into the bowl
			self.verticalVelocity = -BeyConfig.DIVE_FORCE
			self.landingSlam = true
			self:playSound("JUMP")
		else
			-- Launch out of the stadium
			self.verticalVelocity = BeyConfig.JUMP_FORCE
			self.airborne = true
			self:playSound("JUMP")
		end
	end

	if input.special and self.special >= BeyConfig.MAX_SPECIAL and os.clock() >= self.specialCooldownUntil then
		self.special = 0
		self.specialCooldownUntil = os.clock() + BeyConfig.SPECIAL_COOLDOWN
		return true
	end
	return false
end

function BeyController:activateSpecial(target)
	if SpecialMoveRunner.run(self, self.beyData.specialId, target) then
		self:playSound("SPECIAL")
		local move = BeyConfig.SPECIAL_MOVES[self.beyData.specialId]
		if self.onHit then
			self.onHit(self, "specialAnnounce", {
				name = move and move.name or self.beyData.special,
				playerName = self.player and self.player.Name or "Dummy",
				color = move and move.color or self.beyData.color,
			})
		end
	end
end

function BeyController:spawnSpinBurst()
	local burst = Instance.new("Part")
	burst.Anchored = true
	burst.CanCollide = false
	burst.Size = Vector3.new(3, 0.4, 3)
	burst.Shape = Enum.PartType.Cylinder
	burst.Material = Enum.Material.Neon
	burst.Color = self.beyData.color
	burst.Transparency = 0.3
	burst.CFrame = self.part.CFrame
	burst.Parent = workspace:FindFirstChild("Arena") or workspace
	task.delay(0.4, function()
		burst:Destroy()
	end)
end


function BeyController:playSound(key)
	if self.onHit then
		self.onHit(self, "sound", key)
	end
end

function BeyController:burst(fromController)
	if self.bursted then
		return
	end
	self.bursted = true
	self.alive = false
	self.hp = 0
	self.spin = 0

	local pos = self.part.Position
	for i = 1, 6 do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(0.8, 1.2, 0.8)
		shard.Color = self.beyData.color
		shard.Material = Enum.Material.Neon
		shard.CFrame = self.part.CFrame
		shard.CanCollide = false
		shard.Parent = workspace:FindFirstChild("Arena") or workspace

		local vel = Instance.new("BodyVelocity")
		vel.MaxForce = Vector3.new(1e4, 1e4, 1e4)
		local angle = (i / 6) * math.pi * 2
		vel.Velocity = Vector3.new(math.cos(angle) * 30, 20 + i * 3, math.sin(angle) * 30)
		vel.Parent = shard
		task.delay(1.2, function()
			shard:Destroy()
		end)
	end

	local explosion = Instance.new("Part")
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Shape = Enum.PartType.Ball
	explosion.Size = Vector3.new(8, 8, 8)
	explosion.Material = Enum.Material.Neon
	explosion.Color = self.beyData.color
	explosion.Transparency = 0.2
	explosion.CFrame = CFrame.new(pos)
	explosion.Parent = workspace:FindFirstChild("Arena") or workspace
	task.delay(0.5, function()
		explosion:Destroy()
	end)

	self:playSound("BURST")
	if self.onHit then
		self.onHit(self, "burst", {
			name = self.beyData.name,
			playerName = self.player and self.player.Name or "Dummy",
		})
	end

	self.part.Transparency = 1
	for _, vis in self.spinVisuals do
		if vis then
			vis.Transparency = 1
		end
	end
	if self.model then
		for _, desc in self.model:GetDescendants() do
			if desc:IsA("BasePart") and desc ~= self.part then
				desc.Transparency = 1
			end
		end
	end
	self.bodyVelocity.Velocity = Vector3.zero
end

function BeyController:takeHit(fromController, damage, spinLoss, isSpecial)
	if not self.alive or self.underground then
		return
	end

	local now = os.clock()
	local cdKey = fromController
	if self.hitCooldowns[cdKey] and now - self.hitCooldowns[cdKey] < BeyConfig.HIT_COOLDOWN then
		return
	end
	self.hitCooldowns[cdKey] = now

	damage *= fromController:getAttackMult()
	damage *= self:getDefenseMult()

	if self.guardReduction > 0 then
		damage *= (1 - self.guardReduction)
	end

	if self.landingSlam and fromController == self then
		damage = BeyConfig.LANDING_SLAM_DAMAGE * fromController:getAttackMult()
		spinLoss = BeyConfig.LANDING_SLAM_SPIN_LOSS
		isSpecial = true
		self.landingSlam = false
	end

	self.hp = math.max(0, self.hp - damage)
	self.spin = math.max(0, self.spin - spinLoss)
	self.special = math.min(BeyConfig.MAX_SPECIAL, self.special + BeyConfig.HIT_SPECIAL_GAIN)

	local knockDir = (self.part.Position - fromController.part.Position).Unit
	local force = BeyConfig.KNOCKBACK_BASE + damage * BeyConfig.KNOCKBACK_SCALE
	self.velocity += Vector3.new(knockDir.X, 0, knockDir.Z) * force

	self:playSound(isSpecial and "SPECIAL" or "HIT")

	if damage >= BeyConfig.BURST_DAMAGE_THRESHOLD or self.spin <= BeyConfig.BURST_SPIN_THRESHOLD or self.hp <= 0 then
		self:burst(fromController)
	elseif self.spin <= 0 then
		self.alive = false
	end
end

function BeyController:areaHit(allControllers, range, damage, isSpecial)
	for _, other in allControllers do
		if other ~= self and other.alive and not other.underground then
			local dist = (self.part.Position - other.part.Position).Magnitude
			if dist <= range then
				local spinLoss = isSpecial and BeyConfig.SPECIAL_SPIN_LOSS or BeyConfig.HIT_SPIN_LOSS
				other:takeHit(self, damage, spinLoss, isSpecial)
			end
		end
	end
end

function BeyController:updateVertical(dt)
	if not self.airborne then
		local y = self.part.Position.Y
		if y > self.floorY + 0.5 then
			self.airborne = true
		else
			self.verticalVelocity = 0
			return
		end
	end

	self.verticalVelocity -= BeyConfig.GRAVITY * dt
	local newY = self.part.Position.Y + self.verticalVelocity * dt

	-- Land on outer platform ring
	local rel = self.part.Position - self.arenaOrigin
	local flatDist = Vector3.new(rel.X, 0, rel.Z).Magnitude
	local onOuterRing = flatDist > self.arenaRadius - 3 and flatDist < self.outerRadius

	if onOuterRing and newY <= self.platformY and self.verticalVelocity <= 0 then
		local fallSpeed = math.abs(self.verticalVelocity)
		newY = self.platformY
		self.verticalVelocity = 0
		self.airborne = false
		if not (self.landingSlam and fallSpeed >= BeyConfig.LANDING_SLAM_MIN_FALL_SPEED) then
			self.landingSlam = false
		end
	elseif newY <= self.floorY and self.verticalVelocity <= 0 and flatDist < self.arenaRadius - 1 then
		local fallSpeed = math.abs(self.verticalVelocity)
		newY = self.floorY
		self.verticalVelocity = 0
		self.airborne = false
		if not (self.landingSlam and fallSpeed >= BeyConfig.LANDING_SLAM_MIN_FALL_SPEED) then
			self.landingSlam = false
		end
	elseif newY <= self.floorY then
		newY = self.floorY
		self.verticalVelocity = 0
	end

	local pos = self.part.Position
	self.part.CFrame = CFrame.new(Vector3.new(pos.X, newY, pos.Z)) * (self.part.CFrame - self.part.CFrame.Position)
end

function BeyController:update(dt, allControllers)
	if not self.alive then
		self.bodyVelocity.Velocity = Vector3.zero
		return
	end

	SpecialMoveRunner.update(self, dt, allControllers)
	self:updateVertical(dt)

	if self.specialActive then
		self.bodyVelocity.Velocity = Vector3.new(self.velocity.X, self.verticalVelocity, self.velocity.Z)
		self:updateSpinVisual(dt)
		return
	end

	local staminaMult = self:getStaminaMult()
	self.spin = math.max(0, self.spin - BeyConfig.SPIN_DECAY * staminaMult * dt * 10)

	if self.spin <= 0 and self.alive then
		self:burst(nil)
		return
	end

	local moveDir = self.inputDir
	local controlMult = self.airborne and BeyConfig.AIR_CONTROL_MULT or 1

	if moveDir.Magnitude > 0.1 then
		self.facing = moveDir.Unit
		local speedMult = self.charging and BeyConfig.CHARGE_SPEED_MULT or 1
		local targetSpeed = BeyConfig.BASE_SPEED * speedMult * (self.beyData.stats.Speed / 7) * controlMult
		self.velocity += moveDir.Unit * BeyConfig.ACCEL_FORCE * dt * controlMult
		local maxSpeed = targetSpeed * BeyConfig.MAX_SPEED_MULT
		local flat = Vector3.new(self.velocity.X, 0, self.velocity.Z)
		if flat.Magnitude > maxSpeed then
			self.velocity = Vector3.new(flat.Unit.X * maxSpeed, 0, flat.Unit.Z * maxSpeed)
		end
	else
		local flat = Vector3.new(self.velocity.X, 0, self.velocity.Z)
		local friction = BeyConfig.COAST_FRICTION * dt
		if flat.Magnitude > friction then
			self.velocity = flat - flat.Unit * friction
		else
			self.velocity = Vector3.zero
		end
	end

	if os.clock() < self.dodgeUntil then
		-- keep dodge velocity
	elseif not self.airborne then
		local rel = self.part.Position - self.arenaOrigin
		local flat = Vector3.new(rel.X, 0, rel.Z)
		local dist = flat.Magnitude
		if dist > self.arenaRadius - 1 then
			local normal = flat.Unit
			self.velocity = self.velocity - 2 * self.velocity:Dot(normal) * normal * BeyConfig.WALL_BOUNCE
			self.velocity *= BeyConfig.WALL_FRICTION
			local y = self.part.Position.Y
			self.part.CFrame = CFrame.new(
				self.arenaOrigin + normal * (self.arenaRadius - 1.5) + Vector3.new(0, y - self.arenaOrigin.Y, 0)
			) * CFrame.Angles(0, math.atan2(-normal.X, -normal.Z), math.rad(90))
			-- Near rim — easier to jump out
			if self.verticalVelocity <= 0 and dist > self.arenaRadius - 4 then
				self.airborne = true
				self.verticalVelocity = BeyConfig.JUMP_FORCE * 0.5
			end
		elseif dist > 0.1 then
			self.velocity -= flat.Unit * BeyConfig.BOWL_PULL * dt
		end
	end

	self.bodyVelocity.Velocity = Vector3.new(self.velocity.X, self.verticalVelocity, self.velocity.Z)

	if self.isDummy then
		self:updateDummyAi(allControllers, dt)
	end

	self:checkCollisions(allControllers, false)
	self:updateSpinVisual(dt)
end

function BeyController:updateSpinVisual(dt)
	local speed = self.spin / BeyConfig.MAX_SPIN
	self._spinAngle = (self._spinAngle or 0) + speed * dt * 14

	for _, ring in self.spinVisuals do
		if ring and ring.Parent then
			local mult = ring:GetAttribute("SpinMult") or 1
			local offset = ring:GetAttribute("SpinOffset") or CFrame.new()
			local alpha = 0.2 + (1 - speed) * 0.55
			ring.Transparency = math.clamp(alpha, 0.15, 0.75)
			ring.CFrame = self.part.CFrame * CFrame.Angles(0, self._spinAngle * mult, 0) * offset
		end
	end
end

function BeyController:updateDummyAi(allControllers, dt)
	local target
	for _, c in allControllers do
		if not c.isDummy and c.alive then
			target = c
			break
		end
	end
	if not target then
		return
	end

	local dir = (target.part.Position - self.part.Position)
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude > 1 then
		self.inputDir = dir.Unit
		self.charging = dir.Magnitude > 8
	end

	if self.spin < 40 and math.random() < 0.02 then
		self:setInput({ moveDir = Vector3.zero, spinRecover = true })
	end

	if target.airborne and math.random() < 0.015 then
		self:setInput({ moveDir = self.inputDir, jump = true })
	end
end

function BeyController:checkCollisions(allControllers, isSpecial)
	for _, other in allControllers do
		if other ~= self and other.alive then
			local dist = (self.part.Position - other.part.Position).Magnitude
			if dist < HIT_RADIUS then
				local dmg = isSpecial and (self.specialMove and self.specialMove.damage or BeyConfig.SPECIAL_DAMAGE) or BeyConfig.HIT_DAMAGE
				local spinLoss = isSpecial and (self.specialMove and self.specialMove.spinLoss or BeyConfig.SPECIAL_SPIN_LOSS) or BeyConfig.HIT_SPIN_LOSS

				if self.landingSlam and self.airborne == false then
					dmg = BeyConfig.LANDING_SLAM_DAMAGE
					spinLoss = BeyConfig.LANDING_SLAM_SPIN_LOSS
					isSpecial = true
					self.landingSlam = false
				end

				other:takeHit(self, dmg, spinLoss, isSpecial)
			end
		end
	end
end

function BeyController:destroy()
	local SpecialVFX = require(script.Parent.SpecialVFX)
	SpecialVFX.cleanup(self)
	if self.model then
		self.model:Destroy()
	elseif self.part then
		self.part:Destroy()
	end
end

return BeyController
