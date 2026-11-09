--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

Players.PlayerAdded:Connect(function(player: Player)
	print(`{player.Name} joined (walk speed {Config.WALK_SPEED})`)
end)
