-- Optimized HoverModule with hold duration support + performance improvements
local HoverModule = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- Modules
local InteractionRegistry = require(ReplicatedStorage:WaitForChild("InteractionRegistry"))

-- Constants
local MAX_DISTANCE = 7
local INTERACT_TAG = "Interactable"
local PROGRESS_UPDATE_RATE = 1/30 -- 30 FPS for progress bar updates

-- DEFAULT COLORS
local DEFAULT_ACTION_TEXT_COLOR = Color3.fromRGB(213, 213, 213)
local DEFAULT_OBJECT_TEXT_COLOR = Color3.fromRGB(217, 217, 217)
local DEFAULT_LABEL_COLOR = Color3.fromRGB(255, 255, 255)

-- State
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local currentTarget = nil
local mousePosition = Vector2.new(0, 0)
local currentActions = {}
local actionRows = {}
local processingTimers = {}
local partStates = {}
local attributeConnections = {}
local feedbackActive = false
local lastProgressUpdate = 0

-- Hold state management (OPTIMIZED)
local holdState = {
	active = false,
	action = nil,
	row = nil,
	startTime = 0,
	duration = 0,
	progressConnection = nil,
	keyHeld = nil,
	target = nil
}

-- Success Sound
local successSound = Instance.new("Sound")
successSound.SoundId = "rbxassetid://876939830"
successSound.Volume = 0.5
successSound.Parent = SoundService

-- UI References
local Screengui = player:WaitForChild("PlayerGui"):WaitForChild("MouseInteractUI")
local mainFrame = Screengui:WaitForChild("Main")
local actionText = mainFrame:WaitForChild("ActionText")
local objectText = mainFrame:WaitForChild("ObjectText")
local rowsFrame = mainFrame:WaitForChild("Rows")
local RowTemplate = mainFrame:WaitForChild("RowTemplate")
local UIListLayout = mainFrame:WaitForChild("UIListLayout")

-- Initialize
RowTemplate.Visible = false

local function updateProgressBar(row, progress)
	if not row then return end
	local imageFrame = row:FindFirstChild("ImageFrame")
	if not imageFrame then return end

	local fill = imageFrame:FindFirstChild("ProgressFill")
	if not fill then return end

	-- Skip redundant updates (less than 1% change)
	local currentProgress = fill.Size.Y.Scale
	if math.abs(currentProgress - progress) < 0.01 then return end

	fill.Size = UDim2.new(1, 0, progress, 0)
	fill.Position = UDim2.new(0, 0, 1, 0)
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Visible = progress > 0
end

local function clearProgressBar(row)
	if not row then return end
	local imageFrame = row:FindFirstChild("ImageFrame")
	if not imageFrame then return end

	local fill = imageFrame:FindFirstChild("ProgressFill")
	if fill then
		fill.Size = UDim2.new(1, 0, 0, 0)
		fill.Position = UDim2.new(0, 0, 1, 0)
		fill.AnchorPoint = Vector2.new(0, 1)
		fill.Visible = false -- FIXED: Force invisible
	end
end

local function highlightRowDuringHold(row, enable)
	if not row then return end
	local label = row:FindFirstChild("Label")
	local yellow = Color3.fromRGB(255, 193, 40)

	if enable then
		-- Highlight yellow
		if label then
			label.TextColor3 = yellow
		end
	else
		-- Restore to default white
		if label then
			label.TextColor3 = DEFAULT_LABEL_COLOR
		end
	end
end

local function stopHoldAction(completed)
	if not holdState.active then return end

	if holdState.progressConnection then
		holdState.progressConnection:Disconnect()
		holdState.progressConnection = nil
	end

	if holdState.row then
		highlightRowDuringHold(holdState.row, false)

		-- Clear progress bar immediately regardless of completion
		clearProgressBar(holdState.row)
	end

	holdState.active = false
	holdState.action = nil
	holdState.row = nil
	holdState.keyHeld = nil
	holdState.target = nil
	holdState.startTime = 0
	holdState.duration = 0
end

-- Helper Functions
local function clearRows()
	for _, child in ipairs(rowsFrame:GetChildren()) do
		if child:IsA("Frame") and child ~= RowTemplate then
			child:Destroy()
		end
	end
	actionRows = {}
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

local function createRow(actionData, defaultLabelColor)
	local row = RowTemplate:Clone()
	row.Name = "Row_" .. tostring(getActionRowCount() + 1)

	local keyLabel = row:FindFirstChild("Key")
	local actionLabel = row:FindFirstChild("Label")

	if keyLabel then 
		keyLabel.Text = actionData.key.Name or ""
	end

	if actionLabel then 
		actionLabel.Text = actionData.label or ""
		local labelColor = actionData.labelColor or defaultLabelColor or DEFAULT_LABEL_COLOR
		actionLabel.TextColor3 = labelColor
	end

	row.Visible = true
	row.Parent = rowsFrame

	actionRows[actionData.label] = row

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

local function getUIDataForHover(target)
	local interactionType = target:GetAttribute("InteractionType")
	if not interactionType then return nil end

	return InteractionRegistry:GetUIData(interactionType, player, target)
end

local function getActionsForInteraction(target)
	local interactionType = target:GetAttribute("InteractionType")
	if not interactionType then return nil end

	return InteractionRegistry:GetAvailableActions(interactionType, player, target)
end

local function setupAttributeListener(target)
	if attributeConnections[target] then
		for _, connection in ipairs(attributeConnections[target]) do
			connection:Disconnect()
		end
		attributeConnections[target] = nil
	end

	local connections = {}

	local targetConnection = target.AttributeChanged:Connect(function(attributeName)
		if currentTarget == target then
			HoverModule:ShowUI(target)
		end
	end)
	table.insert(connections, targetConnection)

	if target.Parent then
		local parentConnection = target.Parent.AttributeChanged:Connect(function(attributeName)
			if currentTarget == target then
				HoverModule:ShowUI(target)
			end
		end)
		table.insert(connections, parentConnection)
	end

	local cleanupConnection = target.AncestryChanged:Connect(function()
		if not target:IsDescendantOf(workspace) then
			if attributeConnections[target] then
				for _, conn in ipairs(attributeConnections[target]) do
					conn:Disconnect()
				end
				attributeConnections[target] = nil
			end

			if processingTimers[target] then
				task.cancel(processingTimers[target])
				processingTimers[target] = nil
			end

			partStates[target] = nil
		end
	end)
	table.insert(connections, cleanupConnection)

	attributeConnections[target] = connections
end

function HoverModule:ShowUI(target)
	if not target or not isInRange(target) then
		self:HideUI()
		return
	end

	local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
	local isSitting = humanoid and humanoid.Sit
	local allowWhileSitting = target:GetAttribute("CanInteractWhileSitting")

	if isSitting and not allowWhileSitting then
		self:HideUI()
		return
	end

	local data = getUIDataForHover(target)
	if not data then
		self:HideUI()
		return
	end

	local partState = partStates[target] or {}

	if partState.isProcessing then
		actionText.Text = partState.processingText or data.actionText
		objectText.Text = partState.hideObjectText and "" or data.objectText
		rowsFrame.Visible = not partState.hideRows
		mainFrame.Visible = true
		clearRows()
		currentActions = {}
		return
	end

	if partState.postProcessState then
		actionText.Text = partState.postProcessState.actionText or data.actionText
		objectText.Text = partState.postProcessState.objectText or data.objectText
		currentActions = partState.postProcessState.actions or {}
	else
		actionText.Text = data.actionText or target.Name
		objectText.Text = data.objectText or ""
		currentActions = getActionsForInteraction(target) or {}
	end

	local actionTextColor = data.actionTextColor or DEFAULT_ACTION_TEXT_COLOR
	actionText.TextColor3 = actionTextColor

	local objectTextColor = data.objectTextColor or DEFAULT_OBJECT_TEXT_COLOR
	objectText.TextColor3 = objectTextColor

	if objectText.Text == "" then
		objectText.Visible = false
	else
		objectText.Visible = true
	end

	if #currentActions == 0 then
		if data.showUIWithoutActions then
			mainFrame.Visible = true
			rowsFrame.Visible = false
			setupAttributeListener(target)
			return
		end

		self:HideUI()
		return
	end

	clearRows()

	local defaultLabelColor = data.labelColor

	for _, action in ipairs(currentActions) do
		createRow(action, defaultLabelColor)
	end

	rowsFrame.Visible = true
	mainFrame.Visible = true

	setupAttributeListener(target)
end

function HoverModule:HideUI()
	mainFrame.Visible = false
	clearRows()
	currentTarget = nil
	currentActions = {}

	stopHoldAction(false)

	for target, connections in pairs(attributeConnections) do
		for _, connection in ipairs(connections) do
			if connection then
				connection:Disconnect()
			end
		end
	end
	attributeConnections = {}
end

function HoverModule:FlashHideShowAction(actionLabel)
	local row = actionRows[actionLabel]
	if not row then return end
	feedbackActive = true

	local label, image = row:FindFirstChild("Label"), row:FindFirstChild("ImageFrame")
	local origLabel, origImg = label and label.TextColor3, image and image.ImageColor3
	local yellow = Color3.fromRGB(255, 193, 40)
	local origSize, origAnchor, origPos = image and image.Size, image and image.AnchorPoint, image and image.Position

	if label then label.TextTransparency = 1 end
	if image then image.ImageTransparency = 1 end

	task.delay(0.08, function()
		if label then label.TextColor3, label.TextTransparency = yellow, 0 end
		if image then
			local centerPos = UDim2.new(origPos.X.Scale + (0.5 - origAnchor.X) * origSize.X.Scale, origPos.X.Offset + (0.5 - origAnchor.X) * origSize.X.Offset,
				origPos.Y.Scale + (0.5 - origAnchor.Y) * origSize.Y.Scale, origPos.Y.Offset + (0.5 - origAnchor.Y) * origSize.Y.Offset)
			image.AnchorPoint, image.Position, image.ImageColor3, image.ImageTransparency = Vector2.new(0.5, 0.5), centerPos, yellow, 0
			image.Size = UDim2.new(origSize.X.Scale * 0.7, origSize.X.Offset * 0.7, origSize.Y.Scale * 0.7, origSize.Y.Offset * 0.7)
		end

		task.delay(0.08, function()
			if label and origLabel then label.TextColor3 = origLabel end
			if image and origImg then
				image.ImageColor3, image.AnchorPoint, image.Position, image.Size = origImg, origAnchor, origPos, origSize
			end
			feedbackActive = false
		end)
	end)
end

function HoverModule:UpdatePosition(position)
	if mainFrame.Visible then
		mainFrame.Position = UDim2.new(0, position.X + 25, 0, position.Y + 80)
	end
end

function HoverModule:PlaySuccessSound()
	if successSound then
		successSound:Play()
	end
end

function HoverModule:CompleteAction(target, action)
	self:PlaySuccessSound()
	self:FlashHideShowAction(action.label)

	if action.onActivate then
		task.delay(0.16, function()
			local success, result = pcall(function()
				return action.onActivate(player, target)
			end)

			if not success then
				warn("Action onActivate failed:", result)
				return
			end

			local state = result

			if not state then
				return
			end

			if action.callback then
				action.callback(player, target)
			end

			partStates[target] = {
				isProcessing = true,
				processingText = state.processingText,
				hideObjectText = state.hideObjectText,
				hideRows = state.hideRows,
			}

			if processingTimers[target] then
				task.cancel(processingTimers[target])
				processingTimers[target] = nil
			end

			self:ShowUI(target)

			local thePart = target
			processingTimers[thePart] = task.spawn(function()
				task.wait(state.processingDuration or 0)
				if partStates[thePart] then
					partStates[thePart].isProcessing = false
					partStates[thePart] = {
						postProcessState = state.postProcessState,
					}
					if currentTarget == thePart then
						HoverModule:ShowUI(thePart)
					end
				end
				processingTimers[thePart] = nil
			end)
		end)
	else
		if action.callback then
			action.callback(player, target)
		end
	end
end

function HoverModule:StartHoldAction(target, action, row)
	if holdState.active then
		stopHoldAction(false)
	end

	if not target or not action or not row then
		warn("Invalid hold action parameters")
		return
	end

	holdState.active = true
	holdState.action = action
	holdState.row = row
	holdState.keyHeld = action.key
	holdState.target = target
	holdState.startTime = tick()
	holdState.duration = action.holdDuration
	lastProgressUpdate = 0

	-- ADDED: Highlight label during hold
	highlightRowDuringHold(row, true)

	updateProgressBar(row, 0)

	-- Use Heartbeat for better performance (more consistent than RenderStepped)
	holdState.progressConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not holdState.active then 
			stopHoldAction(false)
			return 
		end

		-- Throttle updates to 30 FPS
		local now = tick()
		if now - lastProgressUpdate < PROGRESS_UPDATE_RATE then
			return
		end
		lastProgressUpdate = now

		-- Validate target still exists and is in range
		if not holdState.target or not isInRange(holdState.target) then
			stopHoldAction(false)
			return
		end

		local elapsed = now - holdState.startTime
		local progress = math.clamp(elapsed / holdState.duration, 0, 1)

		updateProgressBar(holdState.row, progress)

		if progress >= 1 then
			local completedTarget = holdState.target
			local completedAction = holdState.action
			stopHoldAction(true)
			self:CompleteAction(completedTarget, completedAction)
		end
	end)
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if feedbackActive then return end
	if not currentTarget then return end
	if partStates[currentTarget] and partStates[currentTarget].isProcessing then return end
	if #currentActions == 0 then return end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode

		for _, action in ipairs(currentActions) do
			if action.key == key then
				if isInRange(currentTarget) then
					local row = actionRows[action.label]

					if action.holdDuration and action.holdDuration > 0 then
						HoverModule:StartHoldAction(currentTarget, action, row)
					else
						HoverModule:CompleteAction(currentTarget, action)
					end
				end
				break
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if holdState.active and holdState.keyHeld == input.KeyCode then
			stopHoldAction(false)
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		mousePosition = Vector2.new(mouse.X, mouse.Y)
		HoverModule:UpdatePosition(mousePosition)
	end
end)

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
			if not isInRange(target) then
				HoverModule:HideUI()
			end
		end
	else
		if currentTarget then
			HoverModule:HideUI()
		end
	end

	-- Auto-cancel hold if out of range (additional safety check)
	if holdState.active and holdState.target and not isInRange(holdState.target) then
		stopHoldAction(false)
	end
end)

player.CharacterRemoving:Connect(function()
	HoverModule:HideUI()
	stopHoldAction(false)
end)

return HoverModule
