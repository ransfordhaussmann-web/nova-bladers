local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = {}

local REMOTE_EVENTS = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"BeySelectPick",
	"BeySelectStart",
	"MatchState",
}

function RemotesSetup.ensure()
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

	for _, name in REMOTE_EVENTS do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotes
		end
	end

	return remotes
end

return RemotesSetup
