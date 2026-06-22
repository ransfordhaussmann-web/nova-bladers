local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemote(folder: Folder, name: string, className: string)
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
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

return {
	LobbyReady = ensureRemote(Remotes, "LobbyReady", "RemoteEvent"),
	EnterArena = ensureRemote(Remotes, "EnterArena", "RemoteEvent"),
	OpenBeySelect = ensureRemote(Remotes, "OpenBeySelect", "RemoteEvent"),
	HubZoneHint = ensureRemote(Remotes, "HubZoneHint", "RemoteEvent"),
	HubZoneAction = ensureRemote(Remotes, "HubZoneAction", "RemoteEvent"),
}
