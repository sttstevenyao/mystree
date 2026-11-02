# Mystree: Kickoff (Game Design Document)

Back to [[00 Start Here]] · Code: [[CHO/README]] · Place: **CHO** (placeId 98987233689526, group 35685335)

Idle-cultivation RPG inspired by Nobody's Adventure Chop Chop. Chop your own Divine Tree for gear, take the gear into a shared Hunting Ground, and bring materials back to grow the tree so it drops rarer gear.

> **Exceptions to the Playbook for this game (user's GDD, 2026-10-26):**
> - **Art is semi-realistic, high-fidelity fantasy (Deepwoken-like).** No studs, no low-poly, no blocky parts. This replaces [[04 Visual Style & Art Direction]]'s "bright low-poly with studs" for Mystree only. Everything else in 04 (lighting per biome, colour per meaning, no default sparkle) still applies.
> - **UI is a jade-and-parchment xianxia kit** taken from the user's Chop Chop reference screenshots, not [[17 UI Style - Bubbly Cartoon]]. The feel rules in 17 and [[07 UI & UX]] still apply: pop in/out, huge numbers, mobile first, sounds on every button, a dim backdrop, tab slides.
> - Phase 1 art is **asset slots + clean placeholders**. Every model is fetched through `Assets.get(kind, id)`. Drop a real model into `ReplicatedStorage.MystreeAssets.<Kind>.<Id>` and it replaces the placeholder with no code change.

## 1. Pitch
- Title: **Mystree** (user's pick).
- Fantasy: a cultivator who chops a magic tree for loot, gets stronger, and hunts monsters under blood moons.
- Audience: 10–16, mobile first (landscape phones), also PC/console.
- Quality peers: Deepwoken (world and art), Nobody's Adventure Chop Chop (loop and UI), Anime Vanguards/Pet Sims (drop dopamine). Unlike Chop Chop, the gear is used in real-time 3D combat with friends.

## 2. Loops
| Layer | Mystree |
|---|---|
| **Moment** (seconds) | Strike the tree: crack sound, camera kick, wood chips, a gear drop pops out with a rarity-coloured beam. Swing at a mob: hit-stop, damage number, flash. |
| **Session** (minutes) | Burn your Peaches on the tree, equip upgrades, dismantle the rest for Scraps, run out of Peaches, hunt for Sap/Peaches/EXP, come back and grow the tree. |
| **Long** (days) | Tree Level 1 → 30 (rarer drops each level), player Level and Realm, a full Divine set, Mythic companions, endgame mounts. |

- **Collection**: gear (8 slots × 3 weapon classes × 7 rarities), companions (8 at launch), mounts (5).
- **Rarity ladder and colours** (same everywhere): Common (beige) · Uncommon (green) · Rare (blue) · Epic (purple) · Legendary (orange) · Mythic (red) · Divine (prismatic).
- **Showing off**: CP banner over your head, your tree's size and glow on the hub plot, weapon in hand, companion at your side, mount, Inspect panel, server-wide drop announcements.
- **Variable-ratio rewards** (Playbook 01, required):
  - Every chop already rolls gear rarity (the main variable reward).
  - On top of the guaranteed drop: **Lucky Chip** 15% (bonus Scraps worth 2–6 chops of dismantle value), **Sap Burst** 3% (tree materials), **Golden Bough** 0.3% (a guaranteed Epic-or-better drop, gold beam, server announcement).
  - Mobs: 15% chance of 1–3 Peaches, rare material drops, elites always drop a gear piece at your tree's rarity +1 tier odds.
  - Day/night events (5% each switch) are server-wide jackpots.

## 3. Economy
- **Peaches** (chop energy, from the reference): 1 Peach = 1 chop = 1 gear drop. **The tree is stingy early (user, 2026-10-26)**, so Peaches mostly come from quests and hunting:
  - The cap is 60 at tree Lv 1, +8 per level (VIP +50).
  - Regrowth is 1 every 24 s at Lv 1, 0.6 s faster per level, down to 6 s.
  - Quests (main and side) are the main Peach source. Mobs, dailies and packs also give them.
- **Lucky chop bonuses** start rare and scale with the tree (chance = base + per level, capped):
  - Scraps: 3% → 14%.
  - Peaches: 2% → 8%.
  - Sap: 1% → 4%.
  - Their amounts grow with tree level.
- **Max rarity by tree level:**
  - Lv 1 Rare, Lv 2 Epic, Lv 6 Legendary, Lv 12 Mythic, Lv 20 Divine.
  - Nothing goes above the cap: not luck, Incense, the Fortune Charm, elite shifts or the Golden Bough (which drops at the current cap).
- **Scraps** (soft currency): from dismantling gear and from mobs. Spent on tree growth.
- **Tree materials**: Sap (mob drop), Heartwood (elites/bosses), Blood Amber (Bloodmoon only), Sunstone (Golden Hour only). Milestone tree levels (every 5th) need an event material, so events matter.
- **Spirit Stones** (premium-ish): dailies, bosses, Robux packs. Spent on companion summons.
- **Mount Shards**: elites and bosses. Unlock mounts.
- **Tree growth** L→L+1: Scraps `80·1.55^(L-1)`, Sap from L2, Heartwood from L6, plus a growth timer `30·L²` s (L10 = 50 min, L29 = 7 h). **Instant Growth** finishes it (paid shortcut where the wait is).
- **Gear power**: item level = tree level × 2 ± 1, stat = base × (1 + 0.18·ilvl) × rarity mult (1, 1.4, 2, 2.9, 4.2, 6.2, 9) × 0.9–1.1. Substats by rarity (0–4).
- **Combat Power** = 4·ATK + 0.35·HP + 5·DEF + 1.5·AGL, scaled by crit/lifesteal substats and companion % buffs.
- **First 10 minutes**: free 200 Peaches → first Rare within ~30 chops → equip 6–8 pieces → Tree L2 at ~3 min (60 s growth, free in the tutorial) → walk to Willow Fields → first boar kills → Level 5 → first elite at the 5-minute switch.

## 4. Monetization

**Added 2026-10-26, each offered where the wait is (client `Offers`):**
- **Starter Pack** (R$99, one time): 300 Peaches, 500 Spirit Stones, 60 Mount Shards and a Rare+ weapon. It's offered for 24 h after the tutorial with a countdown pill, and its card opens once by itself.
- **Out of Peaches:** a sheet with the 3 Peach packs, plus "Do quests (free)".
- **Short on Spirit Stones** when summoning: the Spirit Stones shop tab, policy-checked.
- **Bag full:** the Big Bag pass, plus "Open Bag".
- **Death in the Hunting Grounds:** "Revive Here" (R$19) on the fall screen.
- **Side quests all done today:** "Fresh Orders" (R$29) from the villager.
- **New passes:**
  - Fortune Charm (R$399): Epic+ odds ×1.5 forever, still capped by tree level.
  - Celestial Steed (R$499): an exclusive mount with speed 44.

 (Ids in `Config.Products` / `Config.Gamepasses`, 0 = Studio test grant)
- **Gamepasses**: VIP (R$299: +20% Scraps, +50 Peach cap, gold tag), Swift Auto (R$199: auto-chop twice as fast), Big Bag (R$149: +150 bag slots), Twin Spirits (R$349: a second companion slot).
- **Products**: Instant Growth (R$49, offered on the tree timer), Peach Basket 60 / Peach Crate 200 / Peach Cart 600, Lucky Incense (30 min of playtime: Epic+ odds ×2), Call Bloodmoon (R$249: the next night is a Bloodmoon, announced with the buyer's name), 6 Spirit Stone packs (hidden where `PolicyService` restricts paid random items).

## 5. World and style
- **Own island (user, 2026-10-26):** every player chops on their own small floating island (8 islands in a ring 300 studs around the Village, random on join, a name board, a gate back to the Village). Falling off sends you home. Island customization is the next feature to pick.
- **Hub: Mystree Village.** A bigger floating island with a cobbled plaza, a MY ISLAND gate and a HUNTING GROUNDS gate. Server size 8.
- **Hunting Grounds** (one shared floating strip, three zones by level): Willow Fields (Lv 1+), Mossy Ruins (Lv 15+), Ashen Gorge (Lv 35+).
- **No terrain (user, 2026-10-26).** Everything is parts: grass discs, ellipsoid rock undersides (Sphere SpecialMesh), ground slabs. Sculpted island meshes can replace them later (`MystreeAssets.Island.Island`).
- **Lighting**: soft painterly daylight (Future, Atmosphere, warm sun), cool blue night, Bloodmoon red, Golden Hour gold. Swapped by a 5-minute server cycle.
- **Hero assets that need real art** (asset slots exist): Divine Tree (5 growth stages), 3 weapon classes × 7 rarity looks, 8 armour pieces, 8 mobs + 4 bosses, 8 companions, 5 mounts, chopping axe, loot beam, hub props.

## 5b. Tutorial (built 2026-10-26, Playbook 17)
Five real progression steps, each paid on the server (`TutorialService`, `Config.Tutorial`), about 2 minutes in total:
1. Chop your tree 5 times: +150 Scraps.
2. Grow the tree (Tree, then Grow; the first growth is free and instant): +60 Peaches.
3. Summon your first Spirit (new players start with 100 Spirit Stones): +200 Scraps.
4. Go to the Hunting Grounds: +40 Peaches.
5. Defeat 3 monsters: a guaranteed Epic-or-better weapon with the full beam moment.

On screen:
- A goal pill at the top (step, goal, progress, reward, Skip with a confirm tap).
- A spotlight that dims everything but the button to press, with a bouncing arrow. It follows into windows (Grow, the Summon tab, Summon x1).
- A world arrow and a glowing path to your tree, the Hunting Grounds gate or the nearest monster.

Rules:
- Wording follows the device (Tap / Click / Press).
- Steps already done count the moment they come up.
- Saves from before the tutorial existed (tree Lv 4+ or 30+ kills) skip it.
- Afterwards, the bottom goal pill takes over.
- Admin: "Restart tutorial".

## 5c. Village, NPCs and quests (2026-10-26)
- **The Village** is the safe social hub: no fighting. You get there with the Village travel button or gates.
- **NPCs:** Elder Mo, Lan the herbalist, Rui the huntress, Old Bao the blacksmith, Sister Hua the spirit keeper (opens Spirits), Fat Jin the merchant (opens Shop) and Kai the stable hand (opens Mounts). Talk with the custom prompt.
- **Main story, Chapter 1 "The Withering Root"** (13 steps, `Config.MainQuests`):
  - Something is feeding on the Divine Tree. You chop, bring sap, grow the tree, and defeat the Tusk Boar and bandits.
  - Then you bring heartwood, survive a Bloodmoon, defeat the Bone Knight, and finally the Godly Skeleton.
  - It starts when the tutorial's last step sends you to Elder Mo. Each step is handed in to an NPC, which moves the story on.
- **Side quests:** each villager has their own (`Config.SideQuests`), once per day, up to 3 at a time. Rewards scale with the tree. Fresh Orders resets them.

## 5d. Island customization and leaderboards (2026-10-26)
- **Decor** (`Config.Decor`): 14 pieces bought with Scraps (never Robux, Playbook 03).
  - They go into a stash and are placed on your island with a ghost preview: snap, rotate, green or red for valid spots. Edit mode moves, rotates or stores a piece.
  - Rules: max 30 pieces; keep clear of the tree, your stand, the gate and the board; spaced by footprint.
  - Buff pieces (strongest per kind counts): Incense Burner and Spirit Crystal add Drop Luck (+3% / +6%), the Peach Altar makes Peaches grow 15% faster, the Golden Toad gives +10% Scraps.
- **Themes** (`Config.Themes`): Spring Meadow, Cherry Blossom (tree Lv 4), Bamboo Grove (3,000 Scraps), Autumn Maple (Lv 8), Frost Peak (12,000 Scraps), Moonlit Garden (10 Blood Amber), Ember Isle (Lv 15 + 10 Sunstone). Each repaints the island and the tree's leaves and adds drifting petals, leaves, snow or embers.
- **Visit and like:** visit any island from the Island window, the leaderboard or Inspect. Like it once per day; likes are saved on the owner, who gets a toast.
- **Leaderboard:** a custom player list (the "Players N" pill top-right, dropdown with CP, level, tree level and likes; tap a row to inspect or visit) replaces Roblox's default list. A Leaderboards window shows the global top 25 for Combat Power, Tree Level and Island Likes (OrderedDataStores, in-server fallback without API access).
- **Tutorial is quiet:** while it runs only tutorial messages show. No other toasts, server alerts, level-up banners, daily or welcome cards, offers or Starter Pack; errors about your own action still show. The daily gift and Starter Pack follow once it's done, one window at a time.

## 5e. UI v2 and physical interactables (2026-10-26)
- **Main quests are accepted or declined:**
  - The first is offered by Elder Mo; each later step by the NPC you handed the last one to.
  - Declined steps stay offered (with a "!" over that NPC). The tutorial's last step is "accept Elder Mo's quest".
- **HUD layout v2:**
  - **Top-left:** currencies, materials, then the main-quest tracker.
  - **Top-right:** clock, then the Players leaderboard pill in the corner, with the Starter Pack pill under them.
  - **Top-centre:** notifications.
  - **Left:** a travel strip and a 2×3 menu (Quests, Bag, Decor, Spirits, Mounts, Shop).
  - **Bottom-left:** the player card with portrait, CP, level/realm, health bar with damage trail, EXP, tree progress and stats.
  - **Bottom-centre:** the chop dock, only on your own island.
- **Removed duplicates:**
  - the sidebar Tree tile (the dock's Tree button and the tree prompt remain);
  - the right-side gear panel (equipped gear is in the Bag);
  - Combat's extra Village button.
- **Smooth:** HUD groups fade and slide (`UI.fade` on CanvasGroups), toasts drop in and fade out at the top, and windows pop with a background blur.
- **Physical interactables** (`Interact` prompts with `Opens`/`Tab`):
  - Village: Summoning Shrine (Spirits > Summon), merchant stall (Shop), stable (Mounts), quest board (Quest Log), and a Hall of Fame with 3 boards showing the live top lists (Leaderboards).
  - Island: storage chest (Bag), decor workbench (Decor), and "Tend tree" on F at your tree (Tree window).
  - Every tree has a billboard with the owner and level; yours also shows growth progress.

## 5f. Summon cinematic (2026-10-26, Sol's RNG style)
`SummonFx` plays every summon full screen.
- **Roll:** a slot ticks through spirit names in rarity colours, slowing down with rising clicks, and lands on the result. Tap to skip.
- **Reveal, by rarity:**
  - **Rare:** a flash and a card pop.
  - **Epic:** a darker screen, purple rays and a shake.
  - **Legendary:** a black suspense beat with a heartbeat, a light pillar, a typed "LEGENDARY!" title, gold rays, a big burst and a hard shake.
  - **Mythic:** 3 heartbeats, a red sky tint, shockwave rings and a glitching title.
  - **Divine:** shifting rainbow colours and a white-out flash.
- **Card:** the spirit in 3D, its rarity, "1 in N" odds, and NEW or +1 star. An x10 pull plays the best one's cinematic, then all ten cards.
- **Everyone sees it:** Epic+ pulls light a beam over the summoner. Mythic+ pulls get a server-wide banner and Legendary a toast, both with the odds.
- **Admin "Summon preview"** plays any tier without granting anything.

## 5g. The Wildlands, mutations and forging (2026-10-26)
- **Open world.** The Hunting Grounds are one round landmass (`Config.Wild`, radius 560) with a camp in the middle and six zones as 60° sectors around it, so players can go in any order: Willow Fields 1-10, Bamboo Thicket 10-20, Mossy Ruins 20-30, Misty Marsh 30-40, Ashen Gorge 40-50, Frost Peak 50-60. Grass trails separate the zones; each has its own ground, dressing, entry sign and boss arena (`Builders.Wildlands`).
- **Per zone:** camps (and night camps), a 5-minute Elite, a Rare (`Zone.Rare`, 0.6% of camp spawns, one alive, server alert) and a Boss always in its arena (back 8 min after it falls).
- **Mythic beasts** (Heavenly Qilin, Nine-Tailed Fox, Thunder Roc): a roll every 2 min (3.5%), one alive, anywhere in the Wildlands, gone after 15 min if nobody fights it. Each drops its relic, the only way to Mythforge.
- **Mutations** (`Config.Mutations`): Spirit-Touched (extra Spirit Stones), Ancient (bigger, mossy, extra Heartwood), Blood-Corrupted (Bloodmoon only, Blood Amber) and Gilded (Golden Hour only, Sunstone and 3x Scraps). Normal mobs only; tinted body, glow and a tag on the plate.
- **Armour sets** (`Config.ArmorSets`): each zone's boss always drops a piece, its rare by chance, at the set's fixed rarity (Rare to Mythic). 2- and 4-piece bonuses.
- **Forging** (Old Bao's forge in the Village, client `Forge`): dismantling weapons gives Iron Shards / Spirit Steel / Star Shards by rarity. Forge tiers make a chosen class at Rare to Mythic (max main stats, +1 substat, locked by the tree's max rarity). Mythforge: Qilin's Verdict, Foxfire Fang and Stormtalon (Divine, from 3 relics + materials), each with a proc (every Nth hit, area damage, Foxfire heals).
- **Balance note:** mob growth was softened (HP 1.105^L) so level 60 is beatable; not yet tuned in long play.

## 5h. Wildlands balance, levels 40-60 (2026-10-26)
- **Tools:** `CHO/tools/dev/balance_sim.lua` (fight times, kills per level, hours of hunting per tree growth) and `balance_solve.lua` (base HP/Dmg from targets). Both run in Studio Edit. They model the median of 9 rolled players: tree = level / 2, best-of-60 gear per slot, one companion, sword combo DPS, 1%/s regen plus lifesteal, 75% of mob hits landing.
- **Targets** (kill time / time to die): normals 3.5 s / 75 s, elites 30 / 55 s and rares 45 / 75 s at the zone's start level; bosses 120 / 150 s at its top level; Mythic beasts 240 / 180 s at its top level. Levelling: about 60 normal kills per level. Hunting should pay a tree growth in about its growth timer.
- **Result (Ashen Gorge, Frost Peak):** normals 2-5 s (yetis tanky, hounds/leopards/wisps fragile), elites ~30 s, rares ~45 s, bosses 120 s / ~145 s at the top level and unbeatable solo at zone entry. 54-87 kills per level. A growth is paid in 1.3-3.1 h of hunting against 3.3-5.2 h timers.
- **Mythic beasts** have their own HP growth (`Growth = { HP = 1.055 }`, `Rules.mobStats`), so they take ~240-285 s solo at any zone's top level; damage follows the normal curve (base 77 / 62 for the fox).
- **Play check (level 40, tree 20, Legendary/Mythic gear, Frost Wolf; a 4-Skeleton camp in Ashen Gorge):** at the solved damage the whole camp aggroed at once and killed the character in 13 s. The sim models one mob at a time. Normal-mob damage is now 75% of the solved value. The camp then cleared in 16-18 s with HP bottoming at 71-82%. The sword's sweep hits clumped mobs together, so camps go faster than the sim predicts; normals could take more HP if this feels too easy. Mythic beasts: 240 s to kill / 180 s to die (Ashen Gorge) and 285 / 192 s (Frost Peak), using their own growth (`Growth = { HP = 1.055, Dmg = 1.077 }`).
- **Camp re-fit, second pass:** the earlier Play checks used a test character still wearing the Divine Qilin's Verdict. With reference gear (ATK about 2,080, HP 19.8K, a Mythic greatsword), Ashen Gorge normals are now HP 1.4x the solve and damage about 0.56x. Clearing a 4-Skeleton camp then took 8-25 s with the HP low point at 71-77%. One run at slightly higher damage died in 10 s, so results swing a lot with pull size and how many mobs the sweep catches. Frost Peak got the same factors and wasn't bot-tested (`tools/dev/camp_fight.lua` does it).
- **Known gap:** zones 1-40 (and world-event mobs) were not re-tuned. In this model they are far easier (normals die in under 1 s and nothing can kill the player), so Ashen Gorge is a difficulty cliff until they get the same pass.

## 6. Retention
- Daily gift streak (Peaches, Spirit Stones), offline Peach refill and tree growth.
- Day/night every 5 min. Night: 5% Bloodmoon (Blood Skeletons, boss Godly Skeleton, Blood Amber). Day: 5% Golden Hour (Golden Stags, boss Jade Tortoise, Sunstone). Big top-of-screen alert server-wide.
- Elites spawn in every zone on each switch, with communal scaling (more players nearby = tankier, everyone who hits it gets their own drops).
- Social: Inspect anyone (CP, gear, companion, mount), drop announcements, plots visible to all.
- Later: Tribulation (realm breakthrough fight), bounties, guilds, leaderboards by CP.

## 7. Tech
- Services: Remotes, Data, Stats, Gear, Tree, World, Mob, Combat, Companion, Mount, Monetization, Daily, AntiCheat, Admin.
- Remotes: see `ReplicatedStorage.Mystree.Net`.
- Save schema v1: see `DataService` template (DataStore `Mystree_v1`, key `p_<UserId>`).
- Admin panel (F2 / bottom-right in Studio): peaches, scraps, materials, tree level, roll rarity, set level, start Bloodmoon/Golden Hour, skip cycle, spawn elite/boss, give companion/mount, reset save.

## 8. Milestones
1. Core loop playable with placeholders (this pass).
2. Economy tuned for the first hour.
3. **Art pass**: tree, weapons, mobs, companions, mounts (semi-realistic).
4. Monetization + tutorial.
5. Mobile/gamepad pass, launch checklist.
