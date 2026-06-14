local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = {}

local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
}

local function getNovaFolder()
	local nova = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not nova then
		nova = Instance.new("Folder")
		nova.Name = "NovaBladers"
		nova.Parent = ReplicatedStorage
	end
	return nova
end

function RemotesSetup.getRemotesFolder()
	local nova = getNovaFolder()
	local remotes = nova:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = nova
	end
	return remotes
end

function RemotesSetup.ensure(name, className)
	className = className or "RemoteEvent"
	local remotes = RemotesSetup.getRemotesFolder()
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

function RemotesSetup.init()
	for _, name in REMOTE_NAMES do
		RemotesSetup.ensure(name)
	end
end

return RemotesSetup
