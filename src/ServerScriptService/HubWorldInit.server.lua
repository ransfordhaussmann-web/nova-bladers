local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local HubWorldManager = require(script.Parent.HubWorldManager)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

RemotesSetup.ensureAll()
local hub = HubWorldBuilder.build()
HubWorldManager.init(hub)
