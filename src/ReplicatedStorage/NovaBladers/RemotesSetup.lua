local function ensureRemote(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

local RemotesSetup = {}

function RemotesSetup.ensure()
	local root = game:GetService("ReplicatedStorage"):FindFirstChild("NovaBladers")
	if not root then
		root = Instance.new("Folder")
		root.Name = "NovaBladers"
		root.Parent = game:GetService("ReplicatedStorage")
	end

	local remotes = root:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = root
	end

	return {
		LobbyReady = ensureRemote(remotes, "LobbyReady", "RemoteEvent"),
		EnterArena = ensureRemote(remotes, "EnterArena", "RemoteEvent"),
		ReturnToHub = ensureRemote(remotes, "ReturnToHub", "RemoteEvent"),
		HubZoneChanged = ensureRemote(remotes, "HubZoneChanged", "RemoteEvent"),
		OpenBeySelect = ensureRemote(remotes, "OpenBeySelect", "RemoteEvent"),
	}
end

return RemotesSetup
