local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemote(folder, name, className)
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

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

function RemotesSetup.ensureAll()
	local remotes = RemotesSetup.getFolder()
	return {
		EnterArena = ensureRemote(remotes, "EnterArena", "RemoteEvent"),
		LobbyReady = ensureRemote(remotes, "LobbyReady", "RemoteEvent"),
		OpenBeySelect = ensureRemote(remotes, "OpenBeySelect", "RemoteEvent"),
		HubState = ensureRemote(remotes, "HubState", "RemoteEvent"),
	}
end

return RemotesSetup
