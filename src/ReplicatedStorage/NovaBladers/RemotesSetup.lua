local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureChild(parent: Instance, className: string, name: string): Instance
	local child = parent:FindFirstChild(name)
	if not child then
		child = Instance.new(className)
		child.Name = name
		child.Parent = parent
	end
	return child
end

local nova = ensureChild(ReplicatedStorage, "Folder", "NovaBladers")
local remotesFolder = ensureChild(nova, "Folder", "Remotes")

local function remote(name: string)
	return ensureChild(remotesFolder, "RemoteEvent", name)
end

return {
	EnterArena = remote("EnterArena"),
	LobbyReady = remote("LobbyReady"),
	OpenBeySelect = remote("OpenBeySelect"),
	HubState = remote("HubState"),
	RefreshHubStats = remote("RefreshHubStats"),
}
