local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"HubZoneHint",
	"HubZoneAction",
	"ReturnToHub",
}

local RemotesSetup = {}

function RemotesSetup.ensure(parent)
	local remotes = parent:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = parent
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
