-- ServerScriptService.ActionsModule
local ActionsModule = {}
local KeyActionLib = require(script.Parent:WaitForChild("KeyActionLib"))

-- Each action is a table with validate and execute functions
-- If validate is nil, action is always allowed

ActionsModule["Sit Down"] = {
	validate = function(player, part)
		-- Always allow sitting
		print("test")
		return true
	end,

	execute = function(player, part)
		if not player.Character then return end

		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid and part:IsA("Seat") then
			part:Sit(humanoid)
			print(player.Name .. " sat down on " .. part.Name)
		end
	end
}

ActionsModule["Open Door"] = {
	-- No validate = always allowed
	execute = function(player, part)
		local door = part.Parent
		local doorPart = door:FindFirstChild("Door")

		if doorPart then
			local tweenService = game:GetService("TweenService")
			local openCFrame = doorPart.CFrame * CFrame.Angles(0, math.rad(90), 0)
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = tweenService:Create(doorPart, tweenInfo, {CFrame = openCFrame})
			tween:Play()

			print(player.Name .. " opened door: " .. part.Name)

			task.delay(3, function()
				local closeTween = tweenService:Create(doorPart, tweenInfo, {CFrame = doorPart.CFrame})
				closeTween:Play()
			end)
		end
	end
}

ActionsModule["EnterCode"] = {
	execute = function(player, part)
		local correctCode = part:GetAttribute("CorrectCode") or "1234"
		print(player.Name .. " is entering code on: " .. part.Name)
		-- Add your code verification logic here
	end
}

ActionsModule["Add"] = {
	validate = function(player, part)
		local character = player.Character
		if not character then
			return false, "You need to be in the game!"
		end
		local equippedTool = character:FindFirstChildOfClass("Tool")
		if not equippedTool or equippedTool.Name ~= "CoffeeBean" then
			return false, "You need to be holding coffee beans!"
		end
		return true
	end,
	execute = function(player, part)
		local machine = part.Parent
		local character = player.Character
		local Beam = machine.Pourer.BeamPart.Beam
		local coffeeModel = machine:FindFirstChild("CoffeePartModel")
		if coffeeModel then
			for _, childPart in pairs(coffeeModel:GetDescendants()) do
				if childPart:IsA("BasePart") then
					childPart.Transparency = 0
				end
			end
		end
		Beam.Enabled = true
		local equippedTool = character:FindFirstChildOfClass("Tool")
		if equippedTool and equippedTool.Name == "CoffeeBean" then
			print(player.Name .. " added coffee beans to " .. part.Name)
			KeyActionLib:PlayCoffe()
			equippedTool:Destroy()
			machine:SetAttribute("IsProcessing", true)
			task.delay(6, function()
				machine:SetAttribute("IsProcessing", false)
				machine:SetAttribute("HasEspresso", true)
				Beam.Enabled = false
			end)
		end
	end
}

ActionsModule["Collect"] = {
	validate = function(player, part)
		local machine = part.Parent

		if not machine:GetAttribute("HasEspresso") then
			return false, "Nothing to collect!"
		end

		return true
	end,

	execute = function(player, part)
		local machine = part.Parent
		if machine:GetAttribute("HasEspresso") then
			print(player.Name .. " collected espresso from " .. part.Name)
			
			local coffeeModel = machine:FindFirstChild("CoffeePartModel")
			if coffeeModel then
				print("FOUND")
				for _, childPart in pairs(coffeeModel:GetDescendants()) do
					if childPart:IsA("BasePart") then
						childPart.Transparency = 1
					end
				end
			end

			local espresso = game.ServerStorage:FindFirstChild("Espresso")
			if espresso then
				local clone = espresso:Clone()
				clone.Parent = player.Backpack
			end

			machine:SetAttribute("HasEspresso", false)
		end
	end
}


-- Add these to your existing ActionsModule

ActionsModule["Enter Vehicle"] = {
	validate = function(player, part)
		local vehicle = part.Parent
		if not vehicle then
			return false, "Vehicle not found!"
		end

		-- Check if vehicle is locked
		if vehicle:GetAttribute("IsLocked") then
			return false, "🔒 Vehicle is locked!"
		end

		-- Check if vehicle seat is available
		local vehicleSeat = vehicle:FindFirstChild("DriveSeat")
		if vehicleSeat and vehicleSeat.Occupant then
			return false, "Someone is already driving!"
		end

		return true
	end,

	execute = function(player, part)
		local vehicle = part.Parent
		local vehicleSeat = vehicle:FindFirstChild("DriveSeat")

		if not player.Character then return end
		local humanoid = player.Character:FindFirstChild("Humanoid")

		if vehicleSeat and humanoid then
			vehicleSeat:Sit(humanoid)
			print(player.Name .. " entered vehicle: " .. vehicle.Name)
		end
	end
}

ActionsModule["Lock Vehicle"] = {
	validate = function(player, part)
		local vehicle = part.Parent
		if not vehicle then
			return false, "Vehicle not found!"
		end

		-- Already locked?
		if vehicle:GetAttribute("IsLocked") then
			return false, "Vehicle is already locked!"
		end

		-- Optional: Check if player is the owner
		local owner = vehicle:GetAttribute("Owner")
		if owner and owner ~= player.Name then
			return false, "You don't own this vehicle!"
		end

		return true
	end,

	execute = function(player, part)
		local vehicle = part.Parent
		vehicle:SetAttribute("IsLocked", true)

		-- Optional: Play lock sound
		local lockSound = vehicle:FindFirstChild("LockSound")
		if lockSound then
			lockSound:Play()
		end

		print(player.Name .. " locked vehicle: " .. vehicle.Name)
	end
}

ActionsModule["Unlock Vehicle"] = {
	validate = function(player, part)
		local vehicle = part.Parent
		if not vehicle then
			return false, "Vehicle not found!"
		end

		-- Already unlocked?
		if not vehicle:GetAttribute("IsLocked") then
			return false, "Vehicle is already unlocked!"
		end

		-- Optional: Check if player is the owner
		local owner = vehicle:GetAttribute("Owner")
		if owner and owner ~= player.Name then
			return false, "You don't own this vehicle!"
		end

		return true
	end,

	execute = function(player, part)
		local vehicle = part.Parent
		vehicle:SetAttribute("IsLocked", false)

		-- Optional: Play unlock sound
		local unlockSound = vehicle:FindFirstChild("UnlockSound")
		if unlockSound then
			unlockSound:Play()
		end

		print(player.Name .. " unlocked vehicle: " .. vehicle.Name)
	end
}

-- Add to your existing ActionsModule

ActionsModule["Open Door"] = {
	validate = function(player, part)
		local door = part.Parent
		if not door then
			return false, "Door not found!"
		end

		-- Re-validate access on server (IMPORTANT!)
		local allowedTeams = door:GetAttribute("AllowedTeams")
		if allowedTeams then
			print("")
			if not player.Team then
				return false, "🚫 You need to be on a team!"
			end

			local hasAccess = false
			for teamName in string.gmatch(allowedTeams, "[^,]+") do
				teamName = teamName:match("^%s*(.-)%s*$") -- Trim whitespace
				if teamName == player.Team.Name then
					hasAccess = true
					break
				end
			end

			if not hasAccess then
				return false, "🚫 Your team doesn't have access!"
			end
		end

		-- Check AllowAll attribute
		local allowAll = door:GetAttribute("AllowAll")
		if allowAll == false then
			return false, "🚫 Door is locked!"
		end

		return true
	end,

	execute = function(player, part)
		local door = part.Parent
		local doorPart = door:FindFirstChild("Door")

		if doorPart then
			local TweenService = game:GetService("TweenService")

			-- Store original position
			local originalCFrame = doorPart.CFrame

			-- Open animation
			local openCFrame = doorPart.CFrame * CFrame.Angles(0, math.rad(90), 0)
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local openTween = TweenService:Create(doorPart, tweenInfo, {CFrame = openCFrame})
			openTween:Play()

			print(player.Name .. " opened secure door: " .. door.Name)

			-- Close after 3 seconds
			task.delay(3, function()
				local closeTween = TweenService:Create(doorPart, tweenInfo, {CFrame = originalCFrame})
				closeTween:Play()
			end)
		end
	end
}

return ActionsModule
