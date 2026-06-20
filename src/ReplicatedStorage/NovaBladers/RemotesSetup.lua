local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"HubZoneHint",
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

	for _, name in REMOTE_NAMES do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotes
		end
	end

	return remotes
end

return RemotesSetup
