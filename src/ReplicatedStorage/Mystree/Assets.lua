-- ReplicatedStorage/Mystree/Assets (ModuleScript)
-- The asset registry. Every model the game shows comes through Assets.get(kind, id, ...).
-- Art pass: put a finished model at ReplicatedStorage.MystreeAssets.<Kind>.<Id> and it is used
-- instead of the Builders placeholder, with no code change. Conventions for real art:
--   Tree:      MystreeAssets.Tree.Stage1..Stage5 (pivot at the trunk base, a part named "Hit" where chips fly)
--   Weapon:    MystreeAssets.Weapon.<Class>_<Rarity> or .<Class> (PrimaryPart "Handle" with a "Grip" attachment)
--   Gear:      MystreeAssets.Gear.<Slot>_<Rarity> or .<Slot> (UI previews for armour and jewellery)
--   Decor:     MystreeAssets.Decor.<Id> (pivot at the ground centre, front -Z, inside Config.Decor[Id].Radius)
--   Axe:       MystreeAssets.Axe.Axe
--   Mob:       MystreeAssets.Mob.<MobId> (HumanoidRootPart + Humanoid, body welded)
--   Companion: MystreeAssets.Companion.<Id> · Mount: MystreeAssets.Mount.<Id> (a part named "Seat")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builders = require(ReplicatedStorage.Mystree.Builders)

local Assets = {}

local function art(kind, name)
	local root = ReplicatedStorage:FindFirstChild("MystreeAssets")
	local folder = root and root:FindFirstChild(kind)
	local m = folder and folder:FindFirstChild(name)
	return m and m:Clone()
end

function Assets.Tree(stage, cf)
	local m = art("Tree", "Stage" .. stage)
	if m then
		m:PivotTo(cf)
		m:SetAttribute("Stage", stage)
		return m
	end
	return Builders.Tree(stage, cf)
end

function Assets.Weapon(class, rarity)
	return art("Weapon", class .. "_" .. rarity) or art("Weapon", class) or Builders.Weapon(class, rarity)
end

-- Any gear item for UI previews: weapons use the weapon model, the rest a gear icon model
function Assets.Gear(item)
	if item.Slot == "Weapon" then
		return Assets.Weapon(item.Class or "Sword", item.R)
	end
	return art("Gear", item.Slot .. "_" .. item.R) or art("Gear", item.Slot) or Builders.GearIcon(item.Slot, item.R)
end

function Assets.Decor(id)
	return art("Decor", id) or Builders.Decor(id)
end

function Assets.Axe()
	return art("Axe", "Axe") or Builders.Axe()
end

function Assets.Mob(id, cf)
	local m = art("Mob", id)
	if m then
		m:PivotTo(cf)
		return m
	end
	return Builders.Mob(id, cf)
end

function Assets.Companion(id)
	return art("Companion", id) or Builders.Companion(id)
end

function Assets.Mount(id)
	return art("Mount", id) or Builders.Mount(id)
end

return Assets
