local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

HubWorldManager.init(Remotes)
