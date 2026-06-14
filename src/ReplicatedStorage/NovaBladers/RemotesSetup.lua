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

local function ensureRemoteEvent(parent, name)
	local remote = parent:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = parent
	end
	return remote
end

local RemotesSetup = {}

function RemotesSetup.getRemotes()
	local root = ensureFolder(ReplicatedStorage, "NovaBladers")
	local remotes = ensureFolder(root, "Remotes")
	for _, name in REMOTE_NAMES do
		ensureRemoteEvent(remotes, name)
	end
	return remotes
end

return RemotesSetup
