local REMOTES = {
	{ name = "LobbyReady", className = "RemoteEvent" },
	{ name = "EnterArena", className = "RemoteEvent" },
	{ name = "OpenBeySelect", className = "RemoteEvent" },
	{ name = "HubZoneHint", className = "RemoteEvent" },
	{ name = "HubZoneAction", className = "RemoteEvent" },
}

local RemotesSetup = {}

function RemotesSetup.ensure(remotesFolder)
	for _, spec in REMOTES do
		if not remotesFolder:FindFirstChild(spec.name) then
			local remote = Instance.new(spec.className)
			remote.Name = spec.name
			remote.Parent = remotesFolder
		end
	end
	return remotesFolder
end

return RemotesSetup
