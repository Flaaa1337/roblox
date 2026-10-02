-- Global "top raiders" board in the Outpost (all-time value extracted).

local Players = game:GetService("Players")

local LeaderboardService = {}
local S

local REFRESH = 120
local nameCache = {}

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else "Player"
	return nameCache[userId]
end

local function render(entries)
	local list = S.World.hub.leaderboardList
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if #entries == 0 then
		entries = { { name = "Be the first!", value = 0 } }
	end
	for rank, entry in entries do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = rank
		row.Size = UDim2.fromScale(1, 0.09)
		row.BackgroundTransparency = 1
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextScaled = true
		row.Font = Enum.Font.GothamBold
		row.TextColor3 = if rank == 1
			then Color3.fromRGB(255, 215, 80)
			elseif rank <= 3 then Color3.fromRGB(220, 230, 255)
			else Color3.fromRGB(180, 190, 210)
		row.Text = string.format("#%d  %s  —  %d credits", rank, entry.name, entry.value)
		row.Parent = list
	end
end

local function refresh()
	local board = S.Data.GetEarnedBoard()
	if not board then
		render({})
		return
	end
	local ok, pages = pcall(board.GetSortedAsync, board, false, 10)
	if not ok then
		return
	end
	local entries = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { name = nameFor(userId), value = item.value })
		end
	end
	render(entries)
end

function LeaderboardService.Init(services)
	S = services
end

function LeaderboardService.Start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
