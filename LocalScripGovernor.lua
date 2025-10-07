local Players = game:GetService("Players")

-- Modules
local Actions = require(script.Parent.Actions)
local HoverModule = require(script.Parent.HoverModule)
local KeyActionLib = require(script.Parent.KeyActionLib)

-- Connect the HoverModule's action trigger to the Actions module
HoverModule.OnActionTriggered = function(target, actionIdentifier)
	local success = Actions:Execute(target, actionIdentifier)
	if success then
		KeyActionLib:PlaySuccess()
		HoverModule:HideUI()
	end
end
