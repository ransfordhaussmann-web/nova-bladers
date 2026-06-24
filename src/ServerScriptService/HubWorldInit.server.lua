local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldManager.init()

_G.NovaBladersReturnToHub = function(player)
	HubWorldManager.returnToHub(player)
end
