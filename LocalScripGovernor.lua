local Players = game:GetService("Players")

-- Modules
local Actions = require(script.Parent.Actions)
local HoverModule = require(script.Parent.HoverModule)
local KeyActionLib = require(script.Parent.KeyActionLib)

-- Connect the HoverModule's action trigger to the Actions module
HoverModule.OnActionTriggered = function(target, actionIdentifier)
	local action = Actions[actionIdentifier]
	if action then
		action(target) -- run the function directly
		KeyActionLib:PlaySuccess()
		--HoverModule:HideUI()
	else
		warn("No action found for:", actionIdentifier)
	end
end
