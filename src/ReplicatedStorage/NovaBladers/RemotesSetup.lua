local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"HubZoneHint",
	"HubZoneAction",
}

local RemotesSetup = {}

local function ensureRemote(folder, name)
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

function RemotesSetup.setup()
	local nova = ReplicatedStorage:WaitForChild("NovaBladers")
	local remotes = nova:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = nova
	end

	for _, name in REMOTE_NAMES do
		ensureRemote(remotes, name)
	end

	return remotes
end

return RemotesSetup
