local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local RemotesSetup = require(NovaBladers.RemotesSetup)
local HubWorldManager = require(script.Parent.HubWorldManager)

local remotes = RemotesSetup.ensure()
HubWorldManager.init(remotes)
