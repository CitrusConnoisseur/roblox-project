--!strict
-- Parkour mechanics: slide, double jump, wall jump, mantle/ledge climb.
-- Works with sprinting (Main.client.luau) and respects menu movement lock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(script.Parent:WaitForChild("Settings"))

local player = Players.LocalPlayer

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil

local canDoubleJump = false
local hasDoubleJumped = false
local sliding = false
local lastSlideEnd = 0
local slideDirection = Vector3.zero

local ledgeGrabbing = false
local ledgeHangPos = Vector3.zero
local ledgeTopPos = Vector3.zero
local ledgeForward = Vector3.zero

local function movementLocked(): boolean
	return player:GetAttribute("MenuMovementLocked") == true
end

local function isGrounded(hum: Humanoid): boolean
	local state = hum:GetState()
	return state == Enum.HumanoidStateType.Running
		or state == Enum.HumanoidStateType.Landed
		or state == Enum.HumanoidStateType.RunningNoPhysics
end

local function getMoveDirection(): Vector3
	local char = character
	local r = root
	if not char or not r then
		return Vector3.zero
	end
	local hum = humanoid
	local dir = if hum then hum.MoveDirection else Vector3.zero
	if dir.Magnitude < 0.1 then
		-- fall back to camera/look direction flattened
		local look = r.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
		if dir.Magnitude > 0 then
			dir = dir.Unit
		else
			dir = Vector3.zero
		end
	end
	return dir
end

local function raycast(origin: Vector3, direction: Vector3, ignore: Instance): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	params.IgnoreWater = true
	return Workspace:Raycast(origin, direction, params)
end

local function findWall(): Vector3?
	local r = root
	local char = character
	if not r or not char then
		return nil
	end
	local dirs = {
		r.CFrame.LookVector,
		-r.CFrame.LookVector,
		r.CFrame.RightVector,
		-r.CFrame.RightVector,
	}
	local origin = r.Position
	local bestNormal: Vector3? = nil
	local bestDist = Config.WALL_CHECK_DISTANCE + 1
	for _, d in dirs do
		local dir = Vector3.new(d.X, 0, d.Z)
		if dir.Magnitude < 0.01 then
			continue
		end
		dir = dir.Unit
		local result = raycast(origin, dir * Config.WALL_CHECK_DISTANCE, char)
		if result and result.Distance < bestDist then
			bestDist = result.Distance
			bestNormal = result.Normal
		end
	end
	return bestNormal
end

local function releaseLedge(drop: boolean)
	if not ledgeGrabbing then
		return
	end
	ledgeGrabbing = false
	player:SetAttribute("LedgeGrabbing", false)
	local hum = humanoid
	local r = root
	if hum and r then
		hum.PlatformStand = false
		hum.AutoRotate = true
		if not movementLocked() then
			if drop then
				hum:ChangeState(Enum.HumanoidStateType.Freefall)
			else
				hum:ChangeState(Enum.HumanoidStateType.Running)
			end
		end
	end
end

local function climbLedge()
	if not ledgeGrabbing then
		return
	end
	local hum = humanoid
	local r = root
	local char = character
	if not hum or not r or not char then
		releaseLedge(true)
		return
	end
	-- Stop holding and climb up smoothly to top of ledge.
	ledgeGrabbing = false
	player:SetAttribute("LedgeGrabbing", false)

	local startPos = r.Position
	local targetPos = ledgeTopPos
	local forward = ledgeForward
	hum.AutoRotate = false
	hum.PlatformStand = true
	r.AssemblyLinearVelocity = Vector3.zero

	task.spawn(function()
		local duration = 0.3
		local steps = 15
		for i = 1, steps do
			if character ~= char or humanoid ~= hum or root ~= r or movementLocked() then
				break
			end
			local alpha = i / steps
			-- lift up first, then move onto ledge
			local liftAlpha = math.clamp(alpha * 1.3, 0, 1)
			local pos = Vector3.new(
				startPos.X + (targetPos.X - startPos.X) * math.clamp((alpha - 0.25) / 0.75, 0, 1),
				startPos.Y + (targetPos.Y - startPos.Y) * liftAlpha,
				startPos.Z + (targetPos.Z - startPos.Z) * math.clamp((alpha - 0.25) / 0.75, 0, 1)
			)
			r.CFrame = CFrame.new(pos, pos + forward)
			task.wait(duration / steps)
		end
		if character == char and humanoid == hum and root == r then
			hum.PlatformStand = false
			hum.AutoRotate = true
			if not movementLocked() then
				hum:ChangeState(Enum.HumanoidStateType.Running)
				r.AssemblyLinearVelocity =
					Vector3.new(forward.X * Config.MANTLE_BOOST, 2, forward.Z * Config.MANTLE_BOOST)
			end
		end
	end)
end

local function startLedgeGrab(hangPos: Vector3, topPos: Vector3, forward: Vector3)
	local hum = humanoid
	local r = root
	if not hum or not r or ledgeGrabbing then
		return
	end
	ledgeGrabbing = true
	ledgeHangPos = hangPos
	ledgeTopPos = topPos
	ledgeForward = forward
	player:SetAttribute("LedgeGrabbing", true)

	hum.AutoRotate = false
	hum.PlatformStand = true
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	r.AssemblyLinearVelocity = Vector3.zero
	r.CFrame = CFrame.new(hangPos, hangPos + forward)

	-- Hold hang position until player climbs up, drops, or state invalidates.
	task.spawn(function()
		while ledgeGrabbing do
			if character == nil or humanoid ~= hum or root ~= r or movementLocked() then
				releaseLedge(true)
				break
			end
			r.AssemblyLinearVelocity = Vector3.zero
			r.CFrame = CFrame.new(ledgeHangPos, ledgeHangPos + ledgeForward)
			RunService.Heartbeat:Wait()
		end
	end)
end

local function tryLedgeGrab(): boolean
	local r = root
	local hum = humanoid
	local char = character
	if not r or not hum or not char then
		return false
	end
	if movementLocked() or ledgeGrabbing or sliding then
		return false
	end
	local look = r.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 0.1 then
		return false
	end
	forward = forward.Unit

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	params.IgnoreWater = true

	-- Forward check around waist/chest height
	local forwardOrigin = r.Position + Vector3.new(0, -0.5, 0)
	local forwardHit = Workspace:Raycast(forwardOrigin, forward * Config.MANTLE_REACH, params)
	if not forwardHit then
		-- also try slightly lower
		forwardHit = Workspace:Raycast(
			r.Position + Vector3.new(0, -1.5, 0),
			forward * Config.MANTLE_REACH,
			params
		)
	end
	if not forwardHit then
		return false
	end

	-- Ensure there's space above the obstacle to stand
	local ledgeTopStart = forwardHit.Position
		+ forward * 0.6
		+ Vector3.new(0, Config.MANTLE_MAX_HEIGHT, 0)
	local downHit =
		Workspace:Raycast(ledgeTopStart, Vector3.new(0, -Config.MANTLE_MAX_HEIGHT, 0), params)
	if not downHit then
		return false
	end

	local ledgeY = downHit.Position.Y
	local feetY = r.Position.Y - (hum.HipHeight + (r.Size.Y / 2))
	local climbHeight = ledgeY - feetY
	if climbHeight < Config.MANTLE_MIN_HEIGHT or climbHeight > Config.MANTLE_MAX_HEIGHT then
		return false
	end

	-- Check head clearance at destination
	local headClearOrigin = Vector3.new(downHit.Position.X, ledgeY + 0.5, downHit.Position.Z)
	local headBlocked = Workspace:Raycast(headClearOrigin, Vector3.new(0, 3, 0), params)
	if headBlocked then
		return false
	end

	local topPos = Vector3.new(
		downHit.Position.X,
		ledgeY + hum.HipHeight + (r.Size.Y / 2) + 0.2,
		downHit.Position.Z
	)
	topPos += forward * 1.1

	-- Hang position: at the edge, below the ledge top (grab the edge)
	local hangPos = Vector3.new(
		forwardHit.Position.X - forward.X * 1.1,
		ledgeY - 1.8,
		forwardHit.Position.Z - forward.Z * 1.1
	)

	startLedgeGrab(hangPos, topPos, forward)
	canDoubleJump = true
	hasDoubleJumped = false
	return true
end

local function setSliding(active: boolean)
	sliding = active
	player:SetAttribute("Sliding", active)
end

local function endSlide()
	if not sliding then
		return
	end
	setSliding(false)
	lastSlideEnd = os.clock()
	local hum = humanoid
	local r = root
	if hum and r and not movementLocked() then
		hum.AutoRotate = true
		-- restore speed control is handled by Main.client.luau/applySprint; give a nudge
		local dir = getMoveDirection()
		if dir.Magnitude > 0 then
			r.AssemblyLinearVelocity = Vector3.new(
				dir.X * Config.WALK_SPEED,
				r.AssemblyLinearVelocity.Y,
				dir.Z * Config.WALK_SPEED
			)
		end
	end
end

local function startSlide()
	local hum = humanoid
	local r = root
	local char = character
	if not hum or not r or not char then
		return
	end
	if sliding or ledgeGrabbing or movementLocked() then
		return
	end
	if os.clock() - lastSlideEnd < Config.SLIDE_COOLDOWN then
		return
	end
	if not isGrounded(hum) then
		return
	end
	local dir = getMoveDirection()
	if dir.Magnitude < 0.1 then
		return
	end
	dir = dir.Unit

	local function getFacingDirection(): Vector3
		local camera = Workspace.CurrentCamera
		if camera then
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.1 then
				return flat.Unit
			end
		end
		local look = r.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.1 then
			return flat.Unit
		end
		return dir
	end

	setSliding(true)
	slideDirection = getFacingDirection()
	hum.AutoRotate = false

	local startTime = os.clock()
	task.spawn(function()
		while sliding and os.clock() - startTime < Config.SLIDE_DURATION do
			if not humanoid or humanoid ~= hum or movementLocked() then
				break
			end
			if not isGrounded(hum) then
				break
			end
			-- steer slide by where the player is facing (camera), not WASD movement keys
			slideDirection = getFacingDirection()
			r.CFrame = CFrame.new(r.Position, r.Position + slideDirection)
			local flatVel = slideDirection * Config.SLIDE_SPEED
			r.AssemblyLinearVelocity = Vector3.new(flatVel.X, r.AssemblyLinearVelocity.Y, flatVel.Z)
			RunService.Heartbeat:Wait()
		end
		endSlide()
	end)
end

local function trySlideJump(): boolean
	local hum = humanoid
	local r = root
	if not hum or not r then
		return false
	end
	if not sliding then
		return false
	end
	-- Jump out of slide with preserved/boosted forward momentum.
	local dir = slideDirection
	if dir.Magnitude < 0.1 then
		dir = getMoveDirection()
	end
	if dir.Magnitude < 0.1 then
		local look = r.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
	end
	if dir.Magnitude > 0 then
		dir = dir.Unit
	else
		dir = Vector3.zero
	end

	setSliding(false)
	lastSlideEnd = os.clock()
	hum.AutoRotate = true
	hum.Jump = false
	hum:ChangeState(Enum.HumanoidStateType.Jumping)

	local horizontalSpeed = Config.SLIDE_SPEED + Config.SLIDE_JUMP_BOOST
	local launchVel =
		Vector3.new(dir.X * horizontalSpeed, Config.SLIDE_JUMP_POWER, dir.Z * horizontalSpeed)
	r.AssemblyLinearVelocity = launchVel
	-- Reapply shortly after to override default humanoid jump impulse.
	task.delay(0.05, function()
		if root == r and humanoid == hum and not movementLocked() then
			hum.Jump = false
			r.AssemblyLinearVelocity = Vector3.new(
				launchVel.X,
				math.max(r.AssemblyLinearVelocity.Y, launchVel.Y),
				launchVel.Z
			)
		end
	end)

	canDoubleJump = true
	hasDoubleJumped = false
	return true
end

local function tryWallJump(): boolean
	local hum = humanoid
	local r = root
	local char = character
	if not hum or not r or not char then
		return false
	end
	if ledgeGrabbing or isGrounded(hum) then
		return false
	end
	local wallNormal = findWall()
	if not wallNormal then
		return false
	end
	local away = Vector3.new(wallNormal.X, 0, wallNormal.Z)
	if away.Magnitude > 0 then
		away = away.Unit
	end
	local vel = away * Config.WALL_JUMP_PUSH + Vector3.new(0, Config.WALL_JUMP_POWER, 0)
	r.AssemblyLinearVelocity = vel
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	canDoubleJump = true
	hasDoubleJumped = false
	return true
end

local function onJumpAction(allowWallJump: boolean)
	local hum = humanoid
	local r = root
	local char = character
	if not hum or not r or not char then
		return
	end
	if movementLocked() then
		return
	end

	-- If hanging on a ledge, press jump again to climb up (mantle).
	if ledgeGrabbing then
		climbLedge()
		return
	end

	-- Slide-jump momentum: jump while sliding
	if sliding then
		if trySlideJump() then
			return
		end
	end

	-- Try to grab a ledge when moving into it
	if tryLedgeGrab() then
		return
	end

	-- Air actions
	if not isGrounded(hum) then
		-- Wall jump (when allowed for this input)
		if allowWallJump and tryWallJump() then
			return
		end

		-- Double jump
		if canDoubleJump and not hasDoubleJumped then
			hasDoubleJumped = true
			local moveDir = getMoveDirection()
			local vx = moveDir.X * (Config.WALK_SPEED * 0.6)
			local vz = moveDir.Z * (Config.WALK_SPEED * 0.6)
			r.AssemblyLinearVelocity = Vector3.new(vx, Config.DOUBLE_JUMP_POWER, vz)
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end

local function bindCharacter(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid") :: Humanoid
	root = char:WaitForChild("HumanoidRootPart") :: BasePart
	canDoubleJump = false
	hasDoubleJumped = false
	setSliding(false)
	ledgeGrabbing = false
	player:SetAttribute("LedgeGrabbing", false)
	lastSlideEnd = 0
	slideDirection = Vector3.zero

	humanoid.StateChanged:Connect(function(_, newState)
		if
			newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.Running
			or newState == Enum.HumanoidStateType.RunningNoPhysics
		then
			canDoubleJump = true
			hasDoubleJumped = false
			if sliding and not isGrounded(humanoid :: Humanoid) then
				endSlide()
			end
		elseif
			newState == Enum.HumanoidStateType.Freefall
			or newState == Enum.HumanoidStateType.Jumping
		then
			if sliding then
				endSlide()
			end
		end
	end)

	-- Reset double jump availability when leaving ground without jumping (e.g. walk off)
	task.spawn(function()
		while character == char and humanoid and humanoid.Parent do
			if isGrounded(humanoid) then
				canDoubleJump = true
				hasDoubleJumped = false
			end
			task.wait(0.2)
		end
	end)
end

if player.Character then
	bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)

-- ensure attribute reflects state
player:SetAttribute("Sliding", false)

local function getSlideKey(): Enum.KeyCode
	local s = (Settings :: any).state
	if s and typeof(s.slideKey) == "EnumItem" then
		return s.slideKey
	end
	return Enum.KeyCode.C
end

local function getWallJumpKey(): Enum.KeyCode
	local s = (Settings :: any).state
	if s and typeof(s.wallJumpKey) == "EnumItem" then
		return s.wallJumpKey
	end
	return Enum.KeyCode.Space
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if movementLocked() then
		return
	end
	if input.KeyCode == getSlideKey() then
		startSlide()
		return
	end
	-- Rebindable wall jump key: handle here when not Space (Space is handled via JumpRequest).
	local wj = getWallJumpKey()
	if input.KeyCode == wj and wj ~= Enum.KeyCode.Space then
		if ledgeGrabbing then
			climbLedge()
			return
		end
		if tryWallJump() then
			return
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	-- Allow wall jump via jump request only when wall-jump key is bound to Space (default).
	local allowWallJump = getWallJumpKey() == Enum.KeyCode.Space
	onJumpAction(allowWallJump)
end)

-- Stop slide/ledge grab if movement lock engages
player:GetAttributeChangedSignal("MenuMovementLocked"):Connect(function()
	if movementLocked() then
		if sliding then
			endSlide()
		end
		if ledgeGrabbing then
			releaseLedge(true)
		end
	end
end)
