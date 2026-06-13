local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

-- Tracks hub vs arena state for future client features (zone hints, minimap).
Remotes:WaitForChild("HubState").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	player:SetAttribute("NovaInHub", payload.inHub == true)
end)
