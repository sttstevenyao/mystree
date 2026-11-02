-- ServerScriptService/Mystree/Services/DailyService (ModuleScript)
-- Daily gift with a 7-day streak (Config.Daily.Gifts). Missing a day restarts the streak at day 1.
-- Days are UTC day numbers. The client shows the gift card when Daily.Day < today.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)

local DailyService = {}
local S

local function today()
	return os.time() // 86400
end

function DailyService.claim(player)
	local data = S.DataService.data(player)
	local d = data.Daily
	local now = today()
	if d.Day == now then
		return false, "Come back tomorrow for the next gift!"
	end
	d.Streak = (d.Day == now - 1) and (d.Streak + 1) or 1
	d.Day = now
	local gift = Config.Daily.Gifts[((d.Streak - 1) % #Config.Daily.Gifts) + 1]
	S.DataService.grant(player, gift)
	S.DataService.push(player)
	return true, string.format("Day %d gift claimed!", d.Streak), gift
end

function DailyService.Init(services)
	S = services
	workspace:SetAttribute("UtcDay", today())
end

function DailyService.Start()
	S.Remotes.Handle("ClaimDaily", 1, {}, DailyService.claim)
	while true do
		task.wait(30)
		workspace:SetAttribute("UtcDay", today())
	end
end

return DailyService
