local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTES = {
	{ name = "LobbyReady", className = "RemoteEvent" },
	{ name = "EnterArena", className = "RemoteEvent" },
	{ name = "OpenBeySelect", className = "RemoteEvent" },
	{ name = "ReturnToHub", className = "RemoteEvent" },
	{ name = "HubState", className = "RemoteEvent" },
}

local RemotesSetup = {}

function RemotesSetup.getFolder()
	local root = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not root then
		root = Instance.new("Folder")
		root.Name = "NovaBladers"
		root.Parent = ReplicatedStorage
	end

	local remotes = root:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = root
	end

	return remotes
end

function RemotesSetup.ensure()
	local folder = RemotesSetup.getFolder()
	local created = {}

	for _, spec in REMOTES do
		local remote = folder:FindFirstChild(spec.name)
		if not remote then
			remote = Instance.new(spec.className)
			remote.Name = spec.name
			remote.Parent = folder
			created[spec.name] = true
		end
	end

	return folder, created
end

return RemotesSetup
