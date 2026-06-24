local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

RemotesSetup.ensure()
HubWorldManager.init()

_G.NovaBladersReturnToHub = function(player)
	HubWorldManager.returnToHub(player)
end
