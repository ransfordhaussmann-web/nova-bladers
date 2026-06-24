local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureChild(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child then
		return child
	end
	child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local NovaBladers = ensureChild(ReplicatedStorage, "Folder", "NovaBladers")
local Remotes = ensureChild(NovaBladers, "Folder", "Remotes")

local REMOTE_NAMES = {
	"LobbyReady",
	"EnterArena",
	"OpenBeySelect",
	"HubZoneHint",
}

local created = {}
for _, name in REMOTE_NAMES do
	created[name] = ensureChild(Remotes, "RemoteEvent", name)
end

return created
