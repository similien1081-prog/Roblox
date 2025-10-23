-- ServerScriptService.InteractHandler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local InteractRemote = ReplicatedStorage:FindFirstChild("InteractRemote")
local InteractValidate = ReplicatedStorage:FindFirstChild("InteractValidate")
local ActionsModule = require(ReplicatedStorage:WaitForChild("Actions"))

-- Shared validation logic
local function validateRequest(player, part, actionName)
	if not part or not part.Parent then return false, "Invalid part" end
	if not player.Character then return false, "No character" end

	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false, "No HumanoidRootPart" end

	-- Check distance (anti-exploit)
	if (humanoidRootPart.Position - part.Position).Magnitude > 12 then
		return false, "Too far away"
	end

	-- Check if action exists
	local action = ActionsModule[actionName]
	if not action then
		return false, "Action not found"
	end

	-- If action has a validate function, use it
	if action.validate then
		return action.validate(player, part)
	end

	-- No validate function means always allowed
	return true
end

-- Handle validation requests
InteractValidate.OnServerInvoke = function(player, part, actionName)
	return validateRequest(player, part, actionName)
end

-- Handle action execution
InteractRemote.OnServerEvent:Connect(function(player, part, actionName)
	-- Validate first
	local success, errorMessage = validateRequest(player, part, actionName)

	if not success then
		warn(player.Name .. " failed validation: " .. (errorMessage or "Unknown"))
		return
	end

	-- Execute the action
	local action = ActionsModule[actionName]
	if action and action.execute then
		action.execute(player, part)
	else
		warn("Action '" .. actionName .. "' has no execute function!")
	end
end)
