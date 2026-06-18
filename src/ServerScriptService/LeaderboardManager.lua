local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ORDERED = DataStoreService:GetOrderedDataStore("NovaBladers_GlobalRank_v1")

local LeaderboardManager = {}

function LeaderboardManager.submit(player, rankPoints)
	pcall(function()
		ORDERED:SetAsync(tostring(player.UserId), math.max(0, rankPoints))
	end)
end

function LeaderboardManager.getTop(count)
	count = count or 5
	local entries = {}
	local ok, pages = pcall(function()
		return ORDERED:GetSortedAsync(false, count)
	end)
	if not ok or not pages then return entries end

	for rank, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		local name = "Spieler"
		if userId then
			local nameOk, resolved = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if nameOk then name = resolved end
		end
		table.insert(entries, {
			rank = rank,
			name = name,
			points = item.value,
		})
	end
	return entries
end

function LeaderboardManager.getPlayerRank(userId, scanLimit)
	scanLimit = scanLimit or 100
	local ok, pages = pcall(function()
		return ORDERED:GetSortedAsync(false, scanLimit)
	end)
	if not ok or not pages then return 0 end

	for rank, item in pages:GetCurrentPage() do
		if tonumber(item.key) == userId then
			return rank
		end
	end
	return 0
end

return LeaderboardManager
