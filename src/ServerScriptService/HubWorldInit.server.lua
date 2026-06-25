local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldManager = require(script.Parent.HubWorldManager)

if HubConfig.USE_3D_HUB then
	HubWorldManager.init()
end
