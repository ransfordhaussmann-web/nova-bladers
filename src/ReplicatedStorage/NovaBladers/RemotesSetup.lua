local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemote(parent, name)
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

local RemotesSetup = {
	LobbyReady = ensureRemote(Remotes, "LobbyReady"),
	EnterArena = ensureRemote(Remotes, "EnterArena"),
	OpenBeySelect = ensureRemote(Remotes, "OpenBeySelect"),
	HubZoneHint = ensureRemote(Remotes, "HubZoneHint"),
	HubZoneAction = ensureRemote(Remotes, "HubZoneAction"),
	ReturnToHub = ensureRemote(Remotes, "ReturnToHub"),
}

return RemotesSetup
