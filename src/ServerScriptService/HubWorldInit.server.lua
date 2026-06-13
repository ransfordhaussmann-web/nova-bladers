local ServerScriptService = game:GetService("ServerScriptService")

local remotes = require(ServerScriptService.RemotesSetup)
local HubWorldManager = require(ServerScriptService.HubWorld.HubWorldManager)

HubWorldManager.init(remotes)
