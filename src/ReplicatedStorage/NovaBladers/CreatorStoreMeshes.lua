--[[
	Creator Store mesh slots for Nova Bladers beys.

	How to use:
	1. Roblox Studio → Toolbox → Creator Store → search the term below
	2. Insert model, copy MeshId from mesh part (or import whole model to Models/)
	3. Set meshId here OR place cloned model under ReplicatedStorage/NovaBladers/Models/

	Procedural fallback builds run when neither meshId nor Models/ clone exists.
]]

local CreatorStoreMeshes = {
	CrimsonFang = {
		studioModelName = "CrimsonFang",
		creatorStoreSearch = "spinning top red attack",
		targetSize = 3.5,
		-- meshId = "rbxassetid://YOUR_MESH_ID",
		-- textureId = "rbxassetid://YOUR_TEXTURE_ID",
		size = Vector3.new(3.6, 1.2, 3.6),
	},
	FrostCrown = {
		studioModelName = "FrostCrown",
		creatorStoreSearch = "spinning top ice blue",
		targetSize = 3.5,
		-- meshId = "rbxassetid://YOUR_MESH_ID",
		size = Vector3.new(3.6, 1.2, 3.6),
	},
	IronShell = {
		studioModelName = "IronShell",
		creatorStoreSearch = "beyblade defense green shell",
		targetSize = 3.5,
		-- meshId = "rbxassetid://YOUR_MESH_ID",
		size = Vector3.new(3.8, 1.3, 3.8),
	},
	VoltDash = {
		studioModelName = "VoltDash",
		creatorStoreSearch = "spinning top yellow stamina",
		targetSize = 3.5,
		-- meshId = "rbxassetid://YOUR_MESH_ID",
		size = Vector3.new(3.6, 1.0, 3.6),
	},
}

return CreatorStoreMeshes
