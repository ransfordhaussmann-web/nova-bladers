local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local HubWorldManager = require(ServerScriptService.HubWorldManager)

local hub = HubWorldBuilder.build(workspace)
HubWorldManager.init(hub)
