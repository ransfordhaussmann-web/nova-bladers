local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"ReturnToHub",
	"ShowHallPanel",
	"HubZoneAction",
}

local RemotesSetup = {}

local function ensureRemote(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

function RemotesSetup.setup()
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

	for _, name in REMOTE_NAMES do
		ensureRemote(remotes, name, "RemoteEvent")
	end

	return remotes
end

return RemotesSetup
