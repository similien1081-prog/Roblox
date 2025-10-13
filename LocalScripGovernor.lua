local Players = game:GetService("Players")

-- Modules
local Actions = require(script.Parent.Actions)
local HoverModule = require(script.Parent.HoverModule)
local KeyActionLib = require(script.Parent.KeyActionLib)

-- Connect the HoverModule's action trigger to the Actions module
HoverModule.OnActionTriggered = function(target, actionIdentifier)
	local action = Actions[actionIdentifier]
	if action then
		local result = action(target) -- run the function directly and capture return value
		KeyActionLib:PlaySuccess()
		
		-- Check if the action returned a hide request
		if result and type(result) == "table" and result.hide then
			HoverModule:HideAction(result.hide)
		end
		--HoverModule:HideUI()
	else
		warn("No action found for:", actionIdentifier)
	end
end
