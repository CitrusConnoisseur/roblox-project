--!strict
-- Start-up menu + in-game settings icon. Settings UI comes from Settings module.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Settings = require(script.Parent:WaitForChild("Settings"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local modalCount = 0
local manualMouseUnlocked = false

local function applyMouseMode(): ()
	if modalCount > 0 then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		return
	end
	if manualMouseUnlocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
end

local function setModal(open: boolean): ()
	local camera = Workspace.CurrentCamera
	if open then
		modalCount += 1
		player:SetAttribute("MenuMovementLocked", true)
		if camera then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		applyMouseMode()
	else
		modalCount = math.max(modalCount - 1, 0)
		if modalCount == 0 then
			player:SetAttribute("MenuMovementLocked", false)
			local cam = Workspace.CurrentCamera
			if cam then
				cam.CameraType = Enum.CameraType.Custom
			end
		end
		applyMouseMode()
	end
end

-- Toggle mouse lock/unlock in gameplay (keybind configurable in Settings).
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if input.KeyCode ~= Settings.state.mouseUnlockKey then
		return
	end
	if modalCount > 0 then
		return -- menus already control the mouse
	end
	manualMouseUnlocked = not manualMouseUnlocked
	applyMouseMode()
end)

local COLORS = {
	BgImageTint = Color3.fromRGB(15, 15, 22),
	Overlay = Color3.fromRGB(10, 10, 16),
	Panel = Color3.fromRGB(0, 0, 0),
	PanelTransparency = 0.45,
	PanelOutline = Color3.fromRGB(0, 0, 0),
	PanelOutlineThickness = 2,
	Text = Color3.fromRGB(240, 242, 248),
	SubText = Color3.fromRGB(170, 176, 196),
	Play = Color3.fromRGB(72, 199, 142),
	PlayText = Color3.fromRGB(255, 255, 255),
	SettingsBtn = Color3.fromRGB(88, 101, 242),
	SettingsBtnText = Color3.fromRGB(255, 255, 255),
	Icon = Color3.fromRGB(0, 0, 0),
	IconTransparency = 0.45,
	IconOutline = Color3.fromRGB(0, 0, 0),
	IconText = Color3.fromRGB(240, 242, 248),
}

local function makeCorner(parent: Instance, radius: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function addOutline(parent: Instance, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

-- ===== Persistent in-game HUD (settings icon) =====
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "GameHudGui"
hudGui.ResetOnSpawn = false
hudGui.IgnoreGuiInset = true
hudGui.DisplayOrder = 5
hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hudGui.Parent = playerGui

local iconButton = Instance.new("TextButton")
iconButton.Name = "SettingsIcon"
iconButton.AnchorPoint = Vector2.new(1, 0)
iconButton.Position = UDim2.new(1, -16, 0, 16)
iconButton.Size = UDim2.fromOffset(44, 44)
iconButton.BackgroundColor3 = COLORS.Icon
iconButton.BackgroundTransparency = COLORS.IconTransparency
iconButton.BorderSizePixel = 0
iconButton.Text = "⚙"
iconButton.TextColor3 = COLORS.IconText
iconButton.TextScaled = true
iconButton.Font = Enum.Font.GothamBold
iconButton.Visible = false -- shown after leaving the start menu
iconButton.Parent = hudGui
makeCorner(iconButton, 10)
addOutline(iconButton, COLORS.IconOutline, 2)

-- In-game settings overlay (transparent background)
local ingameOverlay = Instance.new("Frame")
ingameOverlay.Name = "InGameSettingsOverlay"
ingameOverlay.Size = UDim2.fromScale(1, 1)
ingameOverlay.BackgroundTransparency = 1 -- transparent background (in-game)
ingameOverlay.BorderSizePixel = 0
ingameOverlay.Visible = false
ingameOverlay.Parent = hudGui

local ingamePanel = Instance.new("Frame")
ingamePanel.Name = "SettingsPanel"
ingamePanel.AnchorPoint = Vector2.new(0.5, 0.5)
ingamePanel.Position = UDim2.fromScale(0.5, 0.5)
ingamePanel.Size = UDim2.fromOffset(640, 380)
ingamePanel.BackgroundColor3 = COLORS.Panel
ingamePanel.BackgroundTransparency = COLORS.PanelTransparency
ingamePanel.BorderSizePixel = 0
ingamePanel.Parent = ingameOverlay
makeCorner(ingamePanel, 14)
addOutline(ingamePanel, COLORS.PanelOutline, COLORS.PanelOutlineThickness)

local ingameContent = Instance.new("Frame")
ingameContent.Name = "Content"
ingameContent.BackgroundTransparency = 1
ingameContent.Position = UDim2.fromOffset(20, 16)
ingameContent.Size = UDim2.new(1, -40, 1, -32)
ingameContent.Parent = ingamePanel

local remountIngame: () -> ()

local function closeInGameSettings(): ()
	ingameOverlay.Visible = false
	iconButton.Visible = true
	setModal(false)
end

remountIngame = function()
	Settings.mount(ingameContent, closeInGameSettings, remountIngame)
end
remountIngame()

iconButton.Activated:Connect(function()
	iconButton.Visible = false
	ingameOverlay.Visible = true
	setModal(true)
end)

-- ===== Start-up menu =====
local menuGui = Instance.new("ScreenGui")
menuGui.Name = "StartMenuGui"
menuGui.ResetOnSpawn = false
menuGui.IgnoreGuiInset = true
menuGui.DisplayOrder = 10
menuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
menuGui.Parent = playerGui

-- Static background image with procedural animation (start menu only).
local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(8, 5, 20)
bg.ClipsDescendants = true
bg.BorderSizePixel = 0
bg.Parent = menuGui

-- Slow zoom focused toward the sun area (adjust anchor/position if needed for this image)
local bgImage = Instance.new("ImageLabel")
bgImage.Name = "BackgroundImage"
bgImage.AnchorPoint = Vector2.new(0.5, 0.6)
bgImage.Position = UDim2.fromScale(0.5, 0.6)
bgImage.Size = UDim2.fromScale(1.05, 1.05)
bgImage.BackgroundTransparency = 1
bgImage.Image = "rbxassetid://123023559434779"
bgImage.ScaleType = Enum.ScaleType.Crop
bgImage.BorderSizePixel = 0
bgImage.ZIndex = 0
bgImage.Parent = bg

-- Color-shift overlay
local colorShift = Instance.new("Frame")
colorShift.Name = "ColorShift"
colorShift.Size = UDim2.fromScale(1, 1)
colorShift.BackgroundColor3 = Color3.fromRGB(255, 140, 80)
colorShift.BackgroundTransparency = 0.88
colorShift.BorderSizePixel = 0
colorShift.ZIndex = 1
colorShift.Parent = bg
local colorShiftGrad = Instance.new("UIGradient")
colorShiftGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 60)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 160)),
})
colorShiftGrad.Rotation = 90
colorShiftGrad.Parent = colorShift

-- Pulsing horizon glow (repositioned for this image; adjust Y if horizon sits elsewhere)
local horizonGlow = Instance.new("Frame")
horizonGlow.Name = "HorizonGlow"
horizonGlow.AnchorPoint = Vector2.new(0.5, 0.5)
horizonGlow.Position = UDim2.fromScale(0.5, 0.72)
horizonGlow.Size = UDim2.new(1.4, 0, 0, 170)
horizonGlow.BackgroundColor3 = Color3.fromRGB(255, 160, 80)
horizonGlow.BackgroundTransparency = 0.55
horizonGlow.BorderSizePixel = 0
horizonGlow.ZIndex = 2
horizonGlow.Parent = bg
local horizonCorner = Instance.new("UICorner")
horizonCorner.CornerRadius = UDim.new(1, 0)
horizonCorner.Parent = horizonGlow
local horizonGrad = Instance.new("UIGradient")
horizonGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 120)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 60)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 160)),
})
horizonGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.18),
	NumberSequenceKeypoint.new(1, 1),
})
horizonGrad.Rotation = 90
horizonGrad.Parent = horizonGlow

-- Procedural animation: slow zoom in, color shifts, pulsing horizon glow.
task.spawn(function()
	local t = 0
	while menuGui.Parent do
		t += 0.03
		-- slow zoom in/out focused on the sun area
		local zoom = 1.05 + ((math.sin(t * 0.12) + 1) / 2) * 0.13
		bgImage.Size = UDim2.fromScale(zoom, zoom)

		-- color shifts
		local hue = (math.sin(t * 0.18) + 1) / 2
		local hue2 = (math.sin(t * 0.13 + 1.2) + 1) / 2
		bgImage.ImageColor3 = Color3.fromHSV(0.06 + hue * 0.05, 0.12 + hue2 * 0.1, 1)
		colorShift.BackgroundTransparency = 0.84 + math.sin(t * 0.22) * 0.04
		colorShiftGrad.Rotation = 90 + math.sin(t * 0.1) * 20
		colorShiftGrad.Offset = Vector2.new(0, math.sin(t * 0.15) * 0.08)

		-- pulsing horizon glow
		local pulse = (math.sin(t * 1.1) + 1) / 2
		horizonGlow.BackgroundTransparency = 0.62 - pulse * 0.18
		horizonGlow.Size = UDim2.new(1.4, 0, 0, 160 + pulse * 28)
		horizonGrad.Offset = Vector2.new(math.sin(t * 0.35) * 0.06, 0)
		horizonGlow.Position = UDim2.new(0.5, 0, 0.72, math.sin(t * 0.5) * 4)

		task.wait(0.03)
	end
end)

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = COLORS.Overlay
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel = 0
overlay.Parent = bg

-- Wider rectangular panel (more width to match height)
local mainPanel = Instance.new("Frame")
mainPanel.Name = "MainPanel"
mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
mainPanel.Position = UDim2.fromScale(0.5, 0.5)
mainPanel.Size = UDim2.fromOffset(640, 380)
mainPanel.BackgroundColor3 = COLORS.Panel
mainPanel.BackgroundTransparency = COLORS.PanelTransparency
mainPanel.BorderSizePixel = 0
mainPanel.Parent = overlay
makeCorner(mainPanel, 14)
addOutline(mainPanel, COLORS.PanelOutline, COLORS.PanelOutlineThickness)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(28, 24)
title.Size = UDim2.new(1, -56, 0, 54)
title.Text = "My Game"
title.TextColor3 = COLORS.Text
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainPanel

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(28, 78)
subtitle.Size = UDim2.new(1, -56, 0, 28)
subtitle.Text = "Ready to play?"
subtitle.TextColor3 = COLORS.SubText
subtitle.TextScaled = true
subtitle.Font = Enum.Font.Gotham
subtitle.Parent = mainPanel

local playButton = Instance.new("TextButton")
playButton.Name = "PlayButton"
playButton.AnchorPoint = Vector2.new(0.5, 0)
playButton.Position = UDim2.new(0.5, 0, 1, -130)
playButton.Size = UDim2.fromOffset(260, 50)
playButton.BackgroundColor3 = COLORS.Play
playButton.BorderSizePixel = 0
playButton.AutoButtonColor = true
playButton.Text = "Play"
playButton.TextColor3 = COLORS.PlayText
playButton.TextScaled = true
playButton.Font = Enum.Font.GothamBold
playButton.Parent = mainPanel
makeCorner(playButton, 8)

local settingsButton = Instance.new("TextButton")
settingsButton.Name = "SettingsButton"
settingsButton.AnchorPoint = Vector2.new(0.5, 0)
settingsButton.Position = UDim2.new(0.5, 0, 1, -68)
settingsButton.Size = UDim2.fromOffset(260, 44)
settingsButton.BackgroundColor3 = COLORS.SettingsBtn
settingsButton.BorderSizePixel = 0
settingsButton.AutoButtonColor = true
settingsButton.Text = "Settings"
settingsButton.TextColor3 = COLORS.SettingsBtnText
settingsButton.TextScaled = true
settingsButton.Font = Enum.Font.GothamBold
settingsButton.Parent = mainPanel
makeCorner(settingsButton, 8)

-- Settings view inside the start menu (opaque/normal)
local menuSettingsPanel = Instance.new("Frame")
menuSettingsPanel.Name = "MenuSettingsPanel"
menuSettingsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
menuSettingsPanel.Position = UDim2.fromScale(0.5, 0.5)
menuSettingsPanel.Size = UDim2.fromOffset(640, 380)
menuSettingsPanel.BackgroundColor3 = COLORS.Panel
menuSettingsPanel.BackgroundTransparency = COLORS.PanelTransparency
menuSettingsPanel.BorderSizePixel = 0
menuSettingsPanel.Visible = false
menuSettingsPanel.Parent = overlay
makeCorner(menuSettingsPanel, 14)
addOutline(menuSettingsPanel, COLORS.PanelOutline, COLORS.PanelOutlineThickness)

local menuSettingsContent = Instance.new("Frame")
menuSettingsContent.BackgroundTransparency = 1
menuSettingsContent.Position = UDim2.fromOffset(20, 16)
menuSettingsContent.Size = UDim2.new(1, -40, 1, -32)
menuSettingsContent.Parent = menuSettingsPanel

local remountMenuSettings: () -> ()

local function closeMenuSettings(): ()
	menuSettingsPanel.Visible = false
	mainPanel.Visible = true
end

remountMenuSettings = function()
	Settings.mount(menuSettingsContent, closeMenuSettings, remountMenuSettings)
end
remountMenuSettings()

settingsButton.Activated:Connect(function()
	mainPanel.Visible = false
	menuSettingsPanel.Visible = true
end)

playButton.Activated:Connect(function()
	menuGui:Destroy()
	iconButton.Visible = true -- keep in-game settings icon available
	setModal(false) -- release start-menu camera lock
	-- Add "start game" logic here later (e.g., enable controls, spawn, load a level).
end)

Settings.apply()
setModal(true) -- lock camera while start menu is shown

-- Signal priority loading screen that the menu is ready (skip becomes available).
do
	local ReplicatedFirst = game:GetService("ReplicatedFirst")
	local readyEvent = ReplicatedFirst:FindFirstChild("MenuReady")
	if readyEvent and readyEvent:IsA("BindableEvent") then
		readyEvent:Fire()
	end
end
