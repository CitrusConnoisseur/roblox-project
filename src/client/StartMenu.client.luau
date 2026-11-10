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

-- Animated neon-sunset background (start menu only). Placeholder-style synthwave attempt.
local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(8, 5, 20)
bg.BorderSizePixel = 0
bg.Parent = menuGui

local sky = Instance.new("Frame")
sky.Name = "Sky"
sky.Size = UDim2.fromScale(1, 1)
sky.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sky.BorderSizePixel = 0
sky.Parent = bg

local skyGradient = Instance.new("UIGradient")
skyGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 2, 20)), -- night
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(25, 0, 60)), -- deep purple
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 0, 120)), -- magenta purple
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(180, 40, 120)), -- horizon pink
	ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 5, 35)), -- lower dark
})
skyGradient.Rotation = 90
skyGradient.Parent = sky

-- Neon sun (retro/synthwave style) near horizon
local sunGlow = Instance.new("Frame")
sunGlow.Name = "SunGlow"
sunGlow.AnchorPoint = Vector2.new(0.5, 0.5)
sunGlow.Position = UDim2.fromScale(0.5, 0.72)
sunGlow.Size = UDim2.fromOffset(460, 460)
sunGlow.BackgroundColor3 = Color3.fromRGB(255, 120, 60)
sunGlow.BackgroundTransparency = 0.55
sunGlow.BorderSizePixel = 0
sunGlow.ZIndex = 1
sunGlow.Parent = bg
local sunGlowCorner = Instance.new("UICorner")
sunGlowCorner.CornerRadius = UDim.new(1, 0)
sunGlowCorner.Parent = sunGlow
local sunGlowGrad = Instance.new("UIGradient")
sunGlowGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 120)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 160)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 0, 255)),
})
sunGlowGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(0.6, 0.55),
	NumberSequenceKeypoint.new(1, 1),
})
sunGlowGrad.Rotation = 90
sunGlowGrad.Parent = sunGlow

local sun = Instance.new("Frame")
sun.Name = "NeonSun"
sun.AnchorPoint = Vector2.new(0.5, 0.5)
sun.Position = UDim2.fromScale(0.5, 0.72)
sun.Size = UDim2.fromOffset(360, 360)
sun.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sun.BorderSizePixel = 0
sun.ClipsDescendants = true -- keep stripes inside the sun
sun.ZIndex = 2
sun.Parent = bg
local sunCorner = Instance.new("UICorner")
sunCorner.CornerRadius = UDim.new(1, 0)
sunCorner.Parent = sun

local sunGradient = Instance.new("UIGradient")
sunGradient.Rotation = 90
sunGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 120)), -- bright top
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 160, 40)), -- orange
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 0, 140)), -- neon pink
	ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 0, 255)), -- purple bottom
})
sunGradient.Parent = sun

-- Horizontal stripes across lower sun for retro "neon sun" look (clipped to sun)
local stripeRatios = { 0.52, 0.60, 0.67, 0.73, 0.785, 0.835, 0.88, 0.92 }
local stripeHeights = { 0.018, 0.022, 0.028, 0.034, 0.042, 0.05, 0.06, 0.07 }
for i, y in stripeRatios do
	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe" .. i
	stripe.BackgroundColor3 = Color3.fromRGB(8, 5, 20)
	stripe.BackgroundTransparency = 0.02
	stripe.BorderSizePixel = 0
	stripe.Position = UDim2.fromScale(0, y)
	stripe.Size = UDim2.fromScale(1, stripeHeights[i] or 0.03)
	stripe.ZIndex = 3
	stripe.Parent = sun
end

-- Horizon glow band
local horizonGlow = Instance.new("Frame")
horizonGlow.Name = "HorizonGlow"
horizonGlow.AnchorPoint = Vector2.new(0.5, 0.5)
horizonGlow.Position = UDim2.fromScale(0.5, 0.8)
horizonGlow.Size = UDim2.new(1.4, 0, 0, 160)
horizonGlow.BackgroundColor3 = Color3.fromRGB(255, 90, 180)
horizonGlow.BackgroundTransparency = 0.35
horizonGlow.BorderSizePixel = 0
horizonGlow.ZIndex = 3
horizonGlow.Parent = bg
local horizonCorner = Instance.new("UICorner")
horizonCorner.CornerRadius = UDim.new(1, 0)
horizonCorner.Parent = horizonGlow
local horizonGrad = Instance.new("UIGradient")
horizonGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 0, 160)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 0, 255)),
})
horizonGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.15),
	NumberSequenceKeypoint.new(1, 1),
})
horizonGrad.Rotation = 90
horizonGrad.Parent = horizonGlow

-- Flowing wave bands at bottom
local wave1 = Instance.new("Frame")
wave1.Name = "Wave1"
wave1.AnchorPoint = Vector2.new(0.5, 0.5)
wave1.Position = UDim2.fromScale(0.5, 0.9)
wave1.Size = UDim2.new(1.4, 0, 0, 90)
wave1.BackgroundColor3 = Color3.fromRGB(255, 0, 140)
wave1.BackgroundTransparency = 0.7
wave1.BorderSizePixel = 0
wave1.ZIndex = 3
wave1.Parent = bg
local wave1Corner = Instance.new("UICorner")
wave1Corner.CornerRadius = UDim.new(1, 0)
wave1Corner.Parent = wave1
local wave1Grad = Instance.new("UIGradient")
wave1Grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 0, 160)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 200)),
})
wave1Grad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.4),
	NumberSequenceKeypoint.new(0.7, 0.4),
	NumberSequenceKeypoint.new(1, 1),
})
wave1Grad.Parent = wave1

local wave2 = Instance.new("Frame")
wave2.Name = "Wave2"
wave2.AnchorPoint = Vector2.new(0.5, 0.5)
wave2.Position = UDim2.fromScale(0.5, 0.97)
wave2.Size = UDim2.new(1.5, 0, 0, 110)
wave2.BackgroundColor3 = Color3.fromRGB(120, 0, 255)
wave2.BackgroundTransparency = 0.75
wave2.BorderSizePixel = 0
wave2.ZIndex = 3
wave2.Parent = bg
local wave2Corner = Instance.new("UICorner")
wave2Corner.CornerRadius = UDim.new(1, 0)
wave2Corner.Parent = wave2
local wave2Grad = Instance.new("UIGradient")
wave2Grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 0, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 0, 120)),
})
wave2Grad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.35, 0.45),
	NumberSequenceKeypoint.new(0.65, 0.45),
	NumberSequenceKeypoint.new(1, 1),
})
wave2Grad.Parent = wave2

-- Animated sun radiation + flowing bottom waves.
task.spawn(function()
	local t = 0
	while menuGui.Parent do
		t += 0.03
		-- sun radiating light (pulsing glow)
		local radiate = 0.5 + 0.5 * math.sin(t * 1.6)
		local glowSize = 440 + radiate * 50
		sunGlow.Size = UDim2.fromOffset(glowSize, glowSize)
		sunGlow.BackgroundTransparency = 0.48 + (1 - radiate) * 0.12
		sunGlowGrad.Offset = Vector2.new(0, math.sin(t * 0.9) * 0.06)

		-- subtle sun shimmer
		sunGradient.Offset = Vector2.new(0, math.sin(t * 0.7) * 0.04)
		skyGradient.Offset = Vector2.new(0, math.sin(t * 0.18) * 0.03)

		-- flowing horizon/waves
		horizonGlow.BackgroundTransparency = 0.28 + math.sin(t * 1.1) * 0.08
		horizonGrad.Offset = Vector2.new(math.sin(t * 0.8) * 0.18, 0)

		wave1Grad.Offset = Vector2.new(math.sin(t * 1.3) * 0.35, 0)
		wave1.Position = UDim2.new(0.5, math.sin(t * 0.9) * 18, 0.9, math.sin(t * 1.1) * 6)
		wave1.BackgroundTransparency = 0.62 + math.sin(t * 1.4 + 0.5) * 0.08

		wave2Grad.Offset = Vector2.new(math.sin(t * 1.0 + 1.2) * -0.4, 0)
		wave2.Position = UDim2.new(0.5, math.sin(t * 0.7 + 1.0) * -22, 0.97, math.sin(t * 0.9) * 5)
		wave2.BackgroundTransparency = 0.68 + math.sin(t * 1.2 + 1.0) * 0.08
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
