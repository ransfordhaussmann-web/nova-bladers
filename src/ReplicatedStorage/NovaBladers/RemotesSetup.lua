local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = {}

local REMOTE_EVENTS = {
	"LobbyReady",
	"EnterArena",
	"HubState",
	"ReturnToHub",
	"BeySelectStart",
	"BeySelectPick",
	"MatchState",
	"BeyStatsUpdate",
	"MatchResult",
	"BeyInput",
	"PlaySound",
	"SpecialAnnounce",
	"BurstEvent",
	-- Walkable hub world
	"OpenBeySelect",
	"HubZoneHint",
	"HubInteract",
}

local BINDABLE_EVENTS = {
	"EnterArena",
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

	local bindables = nova:FindFirstChild("Bindables")
	if not bindables then
		bindables = Instance.new("Folder")
		bindables.Name = "Bindables"
		bindables.Parent = nova
	end

	for _, name in BINDABLE_EVENTS do
		if not bindables:FindFirstChild(name) then
			local bindable = Instance.new("BindableEvent")
			bindable.Name = name
			bindable.Parent = bindables
		end
	end

	return remotes, bindables
end

return RemotesSetup
