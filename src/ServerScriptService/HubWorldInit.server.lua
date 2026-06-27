local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)

ReplicatedStorage:WaitForChild("NovaBladers")
HubWorldManager.init()
