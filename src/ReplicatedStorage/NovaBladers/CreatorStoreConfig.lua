--[[
	Central place to paste Creator Store mesh IDs after inserting models from Toolbox.

	Studio workflow:
	1. View → Toolbox → Creator Store → search terms from BeyCatalog.modelRef.creatorStore
	2. Insert model, scale to ~3–4 studs wide, lay flat on ground
	3. Copy MeshId from the main MeshPart (or note asset ID from store URL)
	4. Paste rbxassetid string below for that bey id

	When meshId is set here, BeyModelBuilder uses it instead of procedural layers.
]]

local CreatorStoreConfig = {
	meshIds = {
		NovaStriker = nil,
		IronShell = nil,
		VoltDash = nil,
		ShadowBite = nil,
		EmberCore = nil,
		TidalRing = nil,
	},

	-- Default MeshPart size when using Creator Store meshes (studs)
	defaultSize = Vector3.new(3.6, 1.2, 3.6),
}

return CreatorStoreConfig
