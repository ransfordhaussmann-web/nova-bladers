local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BeyCatalog = require(ReplicatedStorage.NovaBladers.BeyCatalog)
local BeyConfig = require(ReplicatedStorage.NovaBladers.BeyConfig)
local ArenaBuilder = require(ReplicatedStorage.NovaBladers.ArenaBuilder)
local BeyController = require(ReplicatedStorage.NovaBladers.BeyController)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes = RemotesSetup.ensure()

local MatchPhase = {
	Idle = "Idle",
	Gathering = "Gathering",
	Selecting = "Selecting",
	Countdown = "Countdown",
	Fighting = "Fighting",
	Ended = "Ended",
}

local state = {
	phase = MatchPhase.Idle,
	players = {},
	selections = {},
	controllers = {},
	arena = nil,
	gatherToken = 0,
	heartbeat = nil,
	matchMode = nil,
}

local function getBeyById(id)
	for _, bey in BeyCatalog do
		if bey.id == id then
			return bey
		end
	end
	return BeyCatalog[1]
end

local function getModeFromCount(count)
	if state.matchMode then
		return state.matchMode
	end
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function hidePlayerCharacter(player)
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = CFrame.new(0, -500, 0)
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
end

local function broadcastStats()
	local stats = {}
	for _, controller in state.controllers do
		table.insert(stats, controller:getState())
	end
	for _, player in state.players do
		if player.Parent then
			Remotes.BeyStatsUpdate:FireClient(player, stats)
		end
	end
end

local function broadcastMatch(phase, extra)
	for _, player in state.players do
		if player.Parent then
			Remotes.MatchState:FireClient(player, {
				phase = phase,
				mode = getModeFromCount(#state.players),
				countdown = extra and extra.countdown,
			})
		end
	end
end

local function playSoundForAll(key)
	local soundId = BeyConfig.SOUNDS[key]
	if not soundId then
		return
	end
	for _, player in state.players do
		if player.Parent then
			Remotes.PlaySound:FireClient(player, soundId)
		end
	end
end

local function cleanupMatch()
	if state.heartbeat then
		state.heartbeat:Disconnect()
		state.heartbeat = nil
	end
	for _, controller in state.controllers do
		controller:destroy()
	end
	state.controllers = {}
	state.selections = {}
	state.players = {}
	state.phase = MatchPhase.Idle
	state.matchMode = nil
	ArenaBuilder.hide()
	MatchmakingService.setMatchInProgress(false)
end

local function endMatch(winners)
	state.phase = MatchPhase.Ended
	local winnerSet = {}
	for _, w in winners do
		winnerSet[w] = true
	end

	for _, player in state.players do
		local won = winnerSet[player] == true
		PlayerDataManager.recordMatch(player, won)
		PlayerDataManager.persist(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		Remotes.MatchResult:FireClient(player, { won = won })
		if won then
			playSoundForAll("VICTORY")
		else
			playSoundForAll("DEFEAT")
		end

		task.delay(3, function()
			if player.Parent then
				HubService.returnPlayerToHub(player)
			end
		end)
	end

	task.delay(4, cleanupMatch)
end

local function checkWinCondition()
	local alive = {}
	for _, controller in state.controllers do
		if controller.alive then
			table.insert(alive, controller)
		end
	end

	if #alive <= 1 and state.phase == MatchPhase.Fighting then
		local winners = {}
		if alive[1] and alive[1].player then
			table.insert(winners, alive[1].player)
		elseif #state.players == 1 then
			table.insert(winners, state.players[1])
		end
		endMatch(winners)
	end
end

local function onControllerEvent(controller, eventType, payload)
	if eventType == "sound" then
		playSoundForAll(payload)
	elseif eventType == "pulse" then
		for _, other in state.controllers do
			if other ~= controller and other.alive then
				local dist = (controller.part.Position - other.part.Position).Magnitude
				if dist <= payload.range then
					other:takeHit(controller, payload.damage, BeyConfig.HIT_SPIN_LOSS, true)
				end
			end
		end
	elseif eventType == "specialAnnounce" then
		for _, player in state.players do
			if player.Parent then
				Remotes.SpecialAnnounce:FireClient(player, payload)
			end
		end
	elseif eventType == "burst" then
		for _, player in state.players do
			if player.Parent then
				Remotes.BurstEvent:FireClient(player, payload)
			end
		end
	end
end

local function startFighting()
	state.phase = MatchPhase.Fighting
	state.arena = ArenaBuilder.build()

	local spawnIdx = 1
	for _, player in state.players do
		hidePlayerCharacter(player)
		local beyId = state.selections[player] or BeyCatalog[1].id
		local beyData = getBeyById(beyId)
		local spawn = state.arena.spawnPoints[spawnIdx] or CFrame.new(state.arena.origin)
		spawnIdx += 1

		local controller = BeyController.new({
			player = player,
			beyData = beyData,
			arenaOrigin = state.arena.origin,
			arenaRadius = state.arena.radius,
			outerRadius = state.arena.outerRadius,
			floorY = state.arena.floorY,
			platformY = state.arena.platformY,
			spawnCFrame = spawn,
			onHit = onControllerEvent,
		})
		table.insert(state.controllers, controller)
	end

	local mode = getModeFromCount(#state.players)
	if mode == "training" then
		local dummyData = getBeyById("IronShell")
		local spawn = state.arena.spawnPoints[spawnIdx] or CFrame.new(state.arena.origin + Vector3.new(8, 0, 0))
		local dummy = BeyController.new({
			player = nil,
			beyData = dummyData,
			arenaOrigin = state.arena.origin,
			arenaRadius = state.arena.radius,
			outerRadius = state.arena.outerRadius,
			floorY = state.arena.floorY,
			platformY = state.arena.platformY,
			spawnCFrame = spawn,
			isDummy = true,
			onHit = onControllerEvent,
		})
		table.insert(state.controllers, dummy)
	end

	broadcastMatch("Fighting")
	broadcastStats()

	local lastSync = 0
	state.heartbeat = RunService.Heartbeat:Connect(function(dt)
		for _, controller in state.controllers do
			controller:update(dt, state.controllers)
		end

		local now = os.clock()
		if now - lastSync >= BeyConfig.STATS_SYNC_INTERVAL then
			lastSync = now
			broadcastStats()
		end

		checkWinCondition()
	end)
end

local function startCountdown()
	state.phase = MatchPhase.Countdown
	for i = BeyConfig.MATCH_COUNTDOWN, 1, -1 do
		broadcastMatch("Countdown", { countdown = i })
		task.wait(1)
	end
	startFighting()
end

local function startSelection()
	state.phase = MatchPhase.Selecting
	state.selections = {}

	for _, player in state.players do
		Remotes.BeySelectStart:FireClient(player, {
			catalog = BeyCatalog,
			timeout = BeyConfig.SELECTION_TIMEOUT,
		})
	end

	task.delay(BeyConfig.SELECTION_TIMEOUT, function()
		if state.phase ~= MatchPhase.Selecting then
			return
		end
		for _, player in state.players do
			if not state.selections[player] then
				state.selections[player] = BeyCatalog[1].id
			end
		end
		startCountdown()
	end)
end

local function beginMatch(playerList, modeId)
	state.players = playerList
	state.matchMode = modeId
	state.phase = MatchPhase.Selecting
	for _, player in playerList do
		HubService.setPhaseArena(player)
	end
	broadcastMatch("Selecting")
	startSelection()
end

MatchmakingService.setMatchReadyCallback(function(players, modeId)
	if state.phase ~= MatchPhase.Idle then
		for _, player in players do
			if player.Parent then
				MatchmakingService.joinQueue(player, modeId)
			end
		end
		return
	end

	MatchmakingService.setMatchInProgress(true)
	beginMatch(players, modeId)
end)

Remotes.BeySelectPick.OnServerEvent:Connect(function(player, beyId)
	if state.phase ~= MatchPhase.Selecting then
		return
	end
	if typeof(beyId) ~= "string" then
		return
	end
	state.selections[player] = beyId
	playSoundForAll("SELECT")

	local allSelected = true
	for _, p in state.players do
		if not state.selections[p] then
			allSelected = false
			break
		end
	end
	if allSelected then
		startCountdown()
	end
end)

Remotes.BeyInput.OnServerEvent:Connect(function(player, input)
	if state.phase ~= MatchPhase.Fighting then
		return
	end
	if typeof(input) ~= "table" then
		return
	end

	for _, controller in state.controllers do
		if controller.player == player and controller.alive then
			local moveDir = Vector3.new(input.x or 0, 0, input.z or 0)
			local wantsSpecial = controller:setInput({
				moveDir = moveDir,
				charging = input.charging,
				dodge = input.dodge,
				jump = input.jump,
				spinRecover = input.spinRecover,
				special = input.special,
			})

			if wantsSpecial then
				local target
				for _, other in state.controllers do
					if other ~= controller and other.alive and not other.isDummy then
						target = other
						break
					end
				end
				if not target then
					for _, other in state.controllers do
						if other ~= controller and other.alive then
							target = other
							break
						end
					end
				end
				controller:activateSpecial(target)
			end
			break
		end
	end
end)

print("[GameManager] Match system ready (matchmaking queue)")
