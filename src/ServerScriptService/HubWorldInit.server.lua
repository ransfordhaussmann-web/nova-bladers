local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)

-- Ensure NovaBladers modules are present before init (Studio may load scripts in any order).
ReplicatedStorage:WaitForChild("NovaBladers")

HubWorldManager.init()
