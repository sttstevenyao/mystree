-- ServerScriptService/Mystree/Services/MonetizationService (ModuleScript)
-- Developer products and gamepasses (Config.Products / Config.Gamepasses). Id = 0 means "not created
-- yet": a free test grant in Studio only, not on sale live (Playbook 03). Passes are mirrored to
-- player attributes "Pass_<Key>". Spirit Stone packs feed paid random summons, so they are hidden
-- where PolicyService restricts paid random items (attribute "NoPaidRandom").

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)
local Rules = require(ReplicatedStorage.Mystree.Rules)

local MonetizationService = {}
local S

function MonetizationService.hasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true
end

-- Grant a product by key. Every product resolves its target now and has a fallback, so a purchase
-- is never wasted (Instant Growth with no growth running gives Peaches, the main currency, instead).
local function grant(player, key)
	local p = Config.Products[key]
	if not p then
		return false
	end
	if key == "StarterPack" then
		-- one-time offer; a repeat receipt (rare) still grants, so a purchase is never lost.
		-- The weapon is rolled first: if anything fails, it fails before any part is granted, so
		-- the retried receipt can't hand out the currency twice.
		local data = S.DataService.data(player)
		local item = S.GearService.roll(player, { Min = p.Weapon })
		local w = Rules.rollItem(data.Tree.Level, item.R, Random.new(), "Weapon")
		data.Offers.StarterBought = true
		S.DataService.grant(player, p.Grant)
		local res = S.GearService.give(player, w)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		S.Remotes.Drop:FireClient(player, { Item = w, R = w.R, Pos = hrp and hrp.Position + Vector3.new(0, 4, 0), Equipped = res.Equipped, Dismantled = res.Dismantled, Scraps = res.Scraps, Golden = true })
		S.DataService.push(player)
		S.Remotes.notify(player, "Starter Pack unlocked! " .. p.Desc, "Purchase")
		return true
	elseif key == "Revive" then
		S.CombatService.revive(player)
		return true
	elseif key == "FreshOrders" then
		S.QuestService.freshOrders(player)
		return true
	elseif p.Grant then
		S.DataService.grant(player, p.Grant)
		S.DataService.push(player)
		S.Remotes.notify(player, string.format("%s: thank you! Granted.", p.Name), "Purchase")
		return true
	elseif key == "InstantGrowth" then
		if not S.TreeService.finishGrowth(player, true) then
			S.DataService.grant(player, { Scraps = 1200 })
			S.Remotes.notify(player, "Your tree wasn't growing, so you got 1,200 Peaches instead.", "Purchase")
		end
		return true
	elseif key == "LuckyIncense" then
		local data = S.DataService.data(player)
		local had = data.Boosts.Incense or 0
		data.Boosts.Incense = had + p.Seconds
		S.DataService.push(player)
		if had > 0 then
			S.Remotes.notify(player, string.format("Your Lucky Incense was still burning, so 30m was added: %s left!", Format.Time(data.Boosts.Incense)), "Purchase")
		else
			S.Remotes.notify(player, "Lucky Incense lit: Epic+ odds x2 for 30 minutes of playtime!", "Purchase")
		end
		return true
	elseif key == "CallBloodmoon" then
		S.WorldService.force("Bloodmoon", player.DisplayName)
		return true
	end
	return false
end

local keyById = {}
for key, p in pairs(Config.Products) do
	if p.Id ~= 0 then
		keyById[p.Id] = key
	end
end

local function setPass(player, pass, on)
	player:SetAttribute("Pass_" .. pass, on)
	if S.DataService.isLoaded(player) then
		if pass == "VIP" or pass == "BigBag" or pass == "TwinSpirits" then
			S.StatsService.refresh(player)
		elseif pass == "CelestialSteed" then
			S.MountService.checkUnlocks(player)
		end
	end
end

local function checkPasses(player)
	for pass, def in pairs(Config.Gamepasses) do
		if def.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, def.Id)
			if ok and owns then
				setPass(player, pass, true)
			end
		end
	end
	-- fail closed: if the policy can't be read, treat paid random items as restricted
	player:SetAttribute("NoPaidRandom", true)
	for attempt = 1, 3 do
		local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if ok and type(policy) == "table" and policy.ArePaidRandomItemsRestricted ~= nil then
			player:SetAttribute("NoPaidRandom", policy.ArePaidRandomItemsRestricted)
			break
		end
		task.wait(attempt)
	end
end

-- Runs the same grant as a real receipt (admin "simulate purchase")
function MonetizationService.grantProduct(player, key)
	if Config.Gamepasses[key] then
		setPass(player, key, true)
		return true
	end
	return grant(player, key)
end

function MonetizationService.Init(s)
	S = s
end

function MonetizationService.Start()
	-- Idempotent per receipt: the purchase id is stored in the save, and the purchase is only
	-- confirmed once that save succeeds, so a retry never grants twice and a crash never loses it.
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local key = keyById[info.ProductId]
		if not player or not key or not S.DataService.isLoaded(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not S.DataService.hasReceipt(player, info.PurchaseId) then
			local ok, result = pcall(grant, player, key)
			if not (ok and result) then
				warn("[MonetizationService] grant failed for " .. key .. ": " .. tostring(result))
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			S.DataService.addReceipt(player, info.PurchaseId)
			S.Remotes.effect(player, "Purchase")
		end
		if not S.DataService.saveNow(player) and not RunService:IsStudio() then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok and not owns then
			return -- the prompt said yes but Roblox says no: trust Roblox (a failed check still grants)
		end
		for pass, def in pairs(Config.Gamepasses) do
			if def.Id == passId then
				setPass(player, pass, true)
				S.Remotes.notify(player, def.Name .. " unlocked! " .. def.Desc, "Purchase")
				S.Remotes.effect(player, "Purchase")
			end
		end
	end)

	-- Every Robux purchase starts here: the server checks the offer, then opens the prompt itself,
	-- so restricted players can't be shown paid random items by a modified client.
	S.Remotes.Handle("Buy", 0.5, { "string" }, function(player, key)
		local product, pass = Config.Products[key], Config.Gamepasses[key]
		local def = product or pass
		if not def then
			return false, "That isn't on sale."
		end
		if (def.PaidRandom or key == "StarterPack") and player:GetAttribute("NoPaidRandom") ~= false then
			return false, "That offer isn't available in your region."
		end
		if pass and MonetizationService.hasPass(player, key) then
			return false, "You already own " .. def.Name .. "."
		end
		local data = S.DataService.data(player)
		if def.OneTime and data and data.Offers.StarterBought then
			return false, "You already bought the " .. def.Name .. "."
		end
		if def.Id == 0 then
			if not RunService:IsStudio() then
				return false, def.Name .. " isn't on sale yet."
			end
			MonetizationService.grantProduct(player, key)
			S.Remotes.effect(player, "Purchase")
			return true, "Studio test purchase: " .. def.Name .. " (free here, R$" .. Format.Commas(def.Price) .. " live)"
		end
		if pass then
			MarketplaceService:PromptGamePassPurchase(player, def.Id)
		else
			MarketplaceService:PromptProductPurchase(player, def.Id)
		end
		return true
	end)

	-- Studio only: products and passes with Id 0 are granted for free so everything can be tested
	S.Remotes.Handle("StudioPurchase", 0.5, { "string" }, function(player, key)
		if not RunService:IsStudio() then
			return false, "That isn't on sale yet."
		end
		local product, pass = Config.Products[key], Config.Gamepasses[key]
		if (product and product.Id == 0) or (pass and pass.Id == 0) then
			MonetizationService.grantProduct(player, key)
			S.Remotes.effect(player, "Purchase")
			local name = (pass and pass.Name) or (product and product.Name) or key
			return true, "Studio test purchase: " .. name .. " (free here, R$" .. Format.Commas((product or pass).Price) .. " live)"
		end
		return false, "Use the real purchase prompt for this one."
	end)

	Players.PlayerAdded:Connect(checkPasses)
	for _, pl in ipairs(Players:GetPlayers()) do
		task.spawn(checkPasses, pl)
	end
end

return MonetizationService
