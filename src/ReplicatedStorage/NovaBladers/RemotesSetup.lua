local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getOrCreate(className: string, name: string, parent: Instance)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local NovaBladers = ReplicatedStorage:FindFirstChild("NovaBladers")
if not NovaBladers then
	NovaBladers = Instance.new("Folder")
	NovaBladers.Name = "NovaBladers"
	NovaBladers.Parent = ReplicatedStorage
end

local Remotes = getOrCreate("Folder", "Remotes", NovaBladers)

return {
	EnterArena = getOrCreate("RemoteEvent", "EnterArena", Remotes),
	LobbyReady = getOrCreate("RemoteEvent", "LobbyReady", Remotes),
	OpenBeySelect = getOrCreate("RemoteEvent", "OpenBeySelect", Remotes),
	HubShowStats = getOrCreate("RemoteEvent", "HubShowStats", Remotes),
	ArenaEntered = getOrCreate("RemoteEvent", "ArenaEntered", Remotes),
}
