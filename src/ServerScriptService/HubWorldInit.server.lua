local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local HubWorldManager = require(script.Parent.HubWorldManager)

local remotes = RemotesSetup.setup()
local hub = HubWorldBuilder.build()
HubWorldManager.init(remotes, hub)
