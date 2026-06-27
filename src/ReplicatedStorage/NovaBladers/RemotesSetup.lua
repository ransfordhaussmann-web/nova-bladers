local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:FindFirstChild("NovaBladers")
if not NovaBladers then
	NovaBladers = Instance.new("Folder")
	NovaBladers.Name = "NovaBladers"
	NovaBladers.Parent = ReplicatedStorage
end

local remotesFolder = NovaBladers:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = NovaBladers
end

local REMOTE_NAMES = {
	"EnterArena",
	"LobbyReady",
	"OpenBeySelect",
}

for _, name in REMOTE_NAMES do
	if not remotesFolder:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
end

return remotesFolder
