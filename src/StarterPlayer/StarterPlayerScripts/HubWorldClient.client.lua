local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local remotes = NovaBladers:WaitForChild("Remotes")

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function bindPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then return end
	local remoteName = prompt:GetAttribute("RemoteName")
	if typeof(remoteName) ~= "string" then return end

	local remote = remotes:FindFirstChild(remoteName)
	if not remote then return end

	prompt.Triggered:Connect(function()
		if remoteName == "EnterArena" then
			local lobby = player.PlayerGui:FindFirstChild("Lobby")
			if lobby then lobby.Enabled = false end
			hideBattleUi()
		elseif remoteName == "OpenBeySelect" then
			local select = player.PlayerGui:FindFirstChild("BeySelect")
			if select then select.Enabled = true end
		end
		remote:FireServer()
	end)
end

local function startArenaGlow(pad)
	local start = os.clock()
	RunService.RenderStepped:Connect(function()
		if not pad.Parent then return end
		local pulse = (math.sin((os.clock() - start) * 2.2) + 1) / 2
		pad.Transparency = 0.15 + pulse * 0.2
	end)
end

local function bindHub(hub)
	local zones = hub:WaitForChild("Zones")
	for _, zone in zones:GetChildren() do
		local pad = zone:FindFirstChild("Pad")
		if pad then
			local prompt = pad:FindFirstChild("ZonePrompt")
			if prompt then
				bindPrompt(prompt)
			end
			if pad:GetAttribute("ZoneId") == "Arena" then
				startArenaGlow(pad)
			end
		end
	end
end

local existingHub = workspace:FindFirstChild("NovaHub")
if existingHub then
	bindHub(existingHub)
else
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "NovaHub" then
			bindHub(child)
		end
	end)
end
