local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local hubModel = workspace:WaitForChild("NovaBladersHub")
local zonesFolder = hubModel:WaitForChild("Zones")

local activeHighlight
local activeTween

local function getZonePad(zoneId)
	local zoneFolder = zonesFolder:FindFirstChild(zoneId)
	return zoneFolder and zoneFolder:FindFirstChild("ZonePad")
end

local function resetZonePads()
	for _, zoneFolder in zonesFolder:GetChildren() do
		local pad = zoneFolder:FindFirstChild("ZonePad")
		if pad then
			pad.Transparency = 0.55
			pad.Material = Enum.Material.Neon
		end
	end
end

local function highlightZone(payload)
	resetZonePads()

	local pad = getZonePad(payload.zoneId)
	if not pad then
		return
	end

	if activeTween then
		activeTween:Cancel()
	end

	pad.Transparency = 0.2
	pad.Material = Enum.Material.Neon
	activeHighlight = payload.zoneId

	activeTween = TweenService:Create(pad, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.45,
	})
	activeTween:Play()

	local gui = player:FindFirstChild("PlayerGui")
	local lobby = gui and gui:FindFirstChild("Lobby")
	local panel = lobby and lobby:FindFirstChild("Panel")
	local modeLabel = panel and panel:FindFirstChild("ModeLabel")
	if modeLabel then
		modeLabel.Text = payload.modeLabel or modeLabel.Text
	end
end

Remotes.HubZoneHighlight.OnClientEvent:Connect(highlightZone)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.zoneId then
		highlightZone({
			zoneId = payload.zoneId,
			modeLabel = payload.modeLabel,
		})
	end
end)
