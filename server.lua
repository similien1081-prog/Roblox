local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvent for client-server communication
local InteractEvent = ReplicatedStorage.

-- Handle interactions
InteractEvent.OnServerEvent:Connect(function(player, target, actionName)
	-- Verify player is close enough
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("HumanoidRootPart")
	if not humanoid then return end

	-- Verify distance
	if (humanoid.Position - target.Position).Magnitude > 10 then
		return
	end

	end
end)
