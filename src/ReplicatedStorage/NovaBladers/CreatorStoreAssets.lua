--[[
	Creator Store mesh slots for Nova Bladers Bey models.

	Studio: Toolbox → Creator Store → search "spinning top" / "bey" (free assets).
	Paste rbxassetid into meshId (nil = procedural fallback in BeyModelBuilder).

	Optional studio imports: ReplicatedStorage/NovaBladers/Models/<studioModelName>
]]

local CreatorStoreAssets = {
	NovaStriker = {
		meshId = nil,
		textureId = nil,
		size = Vector3.new(3.6, 1.2, 3.6),
	},
	IronShell = {
		meshId = nil,
		textureId = nil,
		size = Vector3.new(3.8, 1.3, 3.8),
	},
	VoltDash = {
		meshId = nil,
		textureId = nil,
		size = Vector3.new(3.5, 1.0, 3.5),
	},
	ShadowBite = {
		meshId = nil,
		textureId = nil,
		size = Vector3.new(3.6, 1.2, 3.6),
	},
	CrimsonFang = {
		meshId = nil,
		textureId = nil,
		size = Vector3.new(3.7, 1.2, 3.7),
	},
	FrostCrown = {
		meshId = nil,
		textureId = nil,
		size = Vector3.new(3.9, 1.4, 3.9),
	},
}

return CreatorStoreAssets
