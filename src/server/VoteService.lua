-- "Who goes overboard?" votes. Started automatically when the balloon gets
-- low, or by anyone with the vote horn. Bots are candidates and voters too,
-- so this works even with a single real player.

local Players = game:GetService("Players")

local VoteService = {}
local S, Config

local active = nil
local lastVoteAt = -math.huge

local function candidateId(c): number
	return if typeof(c) == "Instance" then c.UserId else c.id
end

local function buildCandidates()
	local list, byId = {}, {}
	for _, player in S.Flight.GetAboard() do
		local ps = S.Flight.GetPlayerState(player)
		byId[player.UserId] = player
		table.insert(list, { id = player.UserId, name = player.DisplayName, weight = ps.weight, bot = false })
	end
	for _, bot in S.Bots.GetAboard() do
		byId[bot.id] = bot
		table.insert(list, { id = bot.id, name = bot.name, weight = bot.weight, bot = true })
	end
	table.sort(list, function(a, b)
		return a.weight > b.weight
	end)
	return list, byId
end

local function tally()
	local counts = {}
	for _, target in active.ballots do
		counts[target] = (counts[target] or 0) + 1
	end
	return counts
end

local function broadcastTally()
	local counts = tally()
	local payload = {}
	for id, n in counts do
		payload[tostring(id)] = n
	end
	S.Remotes.Vote:FireAllClients("Tally", payload)
end

local function finish(vote)
	if active ~= vote then
		return
	end
	active = nil
	local counts = {}
	for _, target in vote.ballots do
		counts[target] = (counts[target] or 0) + 1
	end
	local bestId, bestCount, tie = nil, 0, false
	for id, n in counts do
		if n > bestCount then
			bestId, bestCount, tie = id, n, false
		elseif n == bestCount then
			tie = true
		end
	end

	local target = bestId and vote.byId[bestId]
	if not target or tie or bestCount < Config.MinVotesToThrow or not S.Flight.IsActive() then
		S.Remotes.Vote:FireAllClients("End", { name = nil })
		S.Notify(nil, "🤝 The crew couldn't agree. Nobody goes overboard... for now.", "White")
		return
	end

	local name = if typeof(target) == "Instance" then target.DisplayName else target.name
	S.Remotes.Vote:FireAllClients("End", { name = name, votes = bestCount })
	S.Notify(nil, string.format("🗳️ The crew has spoken: %s goes OVERBOARD! (%d votes)", name, bestCount), "Red", true)

	local center = S.World.balloon.top
	if typeof(target) == "Instance" then
		if not S.Flight.IsAboard(target) then
			return
		end
		local root = S.Flight.GetRoot(target)
		local out = if root then (root.Position - center) * Vector3.new(1, 0, 1) else Vector3.new(1, 0, 0)
		out = if out.Magnitude > 0.1 then out.Unit else Vector3.new(1, 0, 0)
		S.Flight.SetFallReason(target, "(voted off by the crew)", 6)
		S.Flight.Fling(target, out * 110 + Vector3.new(0, 70, 0))
		task.delay(2.5, function()
			if S.Flight.IsAboard(target) then
				S.Flight.Overboard(target, "(voted off by the crew)")
			end
		end)
		S.Analytics.Custom(target, "VotedOff")
	else
		S.Bots.Throw(target, "(voted off by the crew)")
	end
end

local function start(reason: string)
	if active or not S.Flight.IsActive() then
		return false
	end
	local list, byId = buildCandidates()
	if #list < Config.MinPlayersForVote then
		return false
	end
	lastVoteAt = os.clock()
	local vote = {
		ballots = {}, -- [voterKey] = candidateId
		byId = byId,
		endsAt = workspace:GetServerTimeNow() + Config.VoteDuration,
	}
	active = vote
	S.Remotes.Vote:FireAllClients("Start", {
		reason = reason,
		candidates = list,
		endsAt = vote.endsAt,
	})
	S.Bots.OnVoteStarted(list)
	task.delay(Config.VoteDuration, finish, vote)
	return true
end

function VoteService.Call(player: Player)
	if not S.Flight.IsAboard(player) or S.Flight.GetState().state ~= "Flying" then
		return
	end
	if active then
		return
	end
	local wait = Config.VoteCooldown - (os.clock() - lastVoteAt)
	if wait > 0 then
		S.Notify(player, string.format("📯 The vote horn is recharging (%ds)", math.ceil(wait)), "Gray")
		return
	end
	if not start("📯 " .. player.DisplayName .. " blew the vote horn!") then
		S.Notify(player, "Not enough passengers to vote.", "Gray")
	end
end

function VoteService.BotCall(bot)
	if active or S.Flight.GetState().state ~= "Flying" or os.clock() - lastVoteAt < Config.VoteCooldown then
		return false
	end
	return start("📯 " .. bot.name .. " panicked and blew the vote horn!")
end

-- voterKey is a Player or a bot table; targetId is a UserId or bot id.
function VoteService.Cast(voter, targetId)
	if not active or type(targetId) ~= "number" or not active.byId[targetId] then
		return
	end
	if typeof(voter) == "Instance" then
		if not S.Flight.IsAboard(voter) then
			return
		end
	end
	active.ballots[voter] = targetId
	broadcastTally()
end

function VoteService.IsActive(): boolean
	return active ~= nil
end

function VoteService.Step(altitude: number)
	if not active and altitude < Config.AutoVoteAltitude and os.clock() - lastVoteAt >= Config.VoteCooldown then
		start("⚠️ ALTITUDE CRITICAL! Vote someone overboard!")
	end
end

function VoteService.Cancel()
	if active then
		active = nil
		S.Remotes.Vote:FireAllClients("End", { name = nil, cancelled = true })
	end
	lastVoteAt = -math.huge
end

function VoteService.Init(services)
	S = services
	Config = S.Config
end

function VoteService.Start()
	Players.PlayerRemoving:Connect(function(player)
		if active then
			active.ballots[player] = nil
		end
	end)
end

VoteService.CandidateId = candidateId

return VoteService
