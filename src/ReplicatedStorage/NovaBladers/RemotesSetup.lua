local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemoteEvent(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local NovaBladers = ReplicatedStorage:FindFirstChild("NovaBladers")
if not NovaBladers then
	NovaBladers = Instance.new("Folder")
	NovaBladers.Name = "NovaBladers"
	NovaBladers.Parent = ReplicatedStorage
end

local Remotes = NovaBladers:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = NovaBladers
end

ensureRemoteEvent(Remotes, "EnterArena")
ensureRemoteEvent(Remotes, "LobbyReady")
ensureRemoteEvent(Remotes, "OpenBeySelect")
ensureRemoteEvent(Remotes, "HubZoneChanged")

return Remotes
