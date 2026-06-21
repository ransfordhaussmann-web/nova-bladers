local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemote(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

local nova = ReplicatedStorage:WaitForChild("NovaBladers")
local remotes = nova:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = nova
end

ensureRemote(remotes, "LobbyReady", "RemoteEvent")
ensureRemote(remotes, "EnterArena", "RemoteEvent")
ensureRemote(remotes, "OpenBeySelect", "RemoteEvent")
ensureRemote(remotes, "HubZoneHint", "RemoteEvent")

return remotes
