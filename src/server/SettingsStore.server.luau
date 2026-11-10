--!strict
-- Saves/loads per-player settings (server-side DataStore).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("PlayerSettings_v1")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local getSettings = Instance.new("RemoteFunction")
getSettings.Name = "GetSettings"
getSettings.Parent = remotes

local saveSettings = Instance.new("RemoteEvent")
saveSettings.Name = "SaveSettings"
saveSettings.Parent = remotes

local function key(player: Player): string
	return ("u_%d"):format(player.UserId)
end

getSettings.OnServerInvoke = function(player: Player)
	local ok, data = pcall(function()
		return store:GetAsync(key(player))
	end)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

saveSettings.OnServerEvent:Connect(function(player: Player, data: unknown)
	if type(data) ~= "table" then
		return
	end
	local payload = data :: { [string]: unknown }
	-- keep only expected fields (simple validation/sanitizing)
	local clean = {
		sprintKey = if type(payload.sprintKey) == "string" then payload.sprintKey else "LeftShift",
		sprintToggle = payload.sprintToggle == true,
		musicVolume = if type(payload.musicVolume) == "number" then payload.musicVolume else 0.5,
		sfxVolume = if type(payload.sfxVolume) == "number" then payload.sfxVolume else 0.5,
		ambienceVolume = if type(payload.ambienceVolume) == "number"
			then payload.ambienceVolume
			else 0.5,
		fasterGraphics = payload.fasterGraphics == true,
	}
	pcall(function()
		store:SetAsync(key(player), clean)
	end)
end)

Players.PlayerRemoving:Connect(function(_player: Player)
	-- (optional) final save could be triggered from client; kept simple here
end)
