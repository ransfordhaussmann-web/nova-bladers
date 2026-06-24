local RemotesSetup = {}

local REMOTE_DEFS = {
	{ name = "LobbyReady", className = "RemoteEvent" },
	{ name = "EnterArena", className = "RemoteEvent" },
	{ name = "OpenBeySelect", className = "RemoteEvent" },
	{ name = "HubZoneHint", className = "RemoteEvent" },
	{ name = "HubZoneAction", className = "RemoteEvent" },
}

function RemotesSetup.ensure(remotesFolder)
	for _, def in REMOTE_DEFS do
		if not remotesFolder:FindFirstChild(def.name) then
			local remote = Instance.new(def.className)
			remote.Name = def.name
			remote.Parent = remotesFolder
		end
	end
	return remotesFolder
end

return RemotesSetup
