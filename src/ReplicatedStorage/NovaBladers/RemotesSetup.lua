local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"ReturnToHub",
}

local RemotesSetup = {}

function RemotesSetup.ensure()
	local novaBladers = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not novaBladers then
		novaBladers = Instance.new("Folder")
		novaBladers.Name = "NovaBladers"
		novaBladers.Parent = ReplicatedStorage
	end

	local remotes = novaBladers:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = novaBladers
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
