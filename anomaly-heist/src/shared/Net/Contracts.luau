--!strict
-- Network contract: every remote the game uses, created by the server and
-- looked up (with a timeout) by the client. Clients send intent only.
--
-- Server -> client
--   AreaTransition(phase: "start" | "arrived" | "failed", areaId: string, errorCode: string?)
--   Notice(errorCode: string)
--
-- Client -> server: none in M1 (portals use server-side ProximityPrompt
-- handling). Capture/cargo/extraction requests arrive with M2.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = {}

Contracts.FolderName = "AnomalyHeistRemotes"
Contracts.ReadyAttribute = "AH_ServerReady"
Contracts.ErrorAttribute = "AH_ServerError"

Contracts.Events = {
	AreaTransition = "AreaTransition",
	Notice = "Notice",
}

local EVENT_NAMES: { string } = { "AreaTransition", "Notice" }

export type TransitionPhase = "start" | "arrived" | "failed"

function Contracts.createServerRemotes(): { [string]: RemoteEvent }
	local existing = ReplicatedStorage:FindFirstChild(Contracts.FolderName)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = Contracts.FolderName
	local remotes: { [string]: RemoteEvent } = {}
	for _, name in EVENT_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
	return remotes
end

-- Client side: returns nil if the server never created the remotes.
function Contracts.waitForRemotes(timeoutSeconds: number): { [string]: RemoteEvent }?
	local folder = ReplicatedStorage:WaitForChild(Contracts.FolderName, timeoutSeconds)
	if not folder then
		return nil
	end
	local remotes: { [string]: RemoteEvent } = {}
	for _, name in EVENT_NAMES do
		local remote = folder:WaitForChild(name, timeoutSeconds)
		if not remote or not remote:IsA("RemoteEvent") then
			return nil
		end
		remotes[name] = remote
	end
	return remotes
end

return Contracts
