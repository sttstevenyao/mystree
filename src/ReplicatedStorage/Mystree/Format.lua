-- ReplicatedStorage/Mystree/Format (ModuleScript)
-- Number and time formatting for every label (Playbook 02: one Format module, used everywhere).

local Format = {}

function Format.Commas(n)
	local s = tostring(math.floor(n))
	local k
	repeat
		s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

-- 25K, 1.5M, 3B, with commas below 10K
function Format.Num(n)
	n = math.floor(n)
	if n >= 1e12 then
		return (string.format("%.2fT", n / 1e12):gsub("%.?0+T", "T"))
	elseif n >= 1e9 then
		return (string.format("%.2fB", n / 1e9):gsub("%.?0+B", "B"))
	elseif n >= 1e6 then
		return (string.format("%.2fM", n / 1e6):gsub("%.?0+M", "M"))
	elseif n >= 1e4 then
		return (string.format("%.1fK", n / 1e3):gsub("%.0K", "K"))
	end
	return Format.Commas(n)
end

-- 0:42 / 1:05:09
function Format.Clock(sec)
	sec = math.max(0, math.ceil(sec))
	if sec >= 3600 then
		return string.format("%d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
	end
	return string.format("%d:%02d", sec // 60, sec % 60)
end

-- 2h 14m / 5m 03s / 42s
function Format.Time(sec)
	sec = math.max(0, math.ceil(sec))
	if sec >= 3600 then
		return string.format("%dh %02dm", sec // 3600, (sec % 3600) // 60)
	elseif sec >= 60 then
		return string.format("%dm %02ds", sec // 60, sec % 60)
	end
	return sec .. "s"
end

function Format.Pct(x)
	local v = x * 100
	if v < 10 then
		return (string.format("%.1f%%", v):gsub("%.0%%", "%%"))
	end
	return string.format("%d%%", math.floor(v + 0.5))
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
function Format.Roman(n)
	return ROMAN[n] or tostring(n)
end

return Format
