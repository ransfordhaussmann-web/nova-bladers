local RunService = game:GetService("RunService")

local BeyConfig = require(script.Parent.BeyConfig)
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
	self.isDummy = props.isDummy or false
	self.onHit = props.onHit

	self.hp = BeyConfig.MAX_HP
	self.spin = BeyConfig.MAX_SPIN
	self.special = 0
	self.alive = true

	self.velocity = Vector3.zero
	self.facing = Vector3.new(0, 0, -1)
	self.inputDir = Vector3.zero
	self.charging = false
	self.dodgeUntil = 0
	self.hitCooldowns = {}
	self.specialCooldownUntil = 0
	self.specialActive = false
	self.guardReduction = 0

	self.part = Instance.new("Part")
	self.part.Name = "Bey_" .. (self.player and self.player.Name or "Dummy")
	self.part.Shape = Enum.PartType.Cylinder
	self.part.Size = Vector3.new(1.2, 3.6, 3.6)
	self.part.Anchored = false
	self.part.CanCollide = true
	self.part.Material = Enum.Material.Metal
	self.part.Color = props.beyData.color
	self.part.CFrame = props.spawnCFrame * CFrame.Angles(0, 0, math.rad(90))
	self.part.Parent = workspace:FindFirstChild("Arena") or workspace

	local body = Instance.new("BodyVelocity")
	body.Name = "BeyVelocity"
	body.MaxForce = Vector3.new(1e5, 0, 1e5)
	body.Velocity = Vector3.zero
	body.Parent = self.part

	self.bodyVelocity = body

	local att = Instance.new("Attachment")
	att.Parent = self.part

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(120, 36)
	label.StudsOffset = Vector3.new(0, 3, 0)
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

function BeyController:getState()
	return {
		id = self.beyData.id,
		name = self.beyData.name,
		hp = self.hp,
		spin = self.spin,
		special = self.special,
		alive = self.alive,
		playerName = self.player and self.player.Name or "Dummy",
	}
end

function BeyController:setInput(input)
	if not self.alive or self.specialActive then
		return
	end
	self.inputDir = input.moveDir or Vector3.zero
	self.charging = input.charging or false

	if input.dodge and os.clock() >= self.dodgeUntil then
		self.dodgeUntil = os.clock() + BeyConfig.DODGE_DURATION
		local dir = self.inputDir.Magnitude > 0.1 and self.inputDir.Unit or self.facing
		self.velocity = dir * BeyConfig.DODGE_SPEED
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
	end
end

function BeyController:spawnVfx(move)
	local glow = Instance.new("Part")
	glow.Anchored = true
	glow.CanCollide = false
	glow.Size = Vector3.new(4, 4, 4)
	glow.Shape = Enum.PartType.Ball
	glow.Material = Enum.Material.Neon
	glow.Color = move.color
	glow.Transparency = 0.5
	glow.CFrame = self.part.CFrame
	glow.Parent = workspace:FindFirstChild("Arena") or workspace
	task.delay(move.duration, function()
		glow:Destroy()
	end)
end

function BeyController:playSound(key)
	if self.onHit then
		self.onHit(self, "sound", key)
	end
end

function BeyController:takeHit(fromController, damage, spinLoss, isSpecial)
	if not self.alive then
		return
	end

	local now = os.clock()
	local cdKey = fromController
	if self.hitCooldowns[cdKey] and now - self.hitCooldowns[cdKey] < BeyConfig.HIT_COOLDOWN then
		return
	end
	self.hitCooldowns[cdKey] = now

	if self.guardReduction > 0 then
		damage *= (1 - self.guardReduction)
	end

	self.hp = math.max(0, self.hp - damage)
	self.spin = math.max(0, self.spin - spinLoss)
	self.special = math.min(BeyConfig.MAX_SPECIAL, self.special + BeyConfig.HIT_SPECIAL_GAIN)

	local knockDir = (self.part.Position - fromController.part.Position).Unit
	local force = BeyConfig.KNOCKBACK_BASE + damage * BeyConfig.KNOCKBACK_SCALE
	self.velocity += knockDir * force

	self:playSound(isSpecial and "SPECIAL" or "HIT")

	if self.hp <= 0 or self.spin <= 0 then
		self.alive = false
	end
end

function BeyController:pulseHit(range, damage)
	if not self.onHit then
		return
	end
	self.onHit(self, "pulse", { range = range, damage = damage })
end

function BeyController:update(dt, allControllers)
	if not self.alive then
		self.bodyVelocity.Velocity = Vector3.zero
		return
	end

	SpecialMoveRunner.update(self, dt)

	if self.specialActive then
		self.bodyVelocity.Velocity = Vector3.new(self.velocity.X, 0, self.velocity.Z)
		self:checkCollisions(allControllers, true)
		return
	end

	local spinMult = self.beyData.stats.SpinDecayMult or 1
	self.spin = math.max(0, self.spin - BeyConfig.SPIN_DECAY * spinMult * dt * 10)

	local moveDir = self.inputDir
	if moveDir.Magnitude > 0.1 then
		self.facing = moveDir.Unit
		local speedMult = self.charging and BeyConfig.CHARGE_SPEED_MULT or 1
		local targetSpeed = BeyConfig.BASE_SPEED * speedMult * (self.beyData.stats.Speed / 7)
		self.velocity += moveDir.Unit * BeyConfig.ACCEL_FORCE * dt
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
	else
		local rel = self.part.Position - self.arenaOrigin
		local flat = Vector3.new(rel.X, 0, rel.Z)
		local dist = flat.Magnitude
		if dist > self.arenaRadius - 1 then
			local normal = flat.Unit
			self.velocity = self.velocity - 2 * self.velocity:Dot(normal) * normal * BeyConfig.WALL_BOUNCE
			self.velocity *= BeyConfig.WALL_FRICTION
			self.part.CFrame = CFrame.new(
				self.arenaOrigin + normal * (self.arenaRadius - 1.5) + Vector3.new(0, 1.5, 0)
			) * CFrame.Angles(0, math.atan2(-normal.X, -normal.Z), math.rad(90))
		elseif dist > 0.1 then
			self.velocity -= flat.Unit * BeyConfig.BOWL_PULL * dt
		end
	end

	self.bodyVelocity.Velocity = Vector3.new(self.velocity.X, 0, self.velocity.Z)

	if self.isDummy then
		self:updateDummyAi(allControllers, dt)
	end

	self:checkCollisions(allControllers, false)
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
end

function BeyController:checkCollisions(allControllers, isSpecial)
	for _, other in allControllers do
		if other ~= self and other.alive then
			local dist = (self.part.Position - other.part.Position).Magnitude
			if dist < HIT_RADIUS then
				local dmg = isSpecial and (self.specialMove and self.specialMove.damage or BeyConfig.SPECIAL_DAMAGE) or BeyConfig.HIT_DAMAGE
				local spinLoss = isSpecial and (self.specialMove and self.specialMove.spinLoss or BeyConfig.SPECIAL_SPIN_LOSS) or BeyConfig.HIT_SPIN_LOSS
				other:takeHit(self, dmg, spinLoss, isSpecial)
			end
		end
	end
end

function BeyController:destroy()
	if self.part then
		self.part:Destroy()
	end
end

return BeyController
