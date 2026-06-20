local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"HubZoneTouched",
}

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function ensureRemote(folder, name, className)
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

local nova = ensureFolder(ReplicatedStorage, "NovaBladers")
local remotes = ensureFolder(nova, "Remotes")

for _, name in REMOTE_NAMES do
	ensureRemote(remotes, name, "RemoteEvent")
end

return remotes
