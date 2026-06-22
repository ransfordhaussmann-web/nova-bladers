local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_DEFS = {
	{ name = "LobbyReady", className = "RemoteEvent" },
	{ name = "EnterArena", className = "RemoteEvent" },
	{ name = "OpenBeySelect", className = "RemoteEvent" },
	{ name = "ReturnToHub", className = "RemoteEvent" },
	{ name = "HubZoneHint", className = "RemoteEvent" },
	{ name = "HubZoneAction", className = "RemoteEvent" },
}

local RemotesSetup = {}

function RemotesSetup.ensure()
	local folder = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "NovaBladers"
		folder.Parent = ReplicatedStorage
	end

	local remotes = folder:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = folder
	end

	for _, def in REMOTE_DEFS do
		if not remotes:FindFirstChild(def.name) then
			local remote = Instance.new(def.className)
			remote.Name = def.name
			remote.Parent = remotes
		end
	end

	return remotes
end

return RemotesSetup
