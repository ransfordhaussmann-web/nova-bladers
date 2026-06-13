local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemote(parent, name)
	local remote = parent:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = parent
	end
	return remote
end

local nova = ReplicatedStorage:FindFirstChild("NovaBladers")
if not nova then
	nova = Instance.new("Folder")
	nova.Name = "NovaBladers"
	nova.Parent = ReplicatedStorage
end

local remotesFolder = nova:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = nova
end

local remotes = {
	EnterArena = ensureRemote(remotesFolder, "EnterArena"),
	LobbyReady = ensureRemote(remotesFolder, "LobbyReady"),
	OpenBeySelect = ensureRemote(remotesFolder, "OpenBeySelect"),
}

return remotes
