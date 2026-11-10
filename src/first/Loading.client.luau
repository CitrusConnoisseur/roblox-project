--!strict
-- Priority loading screen. Runs in ReplicatedFirst (before other client scripts).
-- Shows immediately, removes the default loading screen, and blocks gameplay until
-- the start menu is fully loaded. Skip is only available after the menu is ready.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

-- Signal for other scripts (StartMenu) to mark the menu as ready.
local menuReady = Instance.new("BindableEvent")
menuReady.Name = "MenuReady"
menuReady.Parent = ReplicatedFirst

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

local COLORS = {
	Bg = Color3.fromRGB(12, 12, 18),
	Panel = Color3.fromRGB(32, 34, 48),
	Text = Color3.fromRGB(240, 242, 248),
	SubText = Color3.fromRGB(170, 176, 196),
	Skip = Color3.fromRGB(88, 101, 242),
	SkipText = Color3.fromRGB(255, 255, 255),
	SkipDisabled = Color3.fromRGB(70, 74, 92),
	SkipDisabledText = Color3.fromRGB(140, 145, 165),
	Accent = Color3.fromRGB(72, 199, 142),
}

local function makeCorner(parent: Instance, radius: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local gui = Instance.new("ScreenGui")
gui.Name = "PriorityLoadingGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100 -- above start menu/HUD
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = COLORS.Bg
bg.BorderSizePixel = 0
bg.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(420, 200)
panel.BackgroundColor3 = COLORS.Panel
panel.BorderSizePixel = 0
panel.Parent = bg
makeCorner(panel, 14)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(24, 22)
title.Size = UDim2.new(1, -48, 0, 40)
title.Text = "Loading"
title.TextColor3 = COLORS.Text
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(24, 66)
status.Size = UDim2.new(1, -48, 0, 26)
status.Text = "Loading menu..."
status.TextColor3 = COLORS.SubText
status.TextScaled = true
status.Font = Enum.Font.Gotham
status.Parent = panel

local barBg = Instance.new("Frame")
barBg.Position = UDim2.fromOffset(24, 104)
barBg.Size = UDim2.new(1, -48, 0, 8)
barBg.BackgroundColor3 = Color3.fromRGB(55, 58, 75)
barBg.BorderSizePixel = 0
barBg.Parent = panel
makeCorner(barBg, 4)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0.35, 1)
barFill.BackgroundColor3 = COLORS.Accent
barFill.BorderSizePixel = 0
barFill.Parent = barBg
makeCorner(barFill, 4)

-- simple indeterminate-style progress while waiting for menu
task.spawn(function()
	while gui.Parent do
		barFill.Size = UDim2.fromScale(0.35, 1)
		barFill.Position = UDim2.fromScale(0, 0)
		barFill:TweenPosition(
			UDim2.fromScale(0.65, 0),
			Enum.EasingDirection.InOut,
			Enum.EasingStyle.Sine,
			0.8,
			true
		)
		task.wait(0.85)
		if not gui.Parent then
			break
		end
		barFill:TweenPosition(
			UDim2.fromScale(0, 0),
			Enum.EasingDirection.InOut,
			Enum.EasingStyle.Sine,
			0.8,
			true
		)
		task.wait(0.85)
	end
end)

local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipButton"
skipButton.AnchorPoint = Vector2.new(0.5, 0)
skipButton.Position = UDim2.new(0.5, 0, 1, -52)
skipButton.Size = UDim2.fromOffset(180, 36)
skipButton.BackgroundColor3 = COLORS.SkipDisabled
skipButton.BorderSizePixel = 0
skipButton.AutoButtonColor = false
skipButton.Active = false
skipButton.Text = "Loading menu..."
skipButton.TextColor3 = COLORS.SkipDisabledText
skipButton.TextScaled = true
skipButton.Font = Enum.Font.GothamBold
skipButton.Parent = panel
makeCorner(skipButton, 8)

local ready = false

local function enableSkip(): ()
	if ready then
		return
	end
	ready = true
	status.Text = "Menu ready. You can skip loading."
	barFill:TweenSize(
		UDim2.fromScale(1, 1),
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		0.2,
		true
	)
	skipButton.BackgroundColor3 = COLORS.Skip
	skipButton.TextColor3 = COLORS.SkipText
	skipButton.Text = "Skip"
	skipButton.AutoButtonColor = true
	skipButton.Active = true
end

menuReady.Event:Connect(enableSkip)

skipButton.Activated:Connect(function()
	if not ready then
		return
	end
	gui:Destroy()
end)
