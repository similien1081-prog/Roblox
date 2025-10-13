-- Actions.lua
local KeyActionLib = require(script.Parent.KeyActionLib)

local Actions = {}

Actions["Sit Down"] = function(seat)
	local player = game.Players.LocalPlayer
	if player and player.Character and player.Character:FindFirstChild("Humanoid") then
		seat:Sit(player.Character.Humanoid)
		return { hide = "Sit Down" }
	end
end

Actions["Open Door"] = function(door)
end

Actions["EnterCode"] = function(part)
	print("test")
end

return Actions
