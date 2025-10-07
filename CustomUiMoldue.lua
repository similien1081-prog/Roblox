local CustomUI = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- UI References
local player = Players.LocalPlayer
local Screengui = player:WaitForChild("PlayerGui"):WaitForChild("MouseInteractUI")
local mainFrame = Screengui:WaitForChild("Main")
local actionText = mainFrame:WaitForChild("ActionText")
local objectText = mainFrame:WaitForChild("ObjectText")

function CustomUI:ShowUI(actionName, objectName)
	-- Update UI text
	actionText.Text = actionName or ""
	objectText.Text = objectName or ""
	mainFrame.Visible = true
end

function CustomUI:HideUI()
	mainFrame.Visible = false
	actionText.Text = ""
	objectText.Text = ""
end

function CustomUI:UpdatePosition(mousePosition)
	if mainFrame.Visible then
		mainFrame.Position = UDim2.new(0, mousePosition.X + 16, 0, mousePosition.Y + 16)
	end
end

-- Optional: Add animation tweens for smooth showing/hiding
function CustomUI:ShowWithAnimation()
	mainFrame.Transparency = 1
	mainFrame.Visible = true

	local tween = TweenService:Create(mainFrame, 
		TweenInfo.new(0.2), 
		{Transparency = 0}
	)
	tween:Play()
end

function CustomUI:HideWithAnimation()
	local tween = TweenService:Create(mainFrame, 
		TweenInfo.new(0.2), 
		{Transparency = 1}
	)
	tween:Play()
	tween.Completed:Connect(function()
		mainFrame.Visible = false
	end)
end

return CustomUI
