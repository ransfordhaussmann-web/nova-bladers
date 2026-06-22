local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldManager.init()
