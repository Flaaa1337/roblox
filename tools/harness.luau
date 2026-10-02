--!nocheck
-- Smoke-test harness: runs the game's server (and client UI) scripts outside
-- Roblox Studio using Lune, with a small mock of the Roblox engine.
-- It catches startup crashes, invalid property names and nil errors.
-- Usage: lune run tools/harness.luau <projectDir>

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")
local process = require("@lune/process")

local I = roblox.Instance
local wrap, unwrap -- proxy membrane, defined below
local projectDir = process.args[1] or "scrapfall"
local failures = 0

---------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------
local function newSignal()
	local sig = { handlers = {} }
	function sig:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end, Connected = true }
	end
	sig.Once = sig.Connect
	function sig:Wait()
		local thread = coroutine.running()
		table.insert(self.handlers, function(...)
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end
	function sig:Fire(...)
		local packed = table.pack(...)
		for i = 1, packed.n do
			packed[i] = wrap(packed[i])
		end
		for _, fn in table.clone(self.handlers) do
			task.spawn(function(...)
				local ok, err = pcall(fn, ...)
				if not ok then
					failures += 1
					print("❌ handler error: " .. tostring(err))
				end
			end, table.unpack(packed, 1, packed.n))
		end
	end
	return sig
end

-- Lune hands out a fresh userdata wrapper on every access, so instances
-- can't be table keys. Give each one a stable id stored as an attribute.
local nextHid = 0
local function idOf(inst)
	local id = inst:GetAttribute("__hid")
	if not id then
		nextHid += 1
		id = nextHid
		inst:SetAttribute("__hid", id)
	end
	return id
end

local signals = {}
local function signalOf(inst, name)
	local key = idOf(unwrap(inst)) .. ":" .. name
	signals[key] = signals[key] or newSignal()
	return signals[key]
end

local EVENTS = {
	Instance = { "AncestryChanged", "ChildAdded", "Destroying" },
	Players = { "PlayerAdded", "PlayerRemoving" },
	Player = { "CharacterAdded", "CharacterRemoving" },
	RunService = { "Heartbeat", "RenderStepped", "Stepped" },
	ProximityPrompt = { "Triggered", "PromptButtonHoldBegan", "PromptButtonHoldEnded" },
	BasePart = { "Touched", "TouchEnded" },
	Humanoid = { "Died", "Running", "StateChanged" },
	BindableEvent = { "Event" },
	RemoteEvent = { "OnServerEvent", "OnClientEvent" },
	UnreliableRemoteEvent = { "OnServerEvent", "OnClientEvent" },
	MarketplaceService = { "PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished" },
	GuiButton = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseLeave", "MouseEnter" },
	UserInputService = { "InputBegan", "InputEnded", "InputChanged" },
	ClickDetector = { "MouseClick" },
	Tween = { "Completed" },
}
for className, names in EVENTS do
	for _, name in names do
		roblox.implementProperty(className, name, function(inst)
			return signalOf(inst, name)
		end)
	end
end

---------------------------------------------------------------------------
-- Proxy membrane: Lune can't provide engine-computed properties (Position,
-- Health, ...), so game code sees every Instance through a proxy that fills
-- those in. Raw Lune instances never leak into game code.
---------------------------------------------------------------------------
local DEFAULTS = {
	Health = 100, MaxHealth = 100, WalkSpeed = 16, HipHeight = 2, Jump = false, PlatformStand = false,
	AutoRotate = true, CameraOffset = roblox.Vector3.zero, AssemblyLinearVelocity = roblox.Vector3.zero,
	TouchEnabled = false, KeyboardEnabled = true, MouseIconEnabled = true,
	MouseBehavior = roblox.Enum.MouseBehavior.Default, ViewportSize = roblox.Vector2.new(1280, 720),
	IsPlaying = false, Looped = false, Status = roblox.Enum.PathStatus.NoPath,
	UserId = 1, DisplayName = "Tester", CameraMinZoomDistance = 0.5, CameraMaxZoomDistance = 128,
	Character = false, LocalPlayer = false, CurrentCamera = false, PrimaryPart = false,
}

local proxies = {} -- [hid] = proxy
local rawOf = setmetatable({}, { __mode = "k" }) -- [proxy] = raw
local ProxyMT = {}
local callbacks = {}

local function isRaw(v)
	return typeof(v) == "Instance" and rawOf[v] == nil
end

wrap = function(v)
	if isRaw(v) then
		local id = idOf(v)
		local p = proxies[id]
		if not p then
			p = setmetatable({}, ProxyMT)
			rawOf[p] = v
			proxies[id] = p
		end
		return p
	end
	return v
end

unwrap = function(v)
	if type(v) == "table" and rawOf[v] then
		return rawOf[v]
	end
	return v
end

local function wrapResult(v)
	if type(v) == "table" and getmetatable(v) == nil and #v > 0 and isRaw(v[1]) then
		local out = {}
		for i, x in v do
			out[i] = wrap(x)
		end
		return out
	end
	return wrap(v)
end

local function wrapAll(n, ...)
	local t = table.pack(...)
	for i = 1, t.n do
		t[i] = wrapResult(t[i])
	end
	return table.unpack(t, 1, t.n)
end

local function stripIds(inst)
	inst:SetAttribute("__hid", nil)
	for _, d in inst:GetDescendants() do
		d:SetAttribute("__hid", nil)
	end
end

ProxyMT.__index = function(p, key)
	local real = rawOf[p]
	if key == "Position" and real:IsA("BasePart") then
		return real.CFrame.Position
	end
	local ok, value = pcall(function()
		return real[key]
	end)
	if not ok then
		local d = DEFAULTS[key]
		if d ~= nil then
			if d == false and (key == "Character" or key == "LocalPlayer" or key == "CurrentCamera" or key == "PrimaryPart") then
				return nil
			end
			return d
		end
		error(value, 2)
	end
	if type(value) == "function" then
		return function(self, ...)
			local args = table.pack(...)
			for i = 1, args.n do
				args[i] = unwrap(args[i])
			end
			if key == "Clone" then
				local clone = value(real)
				stripIds(clone)
				return wrap(clone)
			end
			return wrapAll(0, value(unwrap(self), table.unpack(args, 1, args.n)))
		end
	end
	return wrapResult(value)
end

ProxyMT.__newindex = function(p, key, value)
	local real = rawOf[p]
	if key == "Position" and real:IsA("BasePart") then
		real.CFrame = real.CFrame - real.CFrame.Position + value
		return
	end
	if key == "ProcessReceipt" or key == "OnServerInvoke" or key == "OnClientInvoke" or key == "OnInvoke" then
		callbacks[idOf(real) .. ":" .. key] = value -- engine callbacks
		return
	end
	real[key] = unwrap(value)
end

ProxyMT.__tostring = function(p)
	return tostring(rawOf[p])
end

---------------------------------------------------------------------------
-- Methods
---------------------------------------------------------------------------
local function m(className, name, fn)
	roblox.implementMethod(className, name, function(self, ...)
		local args = table.pack(...)
		for i = 1, args.n do
			args[i] = wrap(args[i])
		end
		return fn(wrap(self), table.unpack(args, 1, args.n))
	end)
end
m("Instance", "WaitForChild", function(self, name, timeout)
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		local c = self:FindFirstChild(name)
		if c then
			return c
		end
		task.wait(0.05)
	end
	if not timeout then
		failures += 1
		print("❌ WaitForChild timed out: " .. self:GetFullName() .. "." .. name)
	end
	return nil
end)
m("Instance", "GetPropertyChangedSignal", function(self, name) return signalOf(self, "prop_" .. name) end)
m("Instance", "GetAttributeChangedSignal", function(self, name) return signalOf(self, "attr_" .. name) end)
local pivots = {}
m("PVInstance", "PivotTo", function(self, cf)
	if self:IsA("BasePart") then
		self.CFrame = cf
	else
		pivots[idOf(self)] = cf
		local primary = self.PrimaryPart or self:FindFirstChild("HumanoidRootPart")
		if primary then
			primary.CFrame = cf
		end
	end
end)
m("PVInstance", "GetPivot", function(self)
	if self:IsA("BasePart") then
		return self.CFrame
	end
	local primary = self.PrimaryPart or self:FindFirstChild("HumanoidRootPart")
	return if primary then primary.CFrame else (pivots[idOf(self)] or roblox.CFrame.new())
end)
m("BasePart", "SetNetworkOwner", function() end)
m("Humanoid", "SetStateEnabled", function() end)
m("Humanoid", "MoveTo", function() end)
m("Humanoid", "TakeDamage", function(self, amount) self.Health = math.max(0, self.Health - amount) if self.Health <= 0 then self.Died:Fire() end end)
m("Humanoid", "ChangeState", function() end)
m("Animator", "LoadAnimation", function()
	local track = I.new("AnimationTrack")
	return track
end)
m("AnimationTrack", "Play", function(self) self.IsPlaying = true end)
m("AnimationTrack", "Stop", function(self) self.IsPlaying = false end)
m("Workspace", "Raycast", function() return nil end)
m("Workspace", "GetServerTimeNow", function() return os.clock() end)
m("Player", "RequestStreamAroundAsync", function() end)
m("Player", "IsInGroup", function() return false end)
m("Player", "LoadCharacter", function() end)
m("RemoteEvent", "FireClient", function(self, plr, ...) self.OnClientEvent:Fire(...) end)
m("RemoteEvent", "FireAllClients", function(self, ...) self.OnClientEvent:Fire(...) end)
m("RemoteEvent", "FireServer", function(self, ...) self.OnServerEvent:Fire(_G.LocalPlayer, ...) end)
m("UnreliableRemoteEvent", "FireClient", function(self, plr, ...) self.OnClientEvent:Fire(...) end)
m("UnreliableRemoteEvent", "FireAllClients", function(self, ...) self.OnClientEvent:Fire(...) end)
m("UnreliableRemoteEvent", "FireServer", function(self, ...) self.OnServerEvent:Fire(_G.LocalPlayer, ...) end)
m("BindableEvent", "Fire", function(self, ...) self.Event:Fire(...) end)
m("Players", "GetPlayers", function(self)
	local list = {}
	for _, c in self:GetChildren() do
		if c:IsA("Player") then
			table.insert(list, c)
		end
	end
	return list
end)
m("Players", "GetPlayerFromCharacter", function(self, char)
	for _, p in self:GetChildren() do
		if p:IsA("Player") and p.Character == char then
			return p
		end
	end
	return nil
end)
m("Players", "GetPlayerByUserId", function(self, id)
	for _, p in self:GetChildren() do
		if p:IsA("Player") and p.UserId == id then
			return p
		end
	end
	return nil
end)
m("Players", "GetNameFromUserIdAsync", function() return "Someone" end)
m("Players", "CreateHumanoidModelFromDescription", function()
	local model = I.new("Model")
	local root = I.new("Part"); root.Name = "HumanoidRootPart"; root.Parent = model
	local head = I.new("Part"); head.Name = "Head"; head.Parent = model
	local hum = I.new("Humanoid"); hum.Parent = model
	local animator = I.new("Animator"); animator.Parent = hum
	model.PrimaryPart = root
	return model
end)
m("DataStoreService", "GetDataStore", function() error("Studio access to API services is disabled (mock)") end)
m("DataStoreService", "GetOrderedDataStore", function() error("Studio access to API services is disabled (mock)") end)
m("DataModel", "BindToClose", function() end)
m("MarketplaceService", "UserOwnsGamePassAsync", function() return false end)
m("MarketplaceService", "PromptGamePassPurchase", function() end)
m("MarketplaceService", "PromptProductPurchase", function() end)
m("MarketplaceService", "GetProductInfo", function() return { PriceInRobux = 99 } end)
m("AnalyticsService", "LogOnboardingFunnelStepEvent", function() end)
m("AnalyticsService", "LogEconomyEvent", function() end)
m("AnalyticsService", "LogCustomEvent", function() end)
local tweenGoals = {}
m("TweenService", "Create", function(self, inst, info, goals)
	local tween = wrap(I.new("Tween"))
	for k in goals do
		local _ = inst[k] -- validates the property name
	end
	tweenGoals[idOf(unwrap(tween))] = { inst = inst, goals = goals }
	return tween
end)
m("Tween", "Play", function(self)
	local t = tweenGoals[idOf(unwrap(self))]
	if t then
		for k, v in t.goals do
			t.inst[k] = v
		end
	end
end)
m("Debris", "AddItem", function() end)
m("ContextActionService", "BindAction", function() end)
m("PathfindingService", "CreatePath", function()
	local path = I.new("Path")
	return path
end)
m("Path", "ComputeAsync", function() end)
m("Path", "GetWaypoints", function() return {} end)

---------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------
local game = I.new("DataModel")
local workspace = game:GetService("Workspace")
local camera = I.new("Camera")
camera.Parent = workspace
workspace.CurrentCamera = camera

local function newRandom(seed)
	local state = seed or os.clock() * 1000
	local r = {}
	local function nextFloat()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	function r:NextNumber(a, b)
		if a == nil then
			return nextFloat()
		end
		return a + (b - a) * nextFloat()
	end
	function r:NextInteger(a, b)
		return math.floor(a + (b - a + 1) * nextFloat())
	end
	return r
end

local env = {
	game = wrap(game), workspace = wrap(workspace), task = task,
	typeof = function(v)
		if type(v) == "table" and rawOf[v] then
			return "Instance"
		end
		return typeof(v)
	end, warn = function(...) print("⚠️", ...) end,
	Instance = {
		new = function(className, parent)
			local inst = I.new(className)
			if parent then
				inst.Parent = unwrap(parent)
			end
			return wrap(inst)
		end,
	},
	Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	UDim = roblox.UDim, UDim2 = roblox.UDim2, Enum = roblox.Enum, ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange,
	TweenInfo = { new = function() return {} end }, RaycastParams = { new = function() return {} end },
	Random = { new = newRandom }, Ray = roblox.Ray,
}
setmetatable(env, { __index = _G })
m("DataModel", "GetService", function(self, name)
	local existing = self:FindFirstChildOfClass(name)
	if existing then
		return existing
	end
	local service = I.new(name)
	service.Parent = self
	return service
end)

---------------------------------------------------------------------------
-- Load the Rojo project into the mock DataModel
---------------------------------------------------------------------------
local sources = {} -- [hid] = path
local function sourceOf(inst)
	return sources[idOf(inst)]
end
local function scriptClass(file)
	if file:match("%.server%.lua$") then
		return "Script", file:gsub("%.server%.lua$", "")
	elseif file:match("%.client%.lua$") then
		return "LocalScript", file:gsub("%.client%.lua$", "")
	end
	return "ModuleScript", file:gsub("%.lua$", "")
end
local function loadDir(dir, parent)
	for _, file in fs.readDir(dir) do
		local path = dir .. "/" .. file
		if fs.isDir(path) then
			local folder = I.new("Folder")
			folder.Name = file
			folder.Parent = parent
			loadDir(path, folder)
		elseif file:match("%.lua$") then
			local class, name = scriptClass(file)
			local s = I.new(class)
			s.Name = name
			s.Parent = parent
			sources[idOf(s)] = path
		end
	end
end
local project = (require("@lune/serde")).decode("json", fs.readFile(projectDir .. "/default.project.json"))
local function mount(node, parent)
	for name, child in node do
		if name:sub(1, 1) ~= "$" and type(child) == "table" then
			local inst
			if parent == game then
				inst = game:GetService(name)
			else
				inst = I.new(child["$className"] or "Folder")
				inst.Name = name
				inst.Parent = parent
			end
			if child["$path"] then
				loadDir(projectDir .. "/" .. child["$path"], inst)
			end
			mount(child, inst)
		end
	end
end
mount(project.tree, game)

local moduleCache = {}
local runScript
local function makeRequire()
	return function(target)
		target = unwrap(target)
		if typeof(target) ~= "Instance" then
			error("require expects an Instance in this harness")
		end
		local key = idOf(target)
		if moduleCache[key] ~= nil then
			return moduleCache[key]
		end
		local result = runScript(target)
		moduleCache[key] = result
		return result
	end
end
runScript = function(scriptInstance)
	local path = sourceOf(scriptInstance)
	assert(path, "no source for " .. scriptInstance:GetFullName())
	local scriptEnv = { script = wrap(scriptInstance), require = makeRequire() }
	for k, v in env do
		scriptEnv[k] = v
	end
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = scriptEnv })
	return fn()
end

local function runTop(scriptInstance)
	local ok, err = pcall(runScript, scriptInstance)
	if not ok then
		failures += 1
		print("❌ " .. scriptInstance:GetFullName() .. ": " .. tostring(err))
	else
		print("✅ ran " .. scriptInstance:GetFullName())
	end
end

---------------------------------------------------------------------------
-- Scenario
---------------------------------------------------------------------------
local Players = game:GetService("Players")
local function findScripts(root, class)
	local list = {}
	for _, d in root:GetDescendants() do
		if d.ClassName == class and sourceOf(d) then
			table.insert(list, d)
		end
	end
	return list
end

-- 1) server scripts
for _, s in findScripts(game:GetService("ServerScriptService"), "Script") do
	task.spawn(runTop, s)
end
task.wait(1)

-- 2) a player joins with a character
local player = I.new("Player")
player.Name = "Tester"
player.UserId = 12345
player.Parent = Players
_G.LocalPlayer = player
local playerGui = I.new("PlayerGui")
playerGui.Parent = player
local function makeCharacter()
	local char = I.new("Model")
	char.Name = "Tester"
	local root = I.new("Part"); root.Name = "HumanoidRootPart"; root.Parent = char
	local head = I.new("Part"); head.Name = "Head"; head.Parent = char
	local torso = I.new("Part"); torso.Name = "UpperTorso"; torso.Parent = char
	local hand = I.new("Part"); hand.Name = "RightHand"; hand.Parent = char
	local hum = I.new("Humanoid"); hum.Parent = char
	local animator = I.new("Animator"); animator.Parent = hum
	char.PrimaryPart = root
	char.Parent = workspace
	player.Character = char
	return char
end
Players.PlayerAdded:Fire(player)
task.wait(0.5)
makeCharacter()
player.CharacterAdded:Fire(player.Character)
task.wait(1)

-- 3) client scripts (UI construction)
Players.LocalPlayer = player
local starterPlayer = game:GetService("StarterPlayer")
for _, s in findScripts(starterPlayer, "LocalScript") do
	task.spawn(runTop, s)
end
task.wait(1.5)

-- 4) game-specific scenario
local scenarioPath = projectDir .. "/../tools/scenario_" .. (projectDir:match("([^/]+)$") or projectDir) .. ".luau"
if fs.isFile(scenarioPath) then
	local scenarioEnv = {
		game = wrap(game), workspace = wrap(workspace), player = wrap(player), I = I, roblox = roblox, task = task, makeCharacter = makeCharacter,
		Vector3 = roblox.Vector3, CFrame = roblox.CFrame, requireModule = makeRequire(),
		fail = function(msg) failures += 1 print("❌ " .. msg) end,
	}
	local scenario = luau.load(fs.readFile(scenarioPath), { debugName = scenarioPath, environment = scenarioEnv })
	local ok, err = pcall(scenario)
	if not ok then
		failures += 1
		print("❌ scenario: " .. tostring(err))
	end
end

task.wait(1)
print(if failures == 0 then "\n🎉 SMOKE TEST PASSED" else ("\n💥 " .. failures .. " problem(s) found"))
process.exit(if failures == 0 then 0 else 1)
