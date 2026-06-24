local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"HubZoneHint",
	"HubZoneAction",
	"ReturnToHub",
}

local RemotesSetup = {}

function RemotesSetup.ensure()
	local root = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not root then
		root = Instance.new("Folder")
		root.Name = "NovaBladers"
		root.Parent = ReplicatedStorage
	end

	local folder = root:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = root
	end

	for _, name in REMOTE_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	return folder
end

return RemotesSetup
