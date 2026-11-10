--!strict
-- Shared settings state + UI builder (used by start menu and in-game settings).
-- Saves per player (via server DataStore). Sliders/values apply to available services.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Settings = {}

-- ===== state =====
local DEFAULTS = table.freeze({
	sprintKey = Enum.KeyCode.LeftShift,
	sprintToggle = false,
	musicVolume = 0.5,
	sfxVolume = 0.5,
	ambienceVolume = 0.5,
	fasterGraphics = false,
})

Settings.state = {
	sprintKey = DEFAULTS.sprintKey,
	sprintToggle = DEFAULTS.sprintToggle,
	musicVolume = DEFAULTS.musicVolume,
	sfxVolume = DEFAULTS.sfxVolume,
	ambienceVolume = DEFAULTS.ambienceVolume,
	fasterGraphics = DEFAULTS.fasterGraphics,
}

Settings.selectedTab = "Misc"

function Settings.reset(): ()
	Settings.state.sprintKey = DEFAULTS.sprintKey
	Settings.state.sprintToggle = DEFAULTS.sprintToggle
	Settings.state.musicVolume = DEFAULTS.musicVolume
	Settings.state.sfxVolume = DEFAULTS.sfxVolume
	Settings.state.ambienceVolume = DEFAULTS.ambienceVolume
	Settings.state.fasterGraphics = DEFAULTS.fasterGraphics
	Settings.apply()
end

local COLORS = {
	Panel = Color3.fromRGB(32, 34, 48),
	PanelAlt = Color3.fromRGB(40, 43, 60),
	Text = Color3.fromRGB(240, 242, 248),
	Muted = Color3.fromRGB(130, 136, 156),
	Back = Color3.fromRGB(90, 96, 120),
	BackText = Color3.fromRGB(240, 242, 248),
	Reset = Color3.fromRGB(220, 70, 70),
	ResetText = Color3.fromRGB(255, 255, 255),
	Keybinds = Color3.fromRGB(255, 179, 71),
	Graphics = Color3.fromRGB(86, 204, 242),
	Audio = Color3.fromRGB(167, 139, 250),
	Misc = Color3.fromRGB(244, 114, 182),
	Divider = Color3.fromRGB(58, 62, 82),
	Tab = Color3.fromRGB(55, 58, 78),
	TabActiveText = Color3.fromRGB(255, 255, 255),
	TabInactiveText = Color3.fromRGB(170, 176, 196),
	On = Color3.fromRGB(72, 199, 142),
	Off = Color3.fromRGB(95, 99, 112),
	BarBg = Color3.fromRGB(55, 58, 75),
	BarFill = Color3.fromRGB(88, 101, 242),
	Capture = Color3.fromRGB(234, 179, 8),
}

local listeningForKey: ((Enum.KeyCode) -> ())? = nil

local function makeCorner(parent: Instance, radius: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function getOrCreateGroup(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if g and g:IsA("SoundGroup") then
		return g
	end
	local sg = Instance.new("SoundGroup")
	sg.Name = name
	sg.Parent = SoundService
	return sg
end

local saveRemote: RemoteEvent? = nil
local saveQueued = false

local function queueSave(): ()
	if not saveRemote or saveQueued then
		return
	end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		if saveRemote then
			saveRemote:FireServer({
				sprintKey = Settings.state.sprintKey.Name,
				sprintToggle = Settings.state.sprintToggle,
				musicVolume = Settings.state.musicVolume,
				sfxVolume = Settings.state.sfxVolume,
				ambienceVolume = Settings.state.ambienceVolume,
				fasterGraphics = Settings.state.fasterGraphics,
			})
		end
	end)
end

function Settings.apply(): ()
	getOrCreateGroup("Music").Volume = Settings.state.musicVolume
	getOrCreateGroup("SFX").Volume = Settings.state.sfxVolume
	getOrCreateGroup("Ambience").Volume = Settings.state.ambienceVolume

	local fast = Settings.state.fasterGraphics
	Lighting.GlobalShadows = not fast
	for _, inst in Lighting:GetChildren() do
		if
			inst:IsA("BloomEffect")
			or inst:IsA("BlurEffect")
			or inst:IsA("SunRaysEffect")
			or inst:IsA("ColorCorrectionEffect")
			or inst:IsA("DepthOfFieldEffect")
		then
			inst.Enabled = not fast
		end
	end
	queueSave()
end

-- global key capture for rebinding
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if listeningForKey and input.UserInputType == Enum.UserInputType.Keyboard then
		local cb = listeningForKey
		listeningForKey = nil
		cb(input.KeyCode)
	end
end)

local function makeSection(
	name: string,
	titleText: string,
	accent: Color3,
	height: number,
	parent: Instance,
	onReset: (() -> ())?
): Frame
	local section = Instance.new("Frame")
	section.Name = name
	section.Size = UDim2.new(1, 0, 0, height)
	section.BackgroundColor3 = COLORS.PanelAlt
	section.BorderSizePixel = 0
	section.Parent = parent
	makeCorner(section, 10)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 6, 1, -16)
	bar.Position = UDim2.fromOffset(8, 8)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = section
	makeCorner(bar, 3)

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(22, 6)
	header.Size = UDim2.new(1, -30, 0, 22)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = titleText
	header.TextColor3 = accent
	header.TextScaled = true
	header.Font = Enum.Font.GothamBold
	header.Parent = section

	if onReset then
		local resetBtn = Instance.new("TextButton")
		resetBtn.Name = "ResetSection"
		resetBtn.AnchorPoint = Vector2.new(1, 1)
		resetBtn.Position = UDim2.new(1, -10, 1, -8)
		resetBtn.Size = UDim2.fromOffset(100, 22)
		resetBtn.BackgroundColor3 = COLORS.Reset
		resetBtn.BorderSizePixel = 0
		resetBtn.Text = "Reset defaults"
		resetBtn.TextColor3 = COLORS.ResetText
		resetBtn.TextScaled = true
		resetBtn.Font = Enum.Font.Gotham
		resetBtn.Parent = section
		makeCorner(resetBtn, 6)
		resetBtn.Activated:Connect(onReset)
	end

	return section
end

local function makeToggleRow(
	label: string,
	y: number,
	get: () -> boolean,
	set: (boolean) -> (),
	parent: Instance
): ()
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(22, y)
	lbl.Size = UDim2.new(1, -120, 0, 24)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = label
	lbl.TextColor3 = COLORS.Text
	lbl.TextScaled = true
	lbl.Font = Enum.Font.Gotham
	lbl.Parent = parent

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(72, 26)
	btn.Position = UDim2.new(1, -88, 0, y - 1)
	btn.BorderSizePixel = 0
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.Parent = parent
	makeCorner(btn, 6)

	local function refresh(): ()
		local on = get()
		btn.BackgroundColor3 = if on then COLORS.On else COLORS.Off
		btn.TextColor3 = COLORS.Text
		btn.Text = if on then "ON" else "OFF"
	end
	refresh()
	btn.Activated:Connect(function()
		set(not get())
		Settings.apply()
		refresh()
	end)
end

local function makeSliderRow(
	label: string,
	y: number,
	get: () -> number,
	set: (number) -> (),
	parent: Instance
): ()
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(22, y)
	lbl.Size = UDim2.new(0.45, -22, 0, 22)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = label
	lbl.TextColor3 = COLORS.Text
	lbl.TextScaled = true
	lbl.Font = Enum.Font.Gotham
	lbl.Parent = parent

	local barBg = Instance.new("TextButton")
	barBg.AutoButtonColor = false
	barBg.Text = ""
	barBg.Position = UDim2.new(0.46, 0, 0, y + 2)
	barBg.Size = UDim2.new(0.52, -28, 0, 18)
	barBg.BackgroundColor3 = COLORS.BarBg
	barBg.BorderSizePixel = 0
	barBg.Parent = parent
	makeCorner(barBg, 6)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = COLORS.BarFill
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(get(), 1)
	fill.Parent = barBg
	makeCorner(fill, 6)

	local function setFromX(x: number): ()
		local rel =
			math.clamp((x - barBg.AbsolutePosition.X) / math.max(barBg.AbsoluteSize.X, 1), 0, 1)
		set(rel)
		fill.Size = UDim2.fromScale(rel, 1)
		Settings.apply()
	end

	barBg.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setFromX(input.Position.X)
			local conn: RBXScriptConnection
			local ended: RBXScriptConnection
			conn = UserInputService.InputChanged:Connect(function(changed: InputObject)
				if
					changed.UserInputType == Enum.UserInputType.MouseMovement
					or changed.UserInputType == Enum.UserInputType.Touch
				then
					setFromX(changed.Position.X)
				end
			end)
			ended = UserInputService.InputEnded:Connect(function(fin: InputObject)
				if
					fin.UserInputType == Enum.UserInputType.MouseButton1
					or fin.UserInputType == Enum.UserInputType.Touch
				then
					conn:Disconnect()
					ended:Disconnect()
				end
			end)
		end
	end)
end

local function makeKeybindRow(label: string, y: number, parent: Instance): ()
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(22, y)
	lbl.Size = UDim2.new(0.5, -22, 0, 24)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = label
	lbl.TextColor3 = COLORS.Text
	lbl.TextScaled = true
	lbl.Font = Enum.Font.Gotham
	lbl.Parent = parent

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(120, 26)
	btn.Position = UDim2.new(1, -136, 0, y - 1)
	btn.BackgroundColor3 = COLORS.BarBg
	btn.BorderSizePixel = 0
	btn.TextColor3 = COLORS.Text
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.Text = Settings.state.sprintKey.Name
	btn.Parent = parent
	makeCorner(btn, 6)

	btn.Activated:Connect(function()
		btn.Text = "Press a key..."
		btn.BackgroundColor3 = COLORS.Capture
		listeningForKey = function(key: Enum.KeyCode)
			Settings.state.sprintKey = key
			btn.Text = key.Name
			btn.BackgroundColor3 = COLORS.BarBg
			Settings.apply()
		end
	end)
end

-- Build settings content into `container` (a Frame). Returns Back button.
-- Tabbed sections (defaults to Misc). `Settings.selectedTab` persists across remounts.
function Settings.mount(container: Frame, onBack: () -> (), onRefresh: (() -> ())?): TextButton
	for _, c in container:GetChildren() do
		c:Destroy()
	end

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(0, 0)
	header.Size = UDim2.new(1, -90, 0, 30)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "Settings"
	header.TextColor3 = COLORS.Text
	header.TextScaled = true
	header.Font = Enum.Font.GothamBold
	header.Parent = container

	local back = Instance.new("TextButton")
	back.Name = "BackButton"
	back.Size = UDim2.fromOffset(76, 28)
	back.Position = UDim2.new(1, -76, 0, 1)
	back.BackgroundColor3 = COLORS.Back
	back.BorderSizePixel = 0
	back.Text = "Back"
	back.TextColor3 = COLORS.BackText
	back.TextScaled = true
	back.Font = Enum.Font.GothamBold
	back.Parent = container
	makeCorner(back, 6)
	back.Activated:Connect(onBack)

	-- Section header tabs
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(0, 34)
	tabBar.Size = UDim2.new(1, 0, 0, 30)
	tabBar.Parent = container

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(0, 68)
	divider.Size = UDim2.new(1, 0, 0, 2)
	divider.BackgroundColor3 = COLORS.Divider
	divider.BorderSizePixel = 0
	divider.Parent = container

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, 76)
	body.Size = UDim2.new(1, 0, 1, -76)
	body.BackgroundTransparency = 1
	body.Parent = container

	type SectionDef = {
		id: string,
		label: string,
		accent: Color3,
		build: (Frame) -> (),
	}
	local sections: { SectionDef } = {
		{
			id = "Misc",
			label = "Misc",
			accent = COLORS.Misc,
			build = function(parent)
				local sec = makeSection("Misc", "Miscellaneous", COLORS.Misc, 94, parent, function()
					Settings.state.sprintToggle = DEFAULTS.sprintToggle
					Settings.apply()
					if onRefresh then
						onRefresh()
					end
				end)
				sec.Size = UDim2.new(1, 0, 0, 94)
				makeToggleRow("Sprint toggle", 30, function()
					return Settings.state.sprintToggle
				end, function(v)
					Settings.state.sprintToggle = v
				end, sec)
			end,
		},
		{
			id = "Keybinds",
			label = "Keybinds",
			accent = COLORS.Keybinds,
			build = function(parent)
				local sec = makeSection(
					"Keybinds",
					"Keybinds",
					COLORS.Keybinds,
					94,
					parent,
					function()
						Settings.state.sprintKey = DEFAULTS.sprintKey
						Settings.apply()
						if onRefresh then
							onRefresh()
						end
					end
				)
				sec.Size = UDim2.new(1, 0, 0, 94)
				makeKeybindRow("Sprint key", 30, sec)
			end,
		},
		{
			id = "Audio",
			label = "Audio",
			accent = COLORS.Audio,
			build = function(parent)
				local sec = makeSection("Audio", "Audio", COLORS.Audio, 136, parent, function()
					Settings.state.musicVolume = DEFAULTS.musicVolume
					Settings.state.sfxVolume = DEFAULTS.sfxVolume
					Settings.state.ambienceVolume = DEFAULTS.ambienceVolume
					Settings.apply()
					if onRefresh then
						onRefresh()
					end
				end)
				sec.Size = UDim2.new(1, 0, 0, 136)
				makeSliderRow("Music volume", 30, function()
					return Settings.state.musicVolume
				end, function(v)
					Settings.state.musicVolume = v
				end, sec)
				makeSliderRow("Sound effects volume", 56, function()
					return Settings.state.sfxVolume
				end, function(v)
					Settings.state.sfxVolume = v
				end, sec)
				makeSliderRow("Ambience volume", 82, function()
					return Settings.state.ambienceVolume
				end, function(v)
					Settings.state.ambienceVolume = v
				end, sec)
			end,
		},
		{
			id = "Graphics",
			label = "Graphics",
			accent = COLORS.Graphics,
			build = function(parent)
				local sec = makeSection(
					"Graphics",
					"Graphics",
					COLORS.Graphics,
					94,
					parent,
					function()
						Settings.state.fasterGraphics = DEFAULTS.fasterGraphics
						Settings.apply()
						if onRefresh then
							onRefresh()
						end
					end
				)
				sec.Size = UDim2.new(1, 0, 0, 94)
				makeToggleRow("Faster graphics (weak hardware)", 30, function()
					return Settings.state.fasterGraphics
				end, function(v)
					Settings.state.fasterGraphics = v
				end, sec)
			end,
		},
	}

	local tabButtons: { [string]: TextButton } = {}
	local panes: { [string]: Frame } = {}

	local function selectTab(id: string): ()
		Settings.selectedTab = id
		for sid, pane in panes do
			pane.Visible = sid == id
		end
		for sid, btn in tabButtons do
			local def = nil
			for _, s in sections do
				if s.id == sid then
					def = s
					break
				end
			end
			local accent = if def then def.accent else COLORS.BarFill
			local active = sid == id
			btn.BackgroundColor3 = if active then accent else COLORS.Tab
			btn.TextColor3 = if active then COLORS.TabActiveText else COLORS.TabInactiveText
		end
	end

	for i, def in sections do
		local pane = Instance.new("Frame")
		pane.Name = def.id .. "Pane"
		pane.BackgroundTransparency = 1
		pane.Size = UDim2.fromScale(1, 1)
		pane.Visible = false
		pane.Parent = body
		panes[def.id] = pane
		def.build(pane)

		local btn = Instance.new("TextButton")
		btn.Name = def.id .. "Tab"
		btn.LayoutOrder = i
		btn.Size = UDim2.fromOffset(96, 28)
		btn.BackgroundColor3 = COLORS.Tab
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = true
		btn.Text = def.label
		btn.TextColor3 = COLORS.TabInactiveText
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Parent = tabBar
		makeCorner(btn, 6)
		tabButtons[def.id] = btn
		btn.Activated:Connect(function()
			selectTab(def.id)
		end)
	end

	-- default to Misc (or last selected tab if still valid)
	if panes[Settings.selectedTab] then
		selectTab(Settings.selectedTab)
	else
		selectTab("Misc")
	end

	return back
end

-- Load saved settings for this player (server DataStore), then apply.
do
	local ok, remotes = pcall(function()
		return ReplicatedStorage:WaitForChild("Remotes", 10)
	end)
	if ok and remotes then
		local getFn = remotes:FindFirstChild("GetSettings")
		local saveEv = remotes:FindFirstChild("SaveSettings")
		if saveEv and saveEv:IsA("RemoteEvent") then
			saveRemote = saveEv
		end
		if getFn and getFn:IsA("RemoteFunction") then
			local ok2, data = pcall(function()
				return (getFn :: RemoteFunction):InvokeServer()
			end)
			if ok2 and type(data) == "table" then
				local d = data :: { [string]: unknown }
				if type(d.sprintKey) == "string" then
					local ok3, kc = pcall(function()
						return (Enum.KeyCode :: any)[d.sprintKey]
					end)
					if ok3 and typeof(kc) == "EnumItem" then
						Settings.state.sprintKey = kc :: Enum.KeyCode
					end
				end
				if type(d.sprintToggle) == "boolean" then
					Settings.state.sprintToggle = d.sprintToggle
				end
				if type(d.musicVolume) == "number" then
					Settings.state.musicVolume = math.clamp(d.musicVolume, 0, 1)
				end
				if type(d.sfxVolume) == "number" then
					Settings.state.sfxVolume = math.clamp(d.sfxVolume, 0, 1)
				end
				if type(d.ambienceVolume) == "number" then
					Settings.state.ambienceVolume = math.clamp(d.ambienceVolume, 0, 1)
				end
				if type(d.fasterGraphics) == "boolean" then
					Settings.state.fasterGraphics = d.fasterGraphics
				end
			end
		end
	end
end

Settings.apply()
return Settings
