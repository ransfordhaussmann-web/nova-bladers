local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CLIENT_TO_SERVER = { "EnterArena", "ReturnToHub", "HubZoneAction" }
local SERVER_TO_CLIENT = { "LobbyReady", "OpenBeySelect", "ShowHallPanel" }

local RemotesSetup = {}

function RemotesSetup.ensure()
	local root = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not root then
		root = Instance.new("Folder")
		root.Name = "NovaBladers"
		root.Parent = ReplicatedStorage
	end

	local remotes = root:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = root
	end

	for _, name in CLIENT_TO_SERVER do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotes
		end
	end

	for _, name in SERVER_TO_CLIENT do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotes
		end
	end

	return remotes
end

return RemotesSetup
