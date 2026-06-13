local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureChild(parent, className, name)
	local child = parent:FindFirstChild(name)
	if not child then
		child = Instance.new(className)
		child.Name = name
		child.Parent = parent
	end
	return child
end

local RemotesSetup = {}

function RemotesSetup.getRemotes()
	local root = ensureChild(ReplicatedStorage, "Folder", "NovaBladers")
	local remotes = ensureChild(root, "Folder", "Remotes")

	return {
		EnterArena = ensureChild(remotes, "RemoteEvent", "EnterArena"),
		LobbyReady = ensureChild(remotes, "RemoteEvent", "LobbyReady"),
		OpenBeySelect = ensureChild(remotes, "RemoteEvent", "OpenBeySelect"),
		HubStateChanged = ensureChild(remotes, "RemoteEvent", "HubStateChanged"),
	}
end

return RemotesSetup
