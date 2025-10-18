-- ModuleScript with reusable utilities
local KeyActionLib = {}

local SoundService = game:GetService("SoundService")

-- Create success sound
local successSound = SoundService.Sound
local CoffeeSound = SoundService.Coffe

function KeyActionLib:PlaySuccess()
	successSound:Play()
end

function KeyActionLib:PlayCoffe()
	CoffeeSound:Play()
end

function KeyActionLib:PlayAnimation(character, animationId)
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator")
		-- Play animation logic
	end
end

function KeyActionLib:ToggleObject(object, duration)
	local initialState = object.CanCollide
	object.CanCollide = not initialState
	task.wait(duration)
	object.CanCollide = initialState
end

return KeyActionLib
