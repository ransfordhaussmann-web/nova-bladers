local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local HubWorldManager = require(script.Parent.HubWorldManager)

local _, prompts = HubWorldBuilder.build()
HubWorldManager.init(prompts)
