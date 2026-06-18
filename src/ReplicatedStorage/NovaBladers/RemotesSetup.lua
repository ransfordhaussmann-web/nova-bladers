local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"ReturnToHub",
	"HubZoneAction",
}

local RemotesSetup = {}

function RemotesSetup.ensure(parent)
	parent = parent or ReplicatedStorage:WaitForChild("NovaBladers")
	local folder = parent:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = parent
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
