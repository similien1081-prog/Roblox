local HoverModule = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- Modules
local InteractionData = require(ReplicatedStorage:WaitForChild("InteractionData"))

-- Constants
local MAX_DISTANCE = 12
local INTERACT_TAG = "Interactable"

-- State
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local currentTarget = nil
local mousePosition = Vector2.new(0, 0)
local currentActions = {}
local actionRows = {}
local processingTimers = {}
local partStates = {}

-- Success Sound
local successSound = Instance.new("Sound")
successSound.SoundId = "rbxassetid://876939830" -- Change to your sound ID
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

local function createRow(actionData)
	local row = RowTemplate:Clone()
	row.Name = "Row_" .. tostring(getActionRowCount() + 1)

	local keyLabel = row:FindFirstChild("Key")
	local actionLabel = row:FindFirstChild("Label")

	if keyLabel then keyLabel.Text = actionData.key.Name or "" end
	if actionLabel then actionLabel.Text = actionData.label or "" end

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

local function getInteractionData(target)
	local interactionType = target:GetAttribute("InteractionType")
	if not interactionType then return nil end

	return InteractionData[interactionType]
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

	local data = getInteractionData(target)
	if not data then
		self:HideUI()
		return
	end

	local partState = partStates[target] or {}

	-- If processing, show processing state
	if partState.isProcessing then
		actionText.Text = partState.processingText or data.actionText
		objectText.Text = partState.hideObjectText and "" or data.objectText
		rowsFrame.Visible = not partState.hideRows
		mainFrame.Visible = true
		clearRows()
		currentActions = {}
		return
	end

	-- Use post-process state if available, otherwise use default
	if partState.postProcessState then
		actionText.Text = partState.postProcessState.actionText or data.actionText
		objectText.Text = partState.postProcessState.objectText or data.objectText
		currentActions = partState.postProcessState.actions or data.actions
	else
		actionText.Text = data.actionText or target.Name
		objectText.Text = data.objectText or ""
		currentActions = data.actions or {}
	end

	if objectText.Text == "" then
		objectText.Visible = false
	else
		objectText.Visible = true
	end

	if #currentActions == 0 then
		self:HideUI()
		return
	end

	clearRows()

	for _, action in ipairs(currentActions) do
		createRow(action)
	end

	rowsFrame.Visible = true
	mainFrame.Visible = true
end

function HoverModule:HideUI()
	mainFrame.Visible = false
	clearRows()
	currentTarget = nil
	currentActions = {}
end

function HoverModule:FlashHideShowAction(actionLabel)
	local row = actionRows[actionLabel]
	if not row then return end
	local function getField(name) return row:FindFirstChild(name) end
	local label, image = getField("Label"), getField("ImageFrame")
	local origLabel, origImg = label and label.TextColor3, image and image.ImageColor3
	local yellow = Color3.fromRGB(255, 193, 40)

	if label then label.TextTransparency = 1 end
	if image then image.ImageTransparency = 1 end

	task.delay(0.08, function()
		if label then 
			label.TextColor3 = yellow
			label.TextTransparency = 0 
		end
		if image then 
			image.ImageColor3 = yellow
			image.ImageTransparency = 0 
		end

		task.delay(0.08, function()
			if label and origLabel then label.TextColor3 = origLabel end
			if image and origImg then image.ImageColor3 = origImg end
		end)
	end)
end

function HoverModule:UpdatePosition(position)
	if mainFrame.Visible then
		mainFrame.Position = UDim2.new(0, position.X + 25, 0, position.Y + 38)
	end
end

function HoverModule:PlaySuccessSound()
	if successSound then
		successSound:Play()
	end
end

function HoverModule:TriggerAction(target, action)
	-- Play success sound
	self:PlaySuccessSound()

	-- Flash the action row FIRST
	self:FlashHideShowAction(action.label)

	-- Check if action has onActivate (needs validation/state changes)
	if action.onActivate then
		task.delay(0.16, function() -- Wait for flash animation to complete
			-- Run onActivate FIRST (this validates)
			local state = action.onActivate(player, target)

			-- If state is nil, validation failed - DON'T fire callback
			if not state then
				return -- Stop here, don't execute callback or change state
			end

			-- Validation passed! NOW fire the callback to server
			if action.callback then
				action.callback(player, target)
			end

			-- Set processing state
			partStates[target] = {
				isProcessing = true,
				processingText = state.processingText,
				hideObjectText = state.hideObjectText,
				hideRows = state.hideRows,
			}

			-- Cancel any existing timer for this part
			if processingTimers[target] then
				task.cancel(processingTimers[target])
				processingTimers[target] = nil
			end

			-- Refresh UI to show processing state
			self:ShowUI(target)

			-- Set up timer to end processing state
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
		-- No onActivate means no validation needed, fire callback immediately
		if action.callback then
			action.callback(player, target)
		end
	end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if not currentTarget then return end
	if partStates[currentTarget] and partStates[currentTarget].isProcessing then return end
	if #currentActions == 0 then return end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode
		-- Check current actions for matching key
		for _, action in ipairs(currentActions) do
			if action.key == key then
				if isInRange(currentTarget) then
					HoverModule:TriggerAction(currentTarget, action)
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
