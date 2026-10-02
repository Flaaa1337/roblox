-- Bot passengers. A game that is only fun with 8 people dies before it gets
-- 8 people, so bots fill the basket while the player count is low. Each bot
-- has a personality that creates the same drama real players would.

local Players = game:GetService("Players")

local BotService = {}
local S, Config

local rng = Random.new()
local bots = {} -- list of bot tables
local nextId = 0
local folder

local WALK_ANIM = "rbxassetid://507777826"
local IDLE_ANIM = "rbxassetid://507766388"

local PERSONALITIES = {
	{
		name = "Greedy Gary", greed = 1.0, caution = 0.0, panic = 0.2,
		colors = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(60, 140, 60) },
		lines = {
			grab = { "MINE!", "Ooh shiny!", "I'm gonna be RICH!", "Hands off, that's mine!" },
			vote = { "Not me, I'm the fun one!", "Throw the skinny one!" },
			thrown = { "MY TREASURE NOOO!", "You'll regret this!!" },
		},
	},
	{
		name = "Captain Panic", greed = 0.5, caution = 0.6, panic = 1.0,
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(30, 50, 110) },
		lines = {
			grab = { "Is this heavy? IS THIS HEAVY?", "Fine, ONE item." },
			vote = { "WE'RE ALL GONNA SINK!", "Someone has to go!!" },
			thrown = { "I KNEW IT! I KNEW IT!", "Tell my parrot I love him!" },
		},
	},
	{
		name = "Careful Carla", greed = 0.3, caution = 1.0, panic = 0.1,
		colors = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(240, 240, 240) },
		lines = {
			grab = { "Light stuff only.", "Safety first!" },
			vote = { "Whoever is heaviest. It's just math.", "Check the weights, people." },
			thrown = { "This is statistically unfair!", "Worth it for the team..." },
		},
	},
	{
		name = "Lucky Lou", greed = 0.7, caution = 0.4, panic = 0.3,
		colors = { Color3.fromRGB(90, 220, 110), Color3.fromRGB(255, 255, 255) },
		lines = {
			grab = { "Feeling lucky!", "Today's my day!", "Jackpot?!" },
			vote = { "Eeny, meeny, miny...", "Luck decides!" },
			thrown = { "Guess my luck ran out!", "Wheee-- wait no" },
		},
	},
	{
		name = "Sneaky Sam", greed = 0.8, caution = 0.3, panic = 0.4,
		colors = { Color3.fromRGB(60, 60, 70), Color3.fromRGB(150, 60, 200) },
		lines = {
			grab = { "Nobody saw that.", "Heh heh heh.", "Yoink." },
			vote = { "I have a list.", "It's personal now." },
			thrown = { "I'll remember your faces!", "Betrayed!" },
		},
	},
}

local function say(bot, kind: string)
	local lines = bot.personality.lines[kind]
	local tag = bot.tag
	if not lines or not tag or not tag.Parent then
		return
	end
	local text = lines[rng:NextInteger(1, #lines)]
	tag.Speech.Text = text
	tag.Speech.Visible = true
	local token = {}
	bot.speechToken = token
	task.delay(3, function()
		if bot.speechToken == token and tag.Parent then
			tag.Speech.Visible = false
		end
	end)
end

local function updateTag(bot)
	if bot.tag and bot.tag.Parent then
		bot.tag.Weight.Text = string.format("🎒 %d kg", bot.weight)
	end
end

local function root(bot)
	return bot.model and bot.model:FindFirstChild("HumanoidRootPart")
end

local function createModel(bot)
	local desc = Instance.new("HumanoidDescription")
	local skin, shirt = bot.personality.colors[1], bot.personality.colors[2]
	desc.HeadColor = Color3.fromRGB(255, 205, 160)
	desc.LeftArmColor = desc.HeadColor
	desc.RightArmColor = desc.HeadColor
	desc.TorsoColor = shirt
	desc.LeftLegColor = skin
	desc.RightLegColor = skin
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Bots] could not create bot model:", model)
		return nil
	end
	model.Name = bot.name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 10

	local head = model:FindFirstChild("Head")
	local tag = Instance.new("BillboardGui")
	tag.Name = "WeightTag"
	tag.Size = UDim2.fromOffset(170, 80)
	tag.StudsOffset = Vector3.new(0, 3.4, 0)
	tag.MaxDistance = 120
	tag.Parent = head
	local speech = Instance.new("TextLabel")
	speech.Name = "Speech"
	speech.Size = UDim2.fromScale(1, 0.38)
	speech.BackgroundColor3 = Color3.new(1, 1, 1)
	speech.TextColor3 = Color3.new(0, 0, 0)
	speech.TextScaled = true
	speech.Font = Enum.Font.GothamBold
	speech.Visible = false
	speech.Parent = tag
	Instance.new("UICorner").Parent = speech
	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromScale(0, 0.4)
	name.Size = UDim2.fromScale(1, 0.3)
	name.BackgroundTransparency = 1
	name.Text = "🤖 " .. bot.name
	name.TextColor3 = Color3.fromRGB(190, 220, 255)
	name.TextScaled = true
	name.Font = Enum.Font.GothamBold
	name.TextStrokeTransparency = 0.3
	name.Parent = tag
	local weight = Instance.new("TextLabel")
	weight.Name = "Weight"
	weight.Position = UDim2.fromScale(0, 0.7)
	weight.Size = UDim2.fromScale(1, 0.3)
	weight.BackgroundTransparency = 1
	weight.TextColor3 = Color3.new(1, 1, 1)
	weight.TextScaled = true
	weight.Font = Enum.Font.GothamBold
	weight.TextStrokeTransparency = 0.3
	weight.Parent = tag
	bot.tag = tag

	model:PivotTo(S.Flight.BasketSpot())
	model.Parent = folder
	local hrp = model:FindFirstChild("HumanoidRootPart")
	pcall(function()
		hrp:SetNetworkOwner(nil)
	end)

	-- Simple walk/idle animation so bots don't slide around stiffly.
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local function load(id)
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok2, track = pcall(animator.LoadAnimation, animator, anim)
		return ok2 and track or nil
	end
	local walk, idle = load(WALK_ANIM), load(IDLE_ANIM)
	if idle then
		idle.Looped = true
		idle:Play()
	end
	humanoid.Running:Connect(function(speed)
		if walk then
			if speed > 0.5 and not walk.IsPlaying then
				walk.Looped = true
				walk:Play()
			elseif speed <= 0.5 and walk.IsPlaying then
				walk:Stop()
			end
		end
	end)

	updateTag(bot)
	return model
end

local function removeBot(bot)
	local index = table.find(bots, bot)
	if index then
		table.remove(bots, index)
	end
	bot.removed = true
	if bot.model then
		bot.model:Destroy()
	end
end

local function spawnBot()
	local used = {}
	for _, b in bots do
		used[b.personality.name] = true
	end
	local options = {}
	for _, p in PERSONALITIES do
		if not used[p.name] then
			table.insert(options, p)
		end
	end
	if #options == 0 then
		return
	end
	nextId += 1
	local personality = options[rng:NextInteger(1, #options)]
	local bot = {
		id = -nextId,
		name = personality.name,
		personality = personality,
		weight = 0,
		cap = math.floor(8 + personality.greed * 18),
		nextThink = os.clock() + rng:NextNumber(1, 3),
		thrown = false,
	}
	bot.model = createModel(bot)
	if bot.model then
		table.insert(bots, bot)
	end
end

function BotService.GetAboard()
	local list = {}
	for _, bot in bots do
		if not bot.thrown then
			table.insert(list, bot)
		end
	end
	return list
end

function BotService.TryCarry(bot, def)
	if bot.thrown or bot.weight + def.weight > bot.cap then
		return false, "full"
	end
	bot.weight += def.weight
	updateTag(bot)
	return true
end

function BotService.Fling(bot, velocity: Vector3, reason: string?)
	local hrp = root(bot)
	if not hrp then
		return
	end
	bot.fallReason = reason
	local humanoid = bot.model:FindFirstChildOfClass("Humanoid")
	humanoid.PlatformStand = true
	hrp.AssemblyLinearVelocity = velocity
	task.delay(1, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end

local function overboard(bot, reason: string?)
	if bot.thrown then
		return
	end
	bot.thrown = true
	S.Notify(nil, string.format("🌊 🤖 %s went OVERBOARD! %s", bot.name, reason or bot.fallReason or ""), "Red")
	task.delay(3, removeBot, bot)
end

function BotService.Throw(bot, reason: string)
	if bot.thrown then
		return
	end
	say(bot, "thrown")
	local hrp = root(bot)
	local center = S.World.balloon.top
	local out = if hrp then (hrp.Position - center) * Vector3.new(1, 0, 1) else Vector3.new(1, 0, 0)
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.new(1, 0, 0)
	BotService.Fling(bot, out * 110 + Vector3.new(0, 70, 0), reason)
	task.delay(2.5, overboard, bot, reason)
end

-- Bring the crew up (or down) to BotCrewSize passengers.
function BotService.Refresh()
	if not Config.BotsEnabled or not S.Flight.IsActive() then
		return
	end
	local real = #S.Flight.GetAboard()
	local wanted = math.max(0, Config.BotCrewSize - real)
	local aboard = BotService.GetAboard()
	if #aboard < wanted then
		for _ = 1, wanted - #aboard do
			spawnBot()
		end
	elseif #aboard > wanted and not S.Vote.IsActive() then
		table.sort(aboard, function(a, b)
			return a.weight < b.weight
		end)
		for i = 1, #aboard - wanted do
			S.Notify(nil, "🤖 " .. aboard[i].name .. " hopped off to make room for a new passenger!", "Gray")
			removeBot(aboard[i])
		end
	end
end

function BotService.OnDock()
	for _, bot in BotService.GetAboard() do
		if bot.weight > 0 then
			bot.weight = 0
			updateTag(bot)
		end
	end
	-- New bots board at Sky Ports to replace the ones voted off.
	BotService.Refresh()
end

function BotService.OnVoteStarted(candidates)
	for _, bot in BotService.GetAboard() do
		task.delay(rng:NextNumber(2, Config.VoteDuration - 2), function()
			if bot.thrown or not S.Vote.IsActive() then
				return
			end
			-- Mostly vote for the heaviest passenger who isn't me.
			local pick
			for _, c in candidates do
				if c.id ~= bot.id then
					if not pick or (c.weight > pick.weight and rng:NextNumber() < 0.8) then
						pick = c
					end
				end
			end
			if bot.personality.name == "Lucky Lou" and rng:NextNumber() < 0.5 then
				pick = candidates[rng:NextInteger(1, #candidates)]
				if pick.id == bot.id then
					return
				end
			end
			if pick then
				say(bot, "vote")
				S.Vote.Cast(bot, pick.id)
			end
		end)
	end
end

local function think(bot, flight)
	local hrp = root(bot)
	local humanoid = bot.model and bot.model:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		return
	end
	local p = bot.personality
	local altitude = flight.altitude

	-- Panic: blow the vote horn when it gets low.
	if p.panic > 0.8 and altitude < 45 and rng:NextNumber() < 0.3 then
		S.Vote.BotCall(bot)
	end

	-- Careful bots run to the burner when things get dicey.
	if altitude < 55 and flight.fuel > 0 and rng:NextNumber() < p.caution * 0.6 then
		humanoid:MoveTo(S.World.balloon.top + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)))
		S.Flight.PumpBurner()
		return
	end

	-- Cautious bots toss weight when the balloon is sinking.
	if altitude < 35 and bot.weight > 0 and rng:NextNumber() < p.caution then
		bot.weight = math.max(0, bot.weight - rng:NextInteger(2, 6))
		updateTag(bot)
		return
	end

	-- Grab loot. Bots are a bit slower than players on purpose.
	local willing = altitude > 40 or rng:NextNumber() < p.greed
	if willing and rng:NextNumber() < 0.45 then
		local nearby = S.Loot.FindNear(hrp.Position, Config.BotHookRange)
		if #nearby > 0 then
			local info = nearby[rng:NextInteger(1, #nearby)]
			local ok = S.Loot.Grab(info, bot)
			if ok then
				S.Loot.PullTo(info, hrp.Position)
				if rng:NextNumber() < 0.5 then
					say(bot, "grab")
				end
				return
			end
		end
	end

	-- Wander around the basket.
	if rng:NextNumber() < 0.5 then
		humanoid:MoveTo(S.Flight.BasketSpot().Position)
	end
end

function BotService.Step(dt: number, flight)
	local clock = os.clock()
	local floorY = S.World.balloon.top.Y
	for _, bot in table.clone(bots) do
		local hrp = root(bot)
		if not bot.thrown then
			if not hrp or hrp.Position.Y < floorY - 25 then
				overboard(bot)
			elseif flight.state == "Flying" and clock >= bot.nextThink then
				bot.nextThink = clock + rng:NextNumber(1.2, 2.6)
				think(bot, flight)
			end
		end
	end
end

function BotService.Clear()
	for _, bot in table.clone(bots) do
		removeBot(bot)
	end
end

function BotService.Init(services)
	S = services
	Config = S.Config
end

function BotService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = workspace
end

return BotService
