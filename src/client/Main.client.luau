--!strict
-- Sprinting (uses Settings). Movement/jump freeze while menus are open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(script.Parent:WaitForChild("Settings"))

local player = Players.LocalPlayer

local sprinting = false

local function getHumanoid(): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function movementLocked(): boolean
	return player:GetAttribute("MenuMovementLocked") == true
end

local function isSliding(): boolean
	return player:GetAttribute("Sliding") == true
end

local function applySprint(): ()
	local humanoid = getHumanoid()
	if not humanoid then
		return
	end
	if movementLocked() then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		return
	end
	humanoid.JumpPower = Config.JUMP_POWER
	if isSliding() then
		-- sliding controls movement; do not apply sprint speed
		return
	end
	humanoid.WalkSpeed = if sprinting then Config.SPRINT_SPEED else Config.WALK_SPEED
end

player.CharacterAdded:Connect(function()
	task.defer(applySprint)
end)

player:GetAttributeChangedSignal("MenuMovementLocked"):Connect(function()
	applySprint()
end)

player:GetAttributeChangedSignal("Sliding"):Connect(function()
	if isSliding() then
		sprinting = false
	end
	applySprint()
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if input.KeyCode ~= Settings.state.sprintKey then
		return
	end
	if isSliding() then
		return
	end
	if Settings.state.sprintToggle then
		sprinting = not sprinting
	else
		sprinting = true
	end
	applySprint()
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if input.KeyCode ~= Settings.state.sprintKey then
		return
	end
	if not Settings.state.sprintToggle then
		sprinting = false
		applySprint()
	end
end)
