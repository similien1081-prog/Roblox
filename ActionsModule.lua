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
		-- Check if player has coffee beans
		local backpack = player:FindFirstChild("Backpack")
		local character = player.Character

		local hasCoffeeBean = (backpack and backpack:FindFirstChild("CoffeeBean")) or 
			(character and character:FindFirstChild("CoffeeBean"))

		if not hasCoffeeBean then
			return false, "You need coffee beans!"
		end

		return true
	end,

	execute = function(player, part)
		local machine = part.Parent
		local backpack = player:FindFirstChild("Backpack")
		local character = player.Character

		local coffeeBeanTool = (backpack and backpack:FindFirstChild("CoffeeBean")) or 
			(character and character:FindFirstChild("CoffeeBean"))

		if coffeeBeanTool then
			print(player.Name .. " added coffee beans to " .. part.Name)
			KeyActionLib:PlayCoffe()
			--task.wait(0.2)
			coffeeBeanTool:Destroy() -- Remove the item

			machine:SetAttribute("IsProcessing", true)

			task.delay(3, function()
				machine:SetAttribute("IsProcessing", false)
				machine:SetAttribute("HasEspresso", true)
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
		local machine = part

		if machine:GetAttribute("HasEspresso") then
			print(player.Name .. " collected espresso from " .. part.Name)

			local espresso = game.ServerStorage:FindFirstChild("Espresso")
			if espresso then
				local clone = espresso:Clone()
				clone.Parent = player.Backpack
			end

			machine:SetAttribute("HasEspresso", false)
		end
	end
}

return ActionsModule
