local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticsConfig = require(ReplicatedStorage.NovaBladers.CosmeticsConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local CosmeticsService = {}
local remotes

local function buildCatalog()
	local trails = {}
	for id, trail in CosmeticsConfig.TRAILS do
		table.insert(trails, {
			id = id,
			name = trail.name,
			color = trail.color,
		})
	end
	table.sort(trails, function(a, b)
		return a.name < b.name
	end)

	local arenaSkins = {}
	for id, skin in CosmeticsConfig.ARENA_SKINS do
		table.insert(arenaSkins, {
			id = id,
			name = skin.name,
			rim = skin.rim,
		})
	end
	table.sort(arenaSkins, function(a, b)
		return a.name < b.name
	end)

	return { trails = trails, arenaSkins = arenaSkins }
end

function CosmeticsService.init(remoteFolder)
	remotes = remoteFolder

	remotes.CosmeticsSelect.OnServerEvent:Connect(function(player, selection)
		if typeof(selection) ~= "table" then
			return
		end

		local trailId = selection.trailId
		local arenaSkin = selection.arenaSkin

		if trailId and not CosmeticsConfig.TRAILS[trailId] then
			trailId = nil
		end
		if arenaSkin and not CosmeticsConfig.ARENA_SKINS[arenaSkin] then
			arenaSkin = nil
		end

		PlayerDataManager.setCosmetics(player, trailId, arenaSkin)
		PlayerDataManager.persist(player)
		CosmeticsService.sendCosmetics(player)
	end)
end

function CosmeticsService.sendCosmetics(player)
	if not remotes then
		return
	end
	local cosmetics = PlayerDataManager.getCosmetics(player)
	remotes.CosmeticsUpdate:FireClient(player, {
		trailId = cosmetics.trailId,
		arenaSkin = cosmetics.arenaSkin,
		catalog = buildCatalog(),
	})
end

function CosmeticsService.getArenaSkinForMatch(players)
	for _, player in players do
		local cosmetics = PlayerDataManager.getCosmetics(player)
		if cosmetics.arenaSkin then
			return cosmetics.arenaSkin
		end
	end
	return CosmeticsConfig.DEFAULT_ARENA_SKIN
end

return CosmeticsService
