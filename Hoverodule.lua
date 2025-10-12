local HoverModule = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

-- Constants
local MAX_DISTANCE = 12
local INTERACT_TAG = "Interactable"

-- State
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local currentTarget = nil
local mousePosition = Vector2.new(0, 0)
local currentActions = {}  -- Store current actions for key handling
local actionRows = {}

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

local function getActionRowCount()
	local count = 0
	for _, child in ipairs(rowsFrame:GetChildren()) do
		if child:IsA("Frame") and child ~= RowTemplate and child.Visible then
			count = count + 1
		end
	end
	return count
end

local function createRow(actionData, callback)
	local row = RowTemplate:Clone()
	row.Name = "Row_" .. tostring(getActionRowCount() + 1)

	local keyLabel = row:FindFirstChild("Key")
	local actionLabel = row:FindFirstChild("Label")

	if keyLabel then keyLabel.Text = actionData.key or "" end
	if actionLabel then actionLabel.Text = actionData.label or "" end

	row.Visible = true
	row.Parent = rowsFrame

	actionRows[actionData.identifier] = row


	return row
end

local function isInRange(target)
	if not target then return false end

	local character = player.Character
	if not character then return false end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end

	return (humanoidRootPart.Position - target.Position).Magnitude <= MAX_DISTANCE
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

	actionText.Text = target:GetAttribute("ActionText") or target.Name
	objectText.Text = target:GetAttribute("ObjectText") or ""

	clearRows()
	currentActions = buildActionsFromAttributes(target)

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

	local rowHeight = 28
	local headerHeight = 56 
	local visibleRowCount = #currentActions
	local totalRowsHeight = visibleRowCount * rowHeight
	local newFrameHeight = math.min(headerHeight + totalRowsHeight, 300) 

	mainFrame.Size = UDim2.new(0, 360, 0, newFrameHeight)
	rowsFrame.Size = UDim2.new(1, -12, 0, totalRowsHeight)

	local rowIndex = 0
	for _, row in ipairs(rowsFrame:GetChildren()) do
		if row ~= RowTemplate and row.Visible then
			row.Position = UDim2.new(0, 0, 0, rowIndex * rowHeight)
			rowIndex += 1
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

-- Clamp UI to screen bounds

function HoverModule:FlashHideShowAction(actionIdentifier)
	local row = actionRows[actionIdentifier]
	if not row then return end

	local function getField(name) return row:FindFirstChild(name) end
	local label, image = getField("Label"), getField("ImageFrame")
	local origLabel, origImg = label and label.TextColor3, image and image.ImageColor3
	local yellow = Color3.fromRGB(255, 193, 40)

	if label then label.TextColor3 = yellow end
	if image then image.ImageColor3 = yellow end

	delay(0.08, function()
		row.Visible = false
		delay(0.08, function()
			row.Visible = true
			if label and origLabel then label.TextColor3 = origLabel end
			if image and origImg then image.ImageColor3 = origImg end

		end)
	end)
end

function HoverModule:UpdatePosition(position)
	if mainFrame.Visible then
		mainFrame.Position = UDim2.new(0, position.X + 32, 0, position.Y + 38)
	end
end

function HoverModule:TriggerAction(target, actionIdentifier)
	if self.OnActionTriggered then
		self.OnActionTriggered(target, actionIdentifier)
	end
	self:FlashHideShowAction(actionIdentifier)

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
		mousePosition = Vector2.new(mouse.X, mouse.Y)
		HoverModule:UpdatePosition(mousePosition)
	end
end)

-- Mouse movement detection using Mouse.Target
RunService.RenderStepped:Connect(function()
	local target = mouse.Target

	if target and CollectionService:HasTag(target, INTERACT_TAG) then
		if target ~= currentTarget then
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
