local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")

local function ensureRemote(folder, name, className)
	className = className or "RemoteEvent"
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

local remotesFolder = NovaBladers:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = NovaBladers
end

ensureRemote(remotesFolder, "LobbyReady")
ensureRemote(remotesFolder, "EnterArena")
ensureRemote(remotesFolder, "OpenBeySelect")
ensureRemote(remotesFolder, "HubBoardUpdate")

local HubWorldManager = require(script.Parent.HubWorldManager)
HubWorldManager.init()
