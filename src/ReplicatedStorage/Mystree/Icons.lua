-- ReplicatedStorage/Mystree/Icons (ModuleScript)
-- The custom icon set (drawn by CHO/tools/icons/make_icons.py, uploaded to group 35685335 with
-- upload.py; image ids in tools/icons/images.json). Icons.Ids[key] is an rbxassetid; client UI uses
-- UI.icon(parent, key, size). Material and currency keys match Config.Materials / Config.Currencies.

local Icons = {}

Icons.Ids = {
	admin = "rbxassetid://133846650285213",
	auto = "rbxassetid://90609254320159",
	bag = "rbxassetid://110169289802446",
	blood_amber = "rbxassetid://118482599317491",
	boss = "rbxassetid://94407963666144",
	chop = "rbxassetid://102538831472981",
	close = "rbxassetid://120450114402227",
	cp = "rbxassetid://99636253145709",
	daily = "rbxassetid://103243360427809",
	decor = "rbxassetid://85146252073869",
	elite = "rbxassetid://73213561921992",
	exp = "rbxassetid://79249901449251",
	forge = "rbxassetid://72587205528305",
	fox_tail = "rbxassetid://122324144310207",
	heart = "rbxassetid://102874607337297",
	heartwood = "rbxassetid://129762880466321",
	hunt = "rbxassetid://112278784474420",
	incense = "rbxassetid://75661403322947",
	iron_shard = "rbxassetid://115802549550194",
	island = "rbxassetid://136912816437371",
	leaderboard = "rbxassetid://111815409918137",
	lock = "rbxassetid://86549194828136",
	mount_shard = "rbxassetid://84127889743306",
	mounts = "rbxassetid://113503920366812",
	mythic = "rbxassetid://76200750759168",
	peach = "rbxassetid://110937186676447",
	qilin_horn = "rbxassetid://79839054612241",
	quests = "rbxassetid://70985315028108",
	revive = "rbxassetid://119180212772306",
	roc_feather = "rbxassetid://136377543929981",
	sap = "rbxassetid://79857001719667",
	scraps = "rbxassetid://101486793542294",
	set = "rbxassetid://113267311736858",
	settings = "rbxassetid://135169991914100",
	shop = "rbxassetid://133757086178467",
	spirit_steel = "rbxassetid://74561388271525",
	spirit_stone = "rbxassetid://125335593527460",
	spirits = "rbxassetid://74529669993820",
	star = "rbxassetid://83006702605318",
	star_shard = "rbxassetid://101874413946022",
	starter = "rbxassetid://135148506163628",
	summon = "rbxassetid://125714261876445",
	sunstone = "rbxassetid://119008825942419",
	tree = "rbxassetid://91656145742411",
	tutorial = "rbxassetid://96743061707224",
	village = "rbxassetid://134335663912333",
}

-- Config keys -> icon keys
Icons.Alias = {
	Spirit = "spirit_stone",
	Scraps = "peach", -- the main currency is shown as Peaches (save key "Scraps")
	Peaches = "peach",
	MountShards = "mount_shard",
	Sap = "sap",
	Heartwood = "heartwood",
	BloodAmber = "blood_amber",
	Sunstone = "sunstone",
	Exp = "exp",
	CP = "cp",
	IronShard = "iron_shard",
	SpiritSteel = "spirit_steel",
	StarShard = "star_shard",
	QilinHorn = "qilin_horn",
	FoxTail = "fox_tail",
	RocFeather = "roc_feather",
}

function Icons.get(key)
	return Icons.Ids[key] or Icons.Ids[Icons.Alias[key] or ""] or ""
end

return Icons
