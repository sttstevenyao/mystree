-- StarterPlayerScripts/MystreeClient/Purchase (ModuleScript)
-- The one way the client buys anything with Robux, and the one place prices come from.
--  * Purchase.buy(key): asks the server ("Buy"), which checks the offer (one-time, already owned,
--    paid random items where PolicyService restricts them) and opens the Roblox prompt itself. Id 0
--    products are free test grants in Studio. Returns ok, message (message is nil for a prompt).
--  * Purchase.price(key): "R$123" from MarketplaceService:GetProductInfoAsync (regional pricing and
--    Roblox Plus discounts), falling back to the Config price until it arrives or while the Id is 0.
--  * Purchase.label(textObj, key, format): keeps a label's price text live ("Get  R$%s").

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)

local Purchase = {}

local live = {} -- key -> Robux price from Roblox
local labels = setmetatable({}, { __mode = "k" }) -- text object -> { Key, Format }
local asked = {}

local function defOf(key)
	local pass = Config.Gamepasses[key]
	return pass or Config.Products[key], pass ~= nil
end

local function refreshLabels(key)
	for obj, l in pairs(labels) do
		if l.Key == key and obj.Parent then
			obj.Text = string.format(l.Format, Format.Commas(Purchase.robux(key)))
		end
	end
end

local function fetch(key)
	local def, isPass = defOf(key)
	if asked[key] or not def or def.Id == 0 then
		return
	end
	asked[key] = true
	task.spawn(function()
		for attempt = 1, 3 do
			local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, def.Id,
				isPass and Enum.InfoType.GamePass or Enum.InfoType.Product)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				live[key] = info.PriceInRobux
				refreshLabels(key)
				return
			end
			task.wait(attempt * 2)
		end
	end)
end

-- the price in Robux (a number): live when known, else Config's
function Purchase.robux(key)
	fetch(key)
	local def = defOf(key)
	return live[key] or (def and def.Price) or 0
end

function Purchase.price(key)
	return "R$" .. Format.Commas(Purchase.robux(key))
end

function Purchase.label(obj, key, format)
	format = format or "R$%s"
	labels[obj] = { Key = key, Format = format }
	obj.Text = string.format(format, Format.Commas(Purchase.robux(key)))
end

function Purchase.buy(key)
	if not defOf(key) then
		return false, "That isn't on sale."
	end
	local ok, msg = Net.invoke("Buy", key)
	return ok == true, msg
end

return Purchase
