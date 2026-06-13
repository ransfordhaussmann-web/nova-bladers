--[[
	Creates Nova Bladers RemoteEvents if missing.
	Require once from a server script (e.g. HubWorldInit) in Studio.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"EnterArena",
	"LobbyReady",
	"OpenBeySelect",
	"HubState",
}

local function ensureRemotes()
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

	for _, name in REMOTE_NAMES do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotes
		end
	end

	return remotes
end

return ensureRemotes
