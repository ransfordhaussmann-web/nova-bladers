local DataStoreService = game:GetService("DataStoreService")

local STORE = DataStoreService:GetDataStore("NovaBladers_PlayerData_v1")
local cache = {}
local DEFAULT = { Wins = 0, Losses = 0 }

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
	end
	cache[player] = data
	return data
end

function PlayerDataManager.get(player)
	local data = cache[player]
	if data then
		return data
	end
	return table.clone(DEFAULT)
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

function PlayerDataManager.persist(player)
	local data = cache[player]
	if not data then return end
	local key = "u_" .. player.UserId
	pcall(function()
		STORE:SetAsync(key, { Wins = data.Wins, Losses = data.Losses })
	end)
end

function PlayerDataManager.save(player)
	PlayerDataManager.persist(player)
	cache[player] = nil
end

return PlayerDataManager
