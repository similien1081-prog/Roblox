local Actions = {}

-- Action definitions
Actions.definitions = {
	["Steam milk (low foam)"] = {
		execute = function(target)
			print("Steaming milk with low foam for", target.Name)
			-- Add your implementation here
			return true
		end,
		condition = function(target)
			-- Add any conditions for when this action should be available
			return true
		end
	},
	["Steam milk (medium foam)"] = {
		execute = function(target)
			print("Steaming milk with medium foam for", target.Name)
			return true
		end,
		condition = function(target)
			return true
		end
	},
	["Steam milk (high foam)"] = {
		execute = function(target)
			print("Steaming milk with high foam for", target.Name)
			return true
		end,
		condition = function(target)
			return true
		end
	},
	["Steam milk (flat)"] = {
		execute = function(target)
			print("Steaming flat milk for", target.Name)
			return true
		end,
		condition = function(target)
			return true
		end
	}
}



-- Function to execute an action by identifier
function Actions:Execute(target, actionIdentifier)
	local actionData = self.definitions[actionIdentifier]
	if actionData and actionData.condition(target) then
		return actionData.execute(target)
	end
	return false
end

return Actions
