local CosmeticsConfig = require(script.Parent.CosmeticsConfig)

local BeyTrail = {}

function BeyTrail.attach(part, trailId)
	local trailData = CosmeticsConfig.getTrail(trailId)

	local att0 = Instance.new("Attachment")
	att0.Name = "TrailAtt0"
	att0.Position = Vector3.new(0, 0, 1.2)
	att0.Parent = part

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailAtt1"
	att1.Position = Vector3.new(0, 0, -1.2)
	att1.Parent = part

	local trail = Instance.new("Trail")
	trail.Name = "SpeedTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, trailData.color),
		ColorSequenceKeypoint.new(1, trailData.accent),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.35
	trail.MinLength = 0.05
	trail.LightEmission = 0.6
	trail.Enabled = false
	trail.Parent = part

	return {
		trail = trail,
		minSpeed = trailData.minSpeed,
	}
end

function BeyTrail.update(trailState, velocity)
	if not trailState or not trailState.trail then
		return
	end
	local speed = velocity.Magnitude
	trailState.trail.Enabled = speed >= trailState.minSpeed
end

function BeyTrail.destroy(trailState)
	if not trailState then
		return
	end
	if trailState.trail then
		trailState.trail:Destroy()
	end
end

return BeyTrail
