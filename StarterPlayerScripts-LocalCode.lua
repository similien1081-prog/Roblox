-- Updated LocalCode with modular interaction system
local Players = game:GetService("Players")

-- Modules
local HoverModule = require(script.Parent.HoverModule)
local KeyActionLib = require(script.Parent.KeyActionLib)

-- The HoverModule now handles everything:
-- - On hover: Shows UI with actions (lazy-loads interaction module)
-- - On interact: Executes the action callback
-- No need for manual OnActionTriggered callback anymore!

-- Optional: Add a success sound/feedback when interaction completes
