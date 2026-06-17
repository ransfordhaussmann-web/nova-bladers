local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"ReturnToHub",
	"HubZoneHint",
}

local novaFolder = ReplicatedStorage:FindFirstChild("NovaBladers")
if not novaFolder then
	novaFolder = Instance.new("Folder")
	novaFolder.Name = "NovaBladers"
	novaFolder.Parent = ReplicatedStorage
end

local remotesFolder = novaFolder:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = novaFolder
end

for _, name in REMOTE_NAMES do
	if not remotesFolder:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
end
