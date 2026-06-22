local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

ReplicatedStorage:WaitForChild("NovaBladers")

local HubWorldManager = require(ServerScriptService.HubWorldManager)
HubWorldManager.init()
