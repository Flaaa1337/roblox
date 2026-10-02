--!nocheck
-- Plays through SCRAPFALL: deploy, shoot, loot, kill robots, extract,
-- trade, craft, quarters, decorate, die. Run via tools/harness.luau.

local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:FindFirstChild("Remotes")
local SSS = game:GetService("ServerScriptService")
local server = SSS:FindFirstChild("Server")
local function mod(name)
	return requireModule(server:FindFirstChild(name))
end
local function step(label, fn)
	local ok, err = pcall(fn)
	if ok then
		print("✅ " .. label)
	else
		fail(label .. ": " .. tostring(err))
	end
end
local function act(name, arg)
	Remotes.Action:FireServer(name, arg)
	task.wait(0.15)
end

local world = workspace:FindFirstChild("ScrapfallWorld")
if not world then
	fail("world was not built")
	return
end
local Data, Raid, Robots, Loot, Inventory = mod("DataService"), mod("RaidService"), mod("RobotService"), mod("LootService"), mod("InventoryService")
local root = player.Character.HumanoidRootPart

step("profile loaded", function()
	assert(Data.Get(player), "no profile")
end)

-- Client menus in the Outpost
for _, panel in { "Trader", "Stash", "Workbench", "Upgrades", "MapSelect", "QuartersBuy" } do
	step("open panel " .. panel, function()
		Remotes.OpenPanel:FireClient(player, panel)
		task.wait(0.1)
	end)
end

step("deploy to Rustfield", function()
	act("Deploy", "Rustfield")
	task.wait(0.3)
	assert(player:GetAttribute("InRaid") == true, "not in raid after deploy")
	assert(Inventory.Get(player), "no raid inventory")
end)

step("shoot, reload, heal, swap", function()
	local head = player.Character.Head
	for _ = 1, 3 do
		Remotes.Fire:FireServer(head.Position, Vector3.new(0, 0, -1))
		task.wait(0.3)
	end
	act("Reload")
	act("UseItem", 1)
	act("Equip", 2)
	act("Equip", 1)
	task.wait(0.5)
end)

step("open bag", function()
	Remotes.OpenPanel:FireClient(player, "Inventory")
	task.wait(0.1)
end)

step("spawn and kill every robot type", function()
	for _, name in { "Crawler", "Buzzer", "Watcher", "Sentinel", "Colossus" } do
		local robot = Robots.Spawn(name, "Rustfield", root.Position + Vector3.new(20, 0, 0))
		assert(robot, "could not spawn " .. name)
		Robots.Damage(robot, 10, player, false)
		Robots.Damage(robot, 1e6, player, true)
	end
end)

step("robot AI runs with a raider nearby", function()
	for _, name in { "Crawler", "Buzzer", "Watcher", "Sentinel" } do
		Robots.Spawn(name, "Rustfield", root.Position + Vector3.new(30, 0, 30))
	end
	task.wait(3)
end)

step("search a container and take everything", function()
	local containers = world:FindFirstChild("Map_Rustfield"):FindFirstChild("Containers")
	local box = containers:GetChildren()[1]
	root.CFrame = box.CFrame
	box:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player)
	task.wait(0.3)
	-- container ids start at 1
	act("Take", { id = 1, index = 0 })
end)

step("bag actions (safe pocket, drop)", function()
	act("ToSafe", 1)
	act("FromSafe", 1)
	act("DropItem", 1)
end)

step("extract", function()
	Raid.Extract(player)
	task.wait(0.3)
	assert(player:GetAttribute("InRaid") == false, "still in raid after extract")
end)

local data = Data.Get(player)
step("trader, stash, upgrades", function()
	Data.AddCredits(player, 50000)
	act("Buy", 1)
	act("Buy", 6)
	act("ToLoadout", 1)
	act("ToStash", { kind = "item", index = 1 })
	act("Sell", 1)
	act("SellSalvage")
	act("Upgrade", "Backpack")
	act("Upgrade", "Stash")
end)

step("craft at the Outpost workbench", function()
	table.insert(data.stash, { id = "ScrapMetal", count = 20 })
	table.insert(data.stash, { id = "Wires", count = 10 })
	for _, d in world:FindFirstChild("Outpost"):GetDescendants() do
		if d:IsA("ProximityPrompt") and d:GetAttribute("Panel") == "Workbench" then
			root.CFrame = d.Parent.CFrame
			d.Triggered:Fire(player)
		end
	end
	task.wait(0.2)
	act("Craft", 1)
	act("Craft", 3)
end)

step("private quarters: buy, decorate, upgrade bench", function()
	act("BuyQuarters")
	task.wait(0.3)
	assert(data.quarters.owned, "quarters not owned")
	table.insert(data.stash, { id = "RobotCore", count = 3 })
	table.insert(data.stash, { id = "Servo", count = 4 })
	table.insert(data.stash, { id = "CircuitBoard", count = 6 })
	table.insert(data.stash, { id = "OpticLens", count = 3 })
	act("BuyDecor", "Couch")
	act("BuyDecor", "CoreDisplay")
	act("PlaceDecor", { slot = 2, id = "Couch" })
	act("UpgradeBench")
	act("UpgradeBench")
	assert(data.quarters.benchTier == 3, "bench tier is " .. data.quarters.benchTier)
	Remotes.OpenPanel:FireClient(player, "Decorate")
	task.wait(0.1)
	Remotes.OpenPanel:FireClient(player, "Workbench")
	task.wait(0.1)
	act("ExitQuarters")
end)

step("deploy to Quarry and die", function()
	act("Deploy", "Quarry")
	task.wait(0.3)
	assert(player:GetAttribute("InRaid") == true, "not in raid")
	player.Character.Humanoid:TakeDamage(1000)
	task.wait(0.5)
	assert(player:GetAttribute("InRaid") == false, "still in raid after dying")
end)

step("free kit when broke", function()
	data.loadout = { weapons = { "", "" }, items = {} }
	makeCharacter()
	player.CharacterAdded:Fire(player.Character)
	task.wait(0.3)
	act("Deploy", "Rustfield")
	task.wait(0.3)
	assert(Inventory.Get(player).weapons[1], "no free weapon")
end)

step("player leaves mid-raid", function()
	game:GetService("Players").PlayerRemoving:Fire(player)
	task.wait(0.5)
end)
