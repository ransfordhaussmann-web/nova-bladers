local DataStoreService = game:GetService("DataStoreService")

local STORE = DataStoreService:GetDataStore("NovaBladers_PlayerData_v1")
local cache = {}
local DEFAULT = { Wins = 0, Losses = 0, SelectedBey = "NovaStriker" }

local PlayerDataManager = {}

function PlayerDataManager.getRankPoints(data)
	return (data.Wins * 3) - data.Losses
end

function PlayerDataManager.load(player)
	local key = "u_" .. player.UserId
	local data = table.clone(DEFAULT)
	local ok, result = pcall(function()
		return STORE:GetAsync(key)
	end)
	if ok and typeof(result) == "table" then
		data.Wins = tonumber(result.Wins) or 0
		data.Losses = tonumber(result.Losses) or 0
		data.SelectedBey = result.SelectedBey or DEFAULT.SelectedBey
	end
	cache[player] = data
	return data
end

function PlayerDataManager.get(player)
	return cache[player] or DEFAULT
end

function PlayerDataManager.recordMatch(player, won)
	local data = cache[player]
	if not data then return end
	if won then
		data.Wins += 1
	else
		data.Losses += 1
	end
end

function PlayerDataManager.setSelectedBey(player, beyId)
	local data = cache[player]
	if not data then return end
	data.SelectedBey = beyId
end

function PlayerDataManager.getSelectedBey(player)
	local data = cache[player]
	return data and data.SelectedBey or DEFAULT.SelectedBey
end

function PlayerDataManager.persist(player)
	local data = cache[player]
	if not data then return end
	local key = "u_" .. player.UserId
	pcall(function()
		STORE:SetAsync(key, {
			Wins = data.Wins,
			Losses = data.Losses,
			SelectedBey = data.SelectedBey,
		})
	end)
end

function PlayerDataManager.save(player)
	PlayerDataManager.persist(player)
	cache[player] = nil
end

return PlayerDataManager
