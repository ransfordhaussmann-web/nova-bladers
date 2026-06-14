local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemote(folder, name, className)
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

local nova = ReplicatedStorage:FindFirstChild("NovaBladers")
if not nova then
	nova = Instance.new("Folder")
	nova.Name = "NovaBladers"
	nova.Parent = ReplicatedStorage
end

local remotes = nova:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = nova
end

ensureRemote(remotes, "EnterArena", "RemoteEvent")
ensureRemote(remotes, "LobbyReady", "RemoteEvent")
ensureRemote(remotes, "OpenBeySelect", "RemoteEvent")
