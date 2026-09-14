local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchModes = {}

local byId = {}

for _, mode in MatchmakingConfig.MODES do
	byId[mode.id] = mode
end

function MatchModes.get(modeId)
	return byId[modeId]
end

function MatchModes.getAll()
	local list = {}
	for _, mode in MatchmakingConfig.MODES do
		table.insert(list, mode)
	end
	return list
end

function MatchModes.getHubPad(modeId)
	for _, pad in HubConfig.MODE_PADS do
		if pad.id == modeId then
			return pad
		end
	end
	return nil
end

function MatchModes.resolveAuto(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
