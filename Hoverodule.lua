local HoverModule = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

-- Constants
local MAX_DISTANCE = 3
local RAY_THROTTLE = 0.1
local INTERACT_TAG = "Interactable"

-- State
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local currentTarget = nil
local lastRayTime = 0
local mousePosition = Vector2.new(0, 0)
local currentActions = {}  -- Store current actions for key handling

-- UI References
local Screengui = player:WaitForChild("PlayerGui"):WaitForChild("MouseInteractUI")
local mainFrame = Screengui:WaitForChild("Main")
local actionText = mainFrame:WaitForChild("ActionText")
local objectText = mainFrame:WaitForChild("ObjectText")
local rowsFrame = mainFrame:WaitForChild("Rows")
local RowTemplate = mainFrame:WaitForChild("RowTemplate")

-- Initialize
RowTemplate.Visible = false

-- Helper Functions
local function clearRows()
	for _, child in ipairs(rowsFrame:GetChildren()) do
		if child:IsA("Frame") and child ~= RowTemplate then
			child:Destroy()
		end
	end
end

local function createRow(actionData, callback)
	local row = RowTemplate:Clone()
	row.Name = "Row_" .. tostring(#rowsFrame:GetChildren())

	local keyLabel = row:FindFirstChild("Key")
	local actionLabel = row:FindFirstChild("Label")

	if keyLabel then keyLabel.Text = actionData.key or "" end
	if actionLabel then actionLabel.Text = actionData.label or "" end

	row.Visible = true
	row.Parent = rowsFrame

	-- Set up click handling
	local button = row:FindFirstChild("ImageButton")
	if button then
		button.MouseButton1Click:Connect(callback)
	end

	return row
end

local function isInRange(target)
	if not target then return false end

	local character = player.Character
	if not character then return false end

	local humanoid = character:FindFirstChild("HumanoidRootPart")
	if not humanoid then return false end

	return (humanoid.Position - target.Position).Magnitude <= MAX_DISTANCE
end

local function buildActionsFromAttributes(target)
	local actions = {}
	local attrs = target:GetAttributes()

	-- Loop through possible actions (1-20 as per your system)
	for i = 1, 20 do
		local actionAttr = attrs["Action" .. i]
		if not actionAttr then break end

		local label = attrs["Action" .. i .. "_Label"] or actionAttr
		local key = attrs["Action" .. i .. "_Key"] or ""

		table.insert(actions, {
			identifier = actionAttr,
			label = label,
			key = key,
			index = i
		})
	end

	return actions
end

function HoverModule:ShowUI(target)
	if not target or not isInRange(target) then
		self:HideUI()
		return
	end

	-- Update main text
	actionText.Text = target:GetAttribute("ActionText") or target.Name
	objectText.Text = target:GetAttribute("ObjectText") or ""

	-- Clear existing rows
	clearRows()

	-- Build new rows from attributes and store for key handling
	currentActions = buildActionsFromAttributes(target)

	-- Only show UI if there are actions available
	if #currentActions == 0 then
		self:HideUI()
		return
	end

	for _, action in ipairs(currentActions) do
		createRow(
			action,
			function()
				if isInRange(target) then
					self:TriggerAction(target, action.identifier)
				end
			end
		)
	end
	
	local rowHeight = 28 -- Height of each row
	local headerHeight = 56 -- Height of the header section (actionText + objectText)
	local visibleRowCount = #currentActions

	-- Calculate new heights
	local totalRowsHeight = visibleRowCount * rowHeight
	local newFrameHeight = math.min(headerHeight + totalRowsHeight, 300) -- Max height of 300

	-- Update both frame sizes
	mainFrame.Size = UDim2.new(0, 360, 0, newFrameHeight)
	rowsFrame.Size = UDim2.new(1, -12, 0, totalRowsHeight)

	-- Position rows with proper spacing
	for i, row in ipairs(rowsFrame:GetChildren()) do
		if row ~= RowTemplate then
			row.Position = UDim2.new(0, 0, 0, (i-1) * rowHeight)
		end
	end

	mainFrame.Visible = true
	
end

function HoverModule:HideUI()
	mainFrame.Visible = false
	clearRows()
	currentTarget = nil
	currentActions = {}
end

function HoverModule:UpdatePosition(position)
	if mainFrame.Visible then
		mainFrame.Position = UDim2.new(0, position.X + 16, 0, position.Y + 16)
	end
end

function HoverModule:TriggerAction(target, actionIdentifier)
	if self.OnActionTriggered then
		self.OnActionTriggered(target, actionIdentifier)
	end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if not currentTarget then return end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode.Name
		-- Check current actions for matching key
		for _, action in ipairs(currentActions) do
			if action.key:upper() == key:upper() then
				if isInRange(currentTarget) then
					HoverModule:TriggerAction(currentTarget, action.identifier)
				end
				break
			end
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		mousePosition = UserInputService:GetMouseLocation()
		HoverModule:UpdatePosition(mousePosition)
	end
end)

-- Mouse movement detection with range check
RunService.RenderStepped:Connect(function()
	local now = tick()
	if now - lastRayTime < RAY_THROTTLE then return end
	lastRayTime = now

	local target = player:GetMouse().Target
	if target and CollectionService:HasTag(target, INTERACT_TAG) then
		if target ~= currentTarget then
			-- Only update if in range
			if isInRange(target) then
				currentTarget = target
				HoverModule:ShowUI(target)
			else
				HoverModule:HideUI()
			end
		else
			-- Check if existing target is still in range
			if not isInRange(target) then
				HoverModule:HideUI()
			end
		end
	else
		if currentTarget then
			HoverModule:HideUI()
		end
	end
end)

-- Cleanup
player.CharacterRemoving:Connect(function()
	HoverModule:HideUI()
end)

return HoverModule
