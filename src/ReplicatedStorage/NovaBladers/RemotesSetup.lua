local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"EnterArena",
	"LobbyReady",
	"OpenBeySelect",
	"HubState",
	"RefreshHubStats",
}

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local RemotesSetup = {}

function RemotesSetup.ensure()
	local root = ensureFolder(ReplicatedStorage, "NovaBladers")
	local remotes = ensureFolder(root, "Remotes")

	for _, remoteName in REMOTE_NAMES do
		if not remotes:FindFirstChild(remoteName) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = remotes
		end
	end

	return remotes
end

return RemotesSetup
