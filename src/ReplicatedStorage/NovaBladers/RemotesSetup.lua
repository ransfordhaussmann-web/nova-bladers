local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function ensureRemote(remotes, name, className)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local root = ensureFolder(ReplicatedStorage, "NovaBladers")
local remotes = ensureFolder(root, "Remotes")

return {
	EnterArena = ensureRemote(remotes, "EnterArena", "RemoteEvent"),
	LobbyReady = ensureRemote(remotes, "LobbyReady", "RemoteEvent"),
	OpenBeySelect = ensureRemote(remotes, "OpenBeySelect", "RemoteEvent"),
	HubState = ensureRemote(remotes, "HubState", "RemoteEvent"),
	RefreshHubStats = ensureRemote(remotes, "RefreshHubStats", "RemoteEvent"),
}
