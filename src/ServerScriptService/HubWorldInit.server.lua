local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function ensureRemotes()
	local nova = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not nova then
		nova = Instance.new("Folder")
		nova.Name = "NovaBladers"
		nova.Parent = ReplicatedStorage
	end

	local remotes = nova:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = nova
	end

	local remoteNames = {
		"LobbyReady",
		"EnterArena",
		"OpenBeySelect",
		"ReturnToHub",
		"HubZoneHint",
	}

	for _, name in remoteNames do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotes
		end
	end

	return remotes
end

ensureRemotes()

local HubWorldManager = require(ServerScriptService.HubWorldManager)
HubWorldManager.init()
