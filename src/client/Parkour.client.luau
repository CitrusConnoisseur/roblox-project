--!strict
-- Parkour mechanics: slide, double jump, wall jump, mantle/ledge climb.
-- Works with sprinting (Main.client.luau) and respects menu movement lock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil

local canDoubleJump = false
local hasDoubleJumped = false
local sliding = false
local lastSlideEnd = 0

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

local function tryMantle(): boolean
	local r = root
	local hum = humanoid
	local char = character
	if not r or not hum or not char then
		return false
	end
	if movementLocked() then
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

	local targetPos = Vector3.new(
		downHit.Position.X,
		ledgeY + hum.HipHeight + (r.Size.Y / 2) + 0.2,
		downHit.Position.Z
	)
	-- move slightly onto the ledge
	targetPos += forward * 1.2

	hum:ChangeState(Enum.HumanoidStateType.Climbing)
	r.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	r.CFrame = CFrame.new(targetPos, targetPos + forward)
	r.AssemblyLinearVelocity =
		Vector3.new(forward.X * Config.MANTLE_BOOST, 6, forward.Z * Config.MANTLE_BOOST)
	task.delay(0.15, function()
		if humanoid == hum then
			hum:ChangeState(Enum.HumanoidStateType.Running)
		end
	end)
	return true
end

local function endSlide()
	if not sliding then
		return
	end
	sliding = false
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
	if sliding or movementLocked() then
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

	sliding = true
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
			-- keep sliding forward along ground
			local flatVel = dir * Config.SLIDE_SPEED
			r.AssemblyLinearVelocity = Vector3.new(flatVel.X, r.AssemblyLinearVelocity.Y, flatVel.Z)
			RunService.Heartbeat:Wait()
		end
		endSlide()
	end)
end

local function onJumpRequest()
	local hum = humanoid
	local r = root
	local char = character
	if not hum or not r or not char then
		return
	end
	if movementLocked() then
		return
	end

	-- Try mantle first when moving into a ledge
	if tryMantle() then
		canDoubleJump = true
		hasDoubleJumped = false
		return
	end

	-- Wall jump when airborne and near a wall
	if not isGrounded(hum) then
		local wallNormal = findWall()
		if wallNormal and hasDoubleJumped == false then
			-- allow wall jump (and refresh double jump feel)
			local away = Vector3.new(wallNormal.X, 0, wallNormal.Z)
			if away.Magnitude > 0 then
				away = away.Unit
			end
			local vel = away * Config.WALL_JUMP_PUSH + Vector3.new(0, Config.WALL_JUMP_POWER, 0)
			r.AssemblyLinearVelocity = vel
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			canDoubleJump = true
			hasDoubleJumped = false
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
	sliding = false
	lastSlideEnd = 0

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
	if input.KeyCode == Config.SLIDE_KEY then
		startSlide()
	end
end)

UserInputService.JumpRequest:Connect(function()
	onJumpRequest()
end)

-- Stop slide if movement lock engages mid-slide
player:GetAttributeChangedSignal("MenuMovementLocked"):Connect(function()
	if movementLocked() and sliding then
		endSlide()
	end
end)
