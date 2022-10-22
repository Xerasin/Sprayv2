pcall(require, "urlimage")
local CONVERTER_URL = "http://sprays.xerasin.com/getimage2.php"
local GETSIZE_URL = "http://sprays.xerasin.com/getsize.php"
local GIFINFO_URL = "http://sprays.xerasin.com/gifinfo.php"

module("spray2", package.seeall)
local _M = _M
local M = setmetatable({},{__index = function(s,k) return rawget(_M,k) end,__newindex = _M})
_M.M = M

local function URLEncode(s)
	s = tostring(s)
	local new = ""

	for i = 1, #s do
		local c = s:sub(i, i)
		local b = c:byte()
		if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or
			(b >= 48 and b <= 57) or
			c == "_" or c == "." or c == "~" then
			new = new .. c
		else
			new = new .. string.format("%%%X", b)
		end
	end

	return new
end
---------------------------------------------
-- https://github.com/Metastruct/gurl/	 --
---------------------------------------------
local URLWhiteList = {}

local TYPE_SIMPLE = 1
local TYPE_PATTERN = 2
local TYPE_BLACKLIST = 4

local function pattern(pattern)
	URLWhiteList[#URLWhiteList + 1] = {TYPE_PATTERN, "^http[s]?://" .. pattern}
end
local function simple(txt)
	URLWhiteList[#URLWhiteList + 1] = {TYPE_SIMPLE, "^http[s]?://" .. txt}
end
local function blacklist(txt)
	URLWhiteList[#URLWhiteList + 1] = {TYPE_BLACKLIST, txt}
end


simple [[www.dropbox.com/s/]]
simple [[dl.dropboxusercontent.com/]]
simple [[dl.dropbox.com/]] --Sometimes redirects to usercontent link

-- OneDrive
-- Examples: 
-- https://onedrive.live.com/redir?resid=123!178&authkey=!gweg&v=3&ithint=abcd%2cefg

simple [[onedrive.live.com/redir]]

-- Google Drive
--- Examples: 
---  https://docs.google.com/uc?export=download&confirm=UYyi&id=0BxUpZqVaDxVPeENDM1RtZDRvaTA

simple [[docs.google.com/uc]]
simple [[drive.google.com/file/d/]]
simple [[drive.google.com/u/0/uc]]
simple [[drive.google.com/open]]


-- Imgur
--- Examples: 
---  http://i.imgur.com/abcd123.xxx

simple [[i.imgur.com/]]

--[=[
-- pastebin
--- Examples: 
---  http://pastebin.com/abcdef

simple [[pastebin.com/]]
]=]

-- github / gist
--- Examples: 
---  https://gist.githubusercontent.com/LUModder/f2b1c0c9bf98224f9679/raw/5644006aae8f0a8b930ac312324f46dd43839189/sh_sbdc.lua
---  https://raw.githubusercontent.com/LUModder/FWP/master/weapon_template.txt

simple [[raw.githubusercontent.com/]]
simple [[gist.githubusercontent.com/]]
simple [[github.com/]]
simple [[www.github.com/]]

-- pomf
-- note: there are a lot of forks of pomf so there are tons of sites. I only listed the mainly used ones. --Flex
--- Examples: 
---  https://my.mixtape.moe/gxiznr.png
---  http://a.1339.cf/fppyhby.txt
---  http://b.1339.cf/fppyhby.txt
---  http://a.pomf.cat/jefjtb.txt

simple [[my.mixtape.moe/]]
simple [[a.1339.cf/]]
simple [[b.1339.cf/]]
simple [[a.pomf.cat/]]


-- TinyPic
--- Examples: 
---  http://i68.tinypic.com/24b3was.gif
pattern [[i(.+)%.tinypic%.com/]]

--[=[
-- paste.ee
--- Examples: 
---  https://paste.ee/r/J3jle
simple [[paste.ee/]]


-- hastebin
--- Examples: 
---  http://hastebin.com/icuvacogig.txt
simple [[hastebin.com/]]
]=]

-- puush
--- Examples:
---  http://puu.sh/asd/qwe.obj
simple [[puu.sh/]]

-- Steam
--- Examples:
---  http://images.akamai.steamusercontent.com/ugc/367407720941694853/74457889F41A19BD66800C71663E9077FA440664/
---  https://steamcdn-a.akamaihd.net/steamcommunity/public/images/apps/4000/dca12980667e32ab072d79f5dbe91884056a03a2.jpg
simple [[images.akamai.steamusercontent.com/]]
simple [[steamcdn-a.akamaihd.net/]]
simple [[steamcommunity.com/]]
simple [[www.steamcommunity.com/]]
simple [[store.steampowered.com/]]
blacklist [[steamcommunity.com/linkfilter/]]
blacklist [[www.steamcommunity.com/linkfilter/]]

---------------------------------------------
-- https://github.com/thegrb93/StarfallEx/ --
---------------------------------------------

-- Discord
--- Examples:
---  https://cdn.discordapp.com/attachments/269175189382758400/421572398689550338/unknown.png
---  https://images-ext-2.discordapp.net/external/UVPTeOLUWSiDXGwwtZ68cofxU1uaA2vMb2ZCjRY8XXU/https/i.imgur.com/j0QGfKN.jpg?width=1202&height=677

pattern [[cdn[%w-_]*.discordapp%.com/(.+)]]
pattern [[images-([%w%-]+)%.discordapp%.net/external/(.+)]]

-- Reddit
--- Examples:
---  https://i.redd.it/u46wumt13an01.jpg
---  https://i.redditmedia.com/RowF7of6hQJAdnJPfgsA-o7ioo_uUzhwX96bPmnLo0I.jpg?w=320&s=116b72a949b6e4b8ac6c42487ffb9ad2
---  https://preview.redd.it/injjlk3t6lb51.jpg?width=640&height=800&crop=smart&auto=webp&s=19261cc37b68ae0216bb855f8d4a77ef92b76937

simple [[i.redditmedia.com]]
simple [[i.redd.it]]
simple [[preview.redd.it]]
--[=[
-- Furry things
--- Examples:
--- https://static1.e621.net/data/8f/db/8fdbc9af34698d470c90ca6cb69c5529.jpg
]=]

simple [[static1.e621.net]]

-- ipfs
--- Examples:
--- https://ipfs.io/ipfs/QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco/I/m/Ellis_Sigil.jpg

simple [[ipfs.io]]
simple [[www.ipfs.io]]

-- neocities
--- Examples:
--- https://fauux.neocities.org/LainDressSlow.gif

pattern [[([%w-_]+)%.neocities%.org/(.+)]]

--[=[
-- Soundcloud
--- Examples:
--- https://i1.sndcdn.com/artworks-000046176006-0xtkjy-large.jpg
pattern [[(%w+)%.sndcdn%.com/(.+)]]

-- Shoutcast
--- Examples:
--- http://yp.shoutcast.com/sbin/tunein-station.pls?id=567807
simple [[yp.shoutcast.com]]

-- Google Translate API
--- Examples:
--- http://translate.google.com/translate_tts?&q=Hello%20World&ie=utf-8&client=tw-ob&tl=en
simple [[translate.google.com]]
]=]


-- END OF SHARED --


function CheckWhitelist(url)
	local out = 0x000
	for _, testPattern in pairs(URLWhiteList) do
		if testPattern[1] == TYPE_SIMPLE then
			if string.find(url, testPattern[2]) then
				out = bit.bor(out, TYPE_SIMPLE)
			end
		elseif testPattern[1] == TYPE_PATTERN then
			if string.match(url, testPattern[2]) then
				out = bit.bor(out, TYPE_PATTERN)
			end
		elseif testPattern[1] == TYPE_BLACKLIST then
			if string.find(url, testPattern[2]) then
				out = bit.bor(out, TYPE_BLACKLIST)
			end
		end
	end

	if bit.band(out, TYPE_BLACKLIST) == TYPE_BLACKLIST then return false end
	if bit.band(out, TYPE_SIMPLE) == TYPE_SIMPLE or bit.band(out, TYPE_PATTERN) == TYPE_PATTERN then return true end
	return false
end

if SERVER then
	AddCSLuaFile()
	util.AddNetworkString("Sprayv2")
	util.AddNetworkString("ClearSpray2")

	net.Receive("Sprayv2", function(len, ply)
		local sprayData = net.ReadTable()
		ply:PostSpray(sprayData or {})
	end)


	hook.Add("PlayerSpray", "Sprayv2", function(ply)
		if ply:PostSpray() then return true end
	end)


	local function addcmd()
		aowl.AddCommand({"spraymenu", "spray", "sprayv2"}, function(ply, line)
			ply:ConCommand("sprayv2_openfavorites")
		end)

		aowl.AddCommand("clearspray2", function(ply, line, target)
			if target and ply:IsSuperAdmin() then
				local targetPly = easylua.FindEntity(target)
				if IsValid(targetPly) and targetPly:IsPlayer() then
					net.Start("ClearSpray2")
						net.WriteEntity(targetPly)
					net.Broadcast()
				end
			else
				net.Start("ClearSpray2")
					net.WriteEntity(ply)
				net.Broadcast()
			end
		end)
	end

	if aowl then
		addcmd()
	else
		hook.Add("AowlInitialized", "sprayv2_addCommands", function()
			addcmd()
			hook.Remove("AowlInitialized", "sprayv2_addCommands")
		end)
	end

	local pmeta = FindMetaTable("Player")
	function pmeta:StripSpray2()
		net.Start("ClearSpray2")
			net.WriteEntity(self)
		net.Broadcast()
	end
	local whitelist = {
		["prop_physics"] = true,
		["prop_ragdoll"] = true,
		["prop_vehicle_airboat"] = true,
		["prop_vehicle_jeep"] = true,
		["prop_vehicle_prisoner_pod"] = true,
		["gmod_sent_vehicle_fphysics_base"] = true,
		["mediaplayer_tv"] = true,
		["mediaplayer_projector"] = true,
		["mediaplayer_repeater"] = true,
		["prop_dynamic"] = true
	}
	local function IsValidSprayTrace(trace)
		if trace.HitPos:Distance(trace.StartPos) > 200 then return false end
		if trace.HitWorld then return true end
		if trace.Hit and IsValid(trace.Entity) and whitelist[trace.Entity:GetClass()] then return true end
		return false
	end

	function pmeta:PostSpray(sprayData)
		if not IsValid(self) then return end
		local new_spray = self:GetInfo("sprayv2_spray")
		if new_spray == "" then return end


		if (not self.LastSpray or (CurTime() - self.LastSpray) > 2.5) then
			local trace = self:GetEyeTrace()
			if IsValidSprayTrace(trace) and CheckWhitelist(new_spray) then
				self.LastSpray = CurTime()
				--[[http.Fetch(GETSIZE_URL .. "?url=" .. URLEncode(new_spray), function(content)
					local info = string.Explode(",", content)
					local size = tonumber(info[1])
					if size and size < 1048576 * 20 then]]
						net.Start("Sprayv2")
							net.WriteEntity(self)
							net.WriteString(new_spray)
							net.WriteVector(trace.HitPos)
							net.WriteVector(trace.HitNormal)
							net.WriteInt(trace.Entity:EntIndex(), 32)
							net.WriteBool(trace.HitWorld)
							net.WriteString("image/png" --[[info[2]])
							net.WriteTable(sprayData or {})
						net.Broadcast()
					--[[end
				end)]]
			end
		end
		return true
	end
	return
end

local surface = surface
local cam = cam

local CurrentSpray = CreateClientConVar("sprayv2_spray", "", true, true)
local sprayProps = CreateClientConVar("sprayv2_entities", "1", true, false, nil, 0, 1)
local maxVertex = CreateClientConVar("sprayv2_entities_maxvertexes", "512", true, false, "Max Vertexes that can be sprayed on", 10)
local playSounds = CreateClientConVar("sprayv2_sounds", "1", true, false, nil, 0, 1)
local showNSFW = CreateClientConVar("sprayv2_nsfw", "0", true, false, nil, 0, 1)

local baseSprayURL = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/testbasespray.png"
local baseSpray = function() end
local loadingMat = function() end
local function init()
	local loadingMatUrl = "https://github.com/Xerasin/Sprayv2/raw/master/files/loading.vtf"
	loadingMat = surface.LazyURLImage(loadingMatUrl)
	baseSpray = surface.LazyURLImage(baseSprayURL)
end

if surface.URLImage then
	init()
else
	hook.Add("Initialize", "DownloadBaseSpray", function()
		if surface.URLImage then
			init()
		end
	end)
end



local sprays = M.sprays or {}
M.sprays = sprays
local sprays2 = M.sprays2 or {}
M.sprays2 = sprays2
local spraycache = M.spraycache or {}
M.spraycache = spraycache
local gifinfocache = M.gifinfocache or {}
M.gifinfocache = gifinfocache
local entitycache = M.enttiycache or {}
M.entitycache = entitycache
local favorites = file.Exists("sprayfavorites.txt", "DATA") and util.JSONToTable(file.Read("sprayfavorites.txt", "DATA")) or {}
M.favorites = favorites

local currentFolder = favorites
local previousFolderStack = {}
local baseMaterial = nil
local lastSpray = 0

local is_down = false
local info_cache = setmetatable({}, {__mode = "k"})
hook.Add("PlayerBindPress", "sprayv2", function(ply, bind, pressed)
	if pressed and bind and bind:find("impulse 201") then
		local url = CurrentSpray:GetString()
		local trace = LocalPlayer():GetEyeTrace()
		if url ~= "" and trace.StartPos:Distance(trace.HitPos) <= 200 then
			if favorites.selected and favorites.selected.nsfw and not showNSFW:GetBool() then
				url = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/nsfw.png"
			end
			is_down = true

			if not info_cache[url] then
				--[[http.Fetch(GETSIZE_URL .. "?url=" .. URLEncode(url), function(content)
					local info = string.Explode(",", content)
					info_cache[url] = info

				end)]]
				info_cache[url] = {0, "image/png"}
			end

			return true
		end
	elseif pressed and bind and bind == "+attack" and is_down then
		is_down = false
		return true
	end
end)

hook.Add("Think", "sprayv2", function()
	if is_down then
		local trace = LocalPlayer():GetEyeTrace()
		if trace.StartPos:Distance(trace.HitPos) >= 205 then
			is_down = false
		end
	end
end)

hook.Add("CreateMove", "sprayv2", function()
	local key = input.LookupBinding("impulse 201")
	if not key then return end
	local keyCode = input.GetKeyCode(key)

	if is_down and input.WasKeyReleased(keyCode) then
		is_down = false
		net.Start("Sprayv2")
			net.WriteTable(favorites.selected or {})
		net.SendToServer()
	end
end)

hook.Add("HUDPaint", "sprayv2_preview", function()
	if is_down then
		local keyName = input.LookupBinding("+attack", true)

		local bound = false
		if not keyName then
			keyName = "<+attack not bound>"
		else
			keyName = "[" .. keyName:upper() .. "]"
			bound = true
		end

		local keyText = keyName
		local helpText = " to cancel"

		surface.SetFont("CloseCaption_Normal")
		local tw, th = surface.GetTextSize(keyText .. helpText)

		local x, y = ScrW() / 2 - tw / 2, ScrH() / 2 + th * 2

		surface.SetTextPos(x + 2, y + 2)
		surface.SetTextColor(0, 0, 0, 128)
		surface.DrawText(keyText .. helpText)

		local keyCol = bound and Color(128, 255, 128) or Color(255, 128, 128)
		surface.SetTextPos(x, y)
		surface.SetTextColor(keyCol)
		local kw = surface.GetTextSize(keyText)
		surface.DrawText(keyText)

		surface.SetTextPos(x + kw, y)
		surface.SetTextColor(192, 192, 192)
		surface.DrawText(helpText)
	end
end)

local imgurls = {}
hook.Add("PostDrawTranslucentRenderables", "sprayv2_preview", function()
	if not surface.URLImage then return end
	if is_down then
		local material = CurrentSpray:GetString()
		if not CheckWhitelist(material) then return end
		if favorites.selected and favorites.selected.nsfw and not showNSFW:GetBool() then
			material = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/nsfw.png"
		end

		local trace = LocalPlayer():GetEyeTrace()
		local vec = trace.HitPos
		local norm = trace.HitNormal


		if not info_cache[material] then
			local lw, lh = loadingMat()
			local up = Vector(0, 0, 1)
			if norm.Z == 1 then up = Vector(0, 1, 0) end
			if norm.Z == -1 then up = Vector(0, -1, 0) end
			local ang = norm:AngleEx(up)
			ang:RotateAroundAxis(ang:Up(), 90)
			ang:RotateAroundAxis(ang:Forward(), 90)
			cam.Start3D2D(vec + ang:Up() * 0.1, ang, 0.35)
				surface.SetAlphaMultiplier(0.5)
				local y = 0
				if lw and lh then
					surface.SetDrawColor(Color(255, 255, 255))
					surface.DrawTexturedRect(-32, -32 - 16, 64, 64)
					y = 32
				end
				draw.Text({
					["pos"] = {0, y},
					["color"] = Color(100, 100, 255, 255),
					["text"] = "Loading...",
					["font"] = "SprayFont",
					["xalign"] = TEXT_ALIGN_CENTER,
					["yalign"] = TEXT_ALIGN_CENTER,
				})
				surface.SetAlphaMultiplier(1)
			cam.End3D2D()
			return
		end
		local info = info_cache[material]
		local imgType = info[2]
		imgType = (imgType == "image/gif" or imgType == "vtf") and "vtf" or "png"

		--local converterUrl = ("%s?url=%s&type=%s"):format(CONVERTER_URL, URLEncode(material), imgType)

		local mat = imgurls[material] or surface.URLImage(material)
		imgurls[material] = mat

		local w, h, httpMat
		if spraycache[material] then
			w, h, httpMat = unpack(spraycache[material])
		else
			w, h, httpMat = mat()
		end

		if w and h then
			spraycache[material] = {w, h, httpMat, LocalPlayer(), LocalPlayer():SteamID(), LocalPlayer():Nick(), material}

			local up = Vector(0, 0, 1)
			if norm.Z == 1 then up = Vector(0, 1, 0) end
			if norm.Z == -1 then up = Vector(0, -1, 0) end
			local ang = norm:AngleEx(up)
			ang:RotateAroundAxis(ang:Up(), 90)
			ang:RotateAroundAxis(ang:Forward(), 90)
			cam.Start3D2D(vec + ang:Up() * 0.1, ang, 1)
				surface.SetAlphaMultiplier(0.5)
				surface.SetMaterial(httpMat)
				surface.SetDrawColor(Color(255, 255, 255))
				surface.DrawTexturedRect(-32, -32, 64, 64)
				surface.SetAlphaMultiplier(1)
			cam.End3D2D()
		else
			local lw, lh = loadingMat()
			local up = Vector(0, 0, 1)
			if norm.Z == 1 then up = Vector(0, 1, 0) end
			if norm.Z == -1 then up = Vector(0, -1, 0) end
			local ang = norm:AngleEx(up)
			ang:RotateAroundAxis(ang:Up(), 90)
			ang:RotateAroundAxis(ang:Forward(), 90)
			cam.Start3D2D(vec + ang:Up() * 0.1, ang, 0.35)
				surface.SetAlphaMultiplier(0.5)
				local y = 0
				if lw and lh then
					surface.SetDrawColor(Color(255, 255, 255))
					surface.DrawTexturedRect(-32, -32 - 16, 64, 64)
					y = 32
				end
				draw.Text({
					["pos"] = {0, y},
					["color"] = Color(100, 100, 255, 255),
					["text"] = "Loading...",
					["font"] = "SprayFont",
					["xalign"] = TEXT_ALIGN_CENTER,
					["yalign"] = TEXT_ALIGN_CENTER,
				})
				surface.SetAlphaMultiplier(1)
			cam.End3D2D()
		end
	end
end)

surface.CreateFont("SprayFavoritesFolderFont", {font = "arial", size = 12, weight = 450, antialias = true, outline = false, additive = false, shadow = false})
RunConsoleCommand("r_drawbatchdecals", "0")

surface.CreateFont( "SprayFont", {
	font 		= "Default",
	size 		= 25,
	weight 		= 450,
	antialias 	= true,
	additive 	= false,
	shadow 		= false,
	outline 	= false
} )

surface.CreateFont( "SprayFontInfo", {
	font 		= "Default",
	size 		= 25,
	weight 		= 450,
	antialias 	= true,
	additive 	= false,
	shadow 		= false,
	outline 	= true
} )

surface.CreateFont( "SprayFontInfo2", {
	font 		= "Default",
	size 		= 15,
	weight 		= 450,
	antialias 	= true,
	additive 	= false,
	shadow 		= false,
	outline 	= true
} )

function DetectCrash()
	file.Write("_spray2_crash.txt", "BEGIN")
	timer.Remove("Spray2CrashDetect")
	timer.Create("Spray2CrashDetect", 4, 1, spray2.DetectCrashEnd)
end

function DetectCrashEnd()
	timer.Remove("Spray2CrashDetect")
	file.Delete("_spray2_crash.txt")
end

local CrashDetected = file.Exists("_spray2_crash.txt", "DATA") and file.Read("_spray2_crash.txt", "DATA") == "BEGIN"
cvars.AddChangeCallback("sprayv2_entities", function(cvar, oldValue, newValue)
	if tobool(newValue) and CrashDetected then
		CrashDetected = false
		file.Delete("_spray2_crash.txt")
	end
end)

net.Receive("ClearSpray2", function()
	local ply = net.ReadEntity()
	if IsValid(ply) and ply:IsPlayer() then
		ply:StripSpray2()
	end
end)

net.Receive("Sprayv2", function()
	local ply = net.ReadEntity()
	if not IsValid(ply) then return end
	local material = net.ReadString()
	local vec = net.ReadVector()
	local norm = net.ReadVector()
	local targetEntIndex = net.ReadInt(32)
	local isWorld = net.ReadBool()
	local imgType = net.ReadString()

	local sprayData = net.ReadTable() or {}

	local targetEnt = Entity(targetEntIndex)

	if IsValid(targetEnt) or isWorld then
		spray2.Spray(ply, material, vec, norm, imgType, targetEnt, not playSounds:GetBool(), sprayData)
	elseif not isWorld then
		entitycache[ply:SteamID64()] = {targetEntIndex, ply, material, vec, norm, imgType, sprayData}
	end
end)

hook.Add("OnEntityCreated", "Sprayv2Check", function(ent)
	if not IsValid(ent) then return end
	for k,v in pairs(entitycache) do
		if ent:EntIndex() == v[1] and IsValid(v[2]) then
			spray2.Spray(v[2], v[3], v[4], v[5], v[6], ent, not playSounds:GetBool(), v[7])
			entitycache[k] = nil
		end
	end
end)

local pmeta = FindMetaTable("Player")
function pmeta:StripSpray2()
	if sprays[self] then
		if type(sprays[self]) == "string" then
			hook.Remove("Think", sprays[self])
			hook.Remove("PostDrawTranslucentRenderables", sprays[self])
		else
			_, _, baseMaterial = baseSpray()
			sprays[self]:SetString("$alpha", "0")
			sprays[self]:SetString("$alphatest", "1")
			sprays[self]:SetString("$ignorez", "1")
			sprays[self]:SetString("$basetexturetransform", "center 0.5 0.5 scale 0 0 rotate 0 translate 0 0")
			--sprays[player]:GetTexture("$basetexture"):Download()
			if baseMaterial then
				sprays[self]:SetTexture("$basetexture", baseMaterial:GetTexture("$basetexture"))
			else
				sprays[self]:SetTexture("$basetexture", "vgui/notices/error")
			end
		end
		sprays[self] = nil
		sprays2[self:SteamID()] = nil
	end
end
nsfwCache = nsfwCache or {}
cvars.AddChangeCallback("sprayv2_nsfw", function(name, old, new)
	if tobool(new) and table.Count(nsfwCache) > 0 then
		for k,v in pairs(nsfwCache) do
			if IsValid(v[1]) then
				spray2.Spray(unpack(v))
			end
		end
		nsfwCache = {}
	end
end, "Spray2NSFW")

SpraySize = 64
function Spray(ply, material, vec, norm, imgType, targetEnt, noSound, sprayData)
	if not surface.URLImage then return end
	if not IsValid(ply) then return end

	if sprayData and sprayData.nsfw and not showNSFW:GetBool() then
		nsfwCache[ply:SteamID64()] = {ply, material, vec, norm, imgType, targetEnt, noSound, sprayData}
		material = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/nsfw.png"
	end

	ply:StripSpray2()

	if not CheckWhitelist(material) then return end
	--local converterUrl = CONVERTER_URL .. "?url=" .. URLEncode(material) .. "&type=" .. ((imgType == "image/gif" or imgType == "vtf") and "vtf" or "png")
	local mat = surface.URLImage(material)
	local thinkKey = "URLDownload" .. ply:EntIndex()
	sprays[ply] = thinkKey
	local loading2 = false

	sprays2[ply:SteamID()] =
	{
		["material"] = material,
		["steamID"] = ply:SteamID(),
		["nick"] = ply:Nick(),
		["realnick"] = ply.RealNick and ply:RealNick() or "",
		["player"] = ply,
		["vec"] = vec,
		["lvec"] = IsValid(targetEnt) and targetEnt:WorldToLocal(vec) or Vector(),
		["norm"] = norm,
		["ent"] = targetEnt,
		["nsfw"] = sprayData.nsfw
	}


	if IsValid(targetEnt) then
		if not sprayProps:GetBool() then
			sound.Play("ui/beep_error01.wav", vec, 75, 100, 0.5)
			return false
		end

		if CrashDetected then
			sound.Play("ui/beep_error01.wav", vec, 75, 100, 0.5)
			chat.AddText(Color(255, 0, 0), "WARNING! ", Color(255, 255, 255), "Spraying on entities has been disabled due to you crashing, renable with sprayv2_entities 1.")
			sprayProps:SetInt(0)
			return false
		end

		local vertCount = 0
		if targetEnt:GetModel() then
			local modelMesh = util.GetModelMeshes(targetEnt:GetModel())
			if modelMesh then
				for k,v in pairs(modelMesh) do
					if v["verticies"] then
						vertCount = vertCount + #v["verticies"]
					end
				end

				if vertCount > maxVertex:GetInt() then
					sound.Play("ui/beep_error01.wav", vec, 75, 100, 0.5)
					return false
				end
			else
				return false
			end
		end
	end

	hook.Add("Think", thinkKey, function()
		hook.Add("PostDrawTranslucentRenderables", thinkKey, function()
			local w, h = loadingMat()
			local up = Vector(0, 0, 1)
			if norm.Z == 1 then up = Vector(0, 1, 0) end
			if norm.Z == -1 then up = Vector(0, -1, 0) end
			local ang = norm:AngleEx(up)
			ang:RotateAroundAxis(ang:Up(), 90)
			ang:RotateAroundAxis(ang:Forward(), 90)
			cam.Start3D2D(vec + ang:Up() * 0.1, ang, 0.35)
				local y = 0
				if w and h then
					surface.SetDrawColor(Color(255, 255, 255))
					surface.DrawTexturedRect(-32, -32 - 16, 64, 64)
					y = 32
				end
				draw.Text({
					["pos"] = {0, y},
					["color"] = Color(100, 100, 255, 255),
					["text"] = "Loading...",
					["font"] = "SprayFont",
					["xalign"] = TEXT_ALIGN_CENTER,
					["yalign"] = TEXT_ALIGN_CENTER,
				})
			cam.End3D2D()
		end)

		local w, h, httpMat
		if spraycache[material] then
			w, h, httpMat = unpack(spraycache[material])
		else
			w, h, httpMat = mat()
		end

		if w == false or not IsValid(ply) then hook.Remove("Think", thinkKey) hook.Remove("PostDrawTranslucentRenderables", thinkKey) return end
		if type(sprays[ply]) ~= "string" then
			hook.Remove("Think", thinkKey)
			hook.Remove("PostDrawTranslucentRenderables", thinkKey)
			return
		end

		if w and h and (CurTime() - lastSpray) > 1 then
			local _, _, baseSprayMat = baseSpray()
			if loading2 then return end
			if not baseSprayMat then return end
			local function PlaceSpray(rate)
				if not IsValid(ply) then hook.Remove("Think", thinkKey) hook.Remove("PostDrawTranslucentRenderables", thinkKey) return end
				loading2 = false
				lastSpray = CurTime()
				spraycache[material] = {w, h, httpMat, ply, ply:SteamID(), ply:Nick(), material}
				local matname = os.time() .. "SPRAYV2WHYDOIDO" .. math.random(1024)

				local tempMat

		 		if IsValid(targetEnt) then
					tempMat = CreateMaterial(matname, "VertexLitGeneric", {
						["$basetexture"] = baseSprayMat:GetString("$basetexture"),
						["$basetexturetransform"] = "center 0.5 0.5 scale 1 1 rotate 0 translate 0 0",
						["$vertexalpha"] = 1,
						["$decal"] = 1
					})
				else
					tempMat = CreateMaterial(matname, "LightmappedGeneric", {
						["$basetexture"] = baseSprayMat:GetString("$basetexture"),
						["$basetexturetransform"] = "center 0.5 0.5 scale 1 1 rotate 0 translate 0 0",
						["$vertexcolor"] = 1,
						["$vertexalpha"] = 1,
						["$transparent"] = 1,
						["$nolod"] = 1,
						["Proxies"] = {AnimatedTexture = {animatedTextureVar = "$basetexture", animatedTextureFrameNumVar = "$frame", animatedTextureFrameRate = rate or 8}},
						["$decal"] = 1
					})
				end

				local tex = httpMat:GetTexture("$basetexture")
				if tempMat and tex then
					tempMat:SetTexture("$basetexture", tex)
					tempMat:GetTexture("$basetexture"):Download()

					if not tempMat:IsError() and not tempMat:GetTexture("$basetexture"):IsError() then
						hook.Remove("Think", thinkKey)
						hook.Remove("PostDrawTranslucentRenderables", thinkKey)

						materialOut = tempMat
						if not noSound then
							sound.Play("player/sprayer.wav", vec, 75, 100, 0.5)
						end

						DetectCrash()
						util.DecalEx(tempMat, IsValid(targetEnt) and targetEnt or game.GetWorld(), vec, norm, Color(255, 255, 255), 0, 0, 1)
						sprays[ply] = tempMat
						hook.Remove("PostDrawTranslucentRenderables", ply:UniqueID() .. "SprayInfo")
					end
				else
					hook.Remove("Think", thinkKey)
					hook.Remove("PostDrawTranslucentRenderables", thinkKey)
				end
			end

			--[[if imgType == "image/gif" then
				loading2 = true
				if gifinfocache[material] then
					PlaceSpray(gifinfocache[material])
					return
				end
				http.Fetch(GIFINFO_URL .. "?url=" .. URLEncode(material), function(content)
					local num = tonumber(content)
					if num and type(sprays[ply]) == "string" then
						PlaceSpray(num)
						gifinfocache[material] = num
					end
				end)
			else]]
				PlaceSpray(8)
			--end
		end
	end)
end

local lastKeyDown = false
hook.Add("PostDrawTranslucentRenderables", "SprayInfo", function()
	local inSpeed = LocalPlayer():KeyDown(IN_SPEED)
	for k,tbl in pairs(sprays2) do
		if tbl and inSpeed then

			if IsValid(tbl.ent) then
				tbl.vec = tbl.ent:LocalToWorld(tbl.lvec)
			end

			local vec = tbl.vec
			local norm = tbl.norm
			local ply = tbl.ply
			local material = tbl.material
			local up = Vector(0, 0, 1)
			if norm.Z == 1 then up = Vector(0, 1, 0) end
			if norm.Z == -1 then up = Vector(0, -1, 0) end
			local ang = norm:AngleEx(up)
			ang:RotateAroundAxis(ang:Up(), 90)
			ang:RotateAroundAxis(ang:Forward(), 90)


			local ply_id = IsValid(ply) and ply:SteamID() or tbl.steamID
			local ply_name = IsValid(ply) and ply:Nick() or tbl.nick
			local scale = 0.1
			cam.Start3D2D(vec + ang:Up() * 0.1 - ang:Forward() * SpraySize / 2 - ang:Right() * SpraySize / 2, ang, scale)
				local w,h = SpraySize * 1 / scale, SpraySize * 1 / scale
				local info_string = string.format("Player: %s \nPlayer ID: %s \nURL: %s\n%s", ply_name, ply_id, material, tbl.nsfw and "!! Marked NSFW !!" or "")
				local t = string.Explode("\n", info_string)
				for I = 1, #t do
					draw.Text({
						["pos"] = {0, 25 * (I - 1)},
						["color"] = I == 4 and Color(255, 0, 0) or Color(255, 255, 255, 255),
						["text"] = t[I],
						["font"] = I ~= 3 and "SprayFontInfo" or "SprayFontInfo2",
						["xalign"] = TEXT_ALIGN_LEFT,
						["yalign"] = TEXT_ALIGN_TOP,
					})
				end
				local function drawCircle( x, y, radius, seg )
					local cir = {}

					table.insert( cir, { x = x, y = y, u = 0.5, v = 0.5 } )
					for i = 0, seg do
						local a = math.rad( ( i / seg ) * -360 )
						table.insert( cir, { x = x + math.sin( a ) * radius, y = y + math.cos( a ) * radius, u = math.sin( a ) / 2 + 0.5, v = math.cos( a ) / 2 + 0.5 } )
					end

					local a = math.rad( 0 ) -- This is need for non absolute segment counts
					table.insert( cir, { x = x + math.sin( a ) * radius, y = y + math.cos( a ) * radius, u = math.sin( a ) / 2 + 0.5, v = math.cos( a ) / 2 + 0.5 } )

					surface.DrawPoly( cir )
				end
				local selectsize = 8
				surface.SetTexture(0)
				surface.SetDrawColor(150, 0, 0, 100)
				drawCircle(w / 2, h / 2, selectsize * 1 / scale, 30)
				draw.Text({
					["pos"] = {w / 2, h / 2 - 12.5},
					["color"] = Color(255, 255, 255, 255),
					["text"] = "Copy Info",
					["font"] = "SprayFont",
					["xalign"] = TEXT_ALIGN_CENTER,
					["yalign"] = TEXT_ALIGN_CENTER,
				})
				draw.Text({
					["pos"] = {w / 2, h / 2 + 12.5},
					["color"] = Color(100, 100, 100, 255),
					["text"] = "(Left Click)",
					["font"] = "SprayFont",
					["xalign"] = TEXT_ALIGN_CENTER,
					["yalign"] = TEXT_ALIGN_CENTER,
				})
				if LocalPlayer():KeyDown(IN_ATTACK) and not lastKeyDown then
					local trace = LocalPlayer():GetEyeTrace()
					if trace.HitPos:Distance(vec) < selectsize then
						LocalPlayer():ChatPrint("Spray Info copied to clipboard!")
						SetClipboardText(info_string)
					end
				end
			cam.End3D2D()
		end
	end
	lastKeyDown = LocalPlayer():KeyDown(IN_ATTACK)
end)

local SprayPanel = {}
function SprayPanel:Init()
	self:SetText("")
	self.CheckBox = vgui.Create("DCheckBox", self)
	self.CheckBox:SetValue(0)
	self.CheckBox:SetVisible(false)

	self.RemoveButton = vgui.Create("DImageButton", self)
	self.RemoveButton:SetSize(16, 16)
	self.RemoveButton:SetImage("icon16/cross.png")

	self.NSFWButton = vgui.Create("DImageButton", self)
	self.NSFWButton:SetSize(16, 16)
	self.NSFWButton:SetImage("icon16/error.png")

	function self.RemoveButton.DoClick(button)
		Derma_Query("Are you sure you want to delete this?", "Deletion", "Yes", function()
			if self.tab then
				for k,v in pairs(currentFolder) do
					if v == self.tab then
						self.Index = tonumber(k)
					end
				end

				if not self.Index then
					self:Remove()
					return
				end

				table.remove(currentFolder, self.Index)
				file.Write("sprayfavorites.txt", util.TableToJSON(favorites))
				self:Remove()
			end
		end,"No",function() end)
	end

	function self.NSFWButton.DoClick(button)
		self.tab.nsfw = not self.tab.nsfw
		file.Write("sprayfavorites.txt", util.TableToJSON(favorites))
		Repopulate()
	end

	self.Checkmark = Material("icon16/accept.png")
	self.IsFolder = false
	self:Droppable( "spraypanel" )
	self:Receiver("spraypanel", function(receiver, tableOfDroppedPanels, isDropped, menuIndex, mouseX, mouseY)
		if isDropped then
			if receiver.IsFolder then
				local drop = receiver.tab.contents
				if self.PreviousButton then
					drop = previousFolderStack[#previousFolderStack]
				end
				for k,v in pairs(tableOfDroppedPanels) do
					if receiver ~= v then
						table.insert(drop, v.tab)
						for k2,v2 in pairs(currentFolder) do
							if v2 == v.tab then v.Index = k2 end
						end
						table.remove(currentFolder, v.Index)
						file.Write("sprayfavorites.txt", util.TableToJSON(favorites))
						v:Remove()
					end
				end
			else
				Derma_StringRequest("Create Folder", "Name the new folder", "", function(str)
					local newFolder = {}
					newFolder.isFolder = true
					newFolder.name = str
					newFolder.contents = {}
					local function AddPanel(v)
						table.insert(newFolder.contents, v.tab)
						for k2,v2 in pairs(currentFolder) do
							if v2 == v.tab then v.Index = k2 end
						end
						table.remove(currentFolder, v.Index)
						file.Write("sprayfavorites.txt", util.TableToJSON(favorites))
						v:Remove()

					end
					for k,v in pairs(tableOfDroppedPanels) do
						if v ~= receiver then
							AddPanel(v)
						end
					end
					AddPanel(receiver)
					table.insert(currentFolder, newFolder)
					Repopulate()

				end, function() end, "Create", "Cancel")
			end
		end
	end)
end

function SprayPanel:SetFavoriteTab(tab)
	self.tab = tab

	if IsValid(self.NSFWButton) then
		self.NSFWButton:SetColor(self.tab.nsfw and Color(255, 255, 255, 255) or Color(255, 255, 255, 100))
		self.NSFWButton:SetIcon(self.tab.nsfw and "icon16/exclamation.png" or "icon16/error.png")
		self.NSFWButton:SetTooltip(self.tab.nsfw and "Marked as NSFW" or "Mark as NSFW")
	end
end

function SprayPanel:MakeFolder(previous)
	self.IsFolder = true
	self.PreviousButton = previous

	if IsValid(self.NSFWButton) then
		self.NSFWButton:Remove()
	end

	if previous then
		self.RemoveButton:Remove()
	else
		self.RenameButton = vgui.Create("DImageButton", self)
		self.RenameButton:SetSize(16, 16)
		self.RenameButton:SetImage("icon16/pencil.png")
		function self.RenameButton.DoClick(button)
			Derma_StringRequest("Rename Folder", "Enter a new name", self.tab.name, function(str)
				self.tab.name = str
				file.Write("sprayfavorites.txt", util.TableToJSON(favorites))
				Repopulate()
			end, function() end, "Rename", "Cancel")
		end
	end
end

function SprayPanel:SetSpray(str)
	self.SprayURL = str
	--[[local fileType = "png"
	if str:sub(-3) == "gif" or str:sub(-3) == "vtf" then
		fileType = "vtf"
	end
	local converterUrl = CONVERTER_URL .. "?url=" .. URLEncode(str) .. "&type=" .. fileType]]
	if CheckWhitelist(str) then
		self.Mat = surface.URLImage(str)
	end
end

function SprayPanel:PerformLayout()
	local w, h = self:GetSize()

	self.CheckBox:SetPos(5, 5)

	if IsValid(self.RemoveButton) then
		self.RemoveButton:SetPos(w - 16, 0)
	end

	if IsValid(self.RenameButton) then
		self.RenameButton:SetPos(w - 16, h - 16)
	end

	if IsValid(self.NSFWButton) then
		self.NSFWButton:SetPos(0, 0)
	end
end

function SprayPanel:Paint(pw, ph)
	if self.Mat then
		local w, h = self.Mat()
		surface.SetDrawColor(Color(20, 20, 20))
		surface.DrawRect(0, 0, pw, ph)
		if w and h then
			local x,y,w2,h2,ratio = 0, 0, 0, 0, 0
			if w > h then
				ratio = w / h
				w2 = pw
				h2 = pw * 1 / ratio
				y = (ph - h2) / 2
			else
				ratio = h / w

				h2 = ph
				w2 = ph * 1 / ratio
				x = (pw - w2) / 2
			end
			surface.SetDrawColor(Color(255, 255, 255))
			surface.DrawTexturedRect(x, y, w2, h2)
		end
	end

	if self.IsFolder then
		draw.Text({
			["pos"] = { pw / 2 , ph - 12 },
			["color"] = Color(255, 255, 255, 255),
			["text"] = self.tab.name or "???",
			["font"] = "SprayFavoritesFolderFont",
			["xalign"] = TEXT_ALIGN_CENTER,
			["yalign"] = TEXT_ALIGN_CENTER,
		})
	end

	if CurrentSpray:GetString() == self.SprayURL then
		surface.SetMaterial(self.Checkmark)
		surface.SetDrawColor(Color(255, 255, 255))
		surface.DrawTexturedRect(0, ph - 16, 16, 16)
	end
end

function SprayPanel:DoClick()
	if self.IsFolder then
		if self.PreviousButton then
			currentFolder = table.remove(previousFolderStack, #previousFolderStack)
		else
			table.insert(previousFolderStack, currentFolder)
			currentFolder = self.tab.contents
		end
		Repopulate()
		return
	end

	favorites.selected = self.tab
	file.Write("sprayfavorites.txt", util.TableToJSON(favorites))
	RunConsoleCommand("sprayv2_spray", self.SprayURL)
end

function SprayPanel:DoRightClick()
	if not self.IsFolder then
		local dMenu = DermaMenu(self)
		dMenu:AddOption("Copy URL", function()
			if self.SprayURL then
				SetClipboardText(self.SprayURL)
			end
		end)
		dMenu:Open()
	end
end


vgui.Register("DSprayPanel", SprayPanel, "DButton")
function Repopulate()
	Sort()
	FavoritePanel.List:Clear()
	local function AddButton(k, v, folder, tab)
		local SprayPan = vgui.Create("DSprayPanel", FavoritePanel.List)
		SprayPan:SetSize(128, 128)
		SprayPan:SetSpray(v.url)
		SprayPan:SetFavoriteTab(v)
		if folder then
			SprayPan:MakeFolder(tab)
		end
		FavoritePanel.List:Add(SprayPan)
	end
	if #previousFolderStack > 0 then
		AddButton(1, {url = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/folder_forward.png", name = "Back"}, true, previousFolderStack[#previousFolderStack])
	end
	for k,v in pairs(currentFolder) do
		if v.isFolder then
			v.url = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/folder_forward.png"
			AddButton(k, v, true)
		elseif tonumber(k) then
			AddButton(k, v)
		end
	end
end

function Sort()
	table.sort(currentFolder, function(a, b)
		local ac = table.Copy(a)
		local bc = table.Copy(b)
		if ac.name then ac.name = "AAAAAAAA" .. ac.name:lower() end
		if bc.name then bc.name = "AAAAAAAA" .. bc.name:lower() end
		return (ac.name or ac.url) < (bc.name or bc.url)
	end)
end

concommand.Add("sprayv2_openfavorites", function()
	if FavoritePanel then
		FavoritePanel:Remove()
	end
	local width = 420
	FavoritePanel = vgui.Create("DFrame")
	local offset = 25
	if FavoritePanel.GetTitleBarHeight then
		offset = FavoritePanel:GetTitleBarHeight()
	end
	FavoritePanel:SetSize(width, 500 + offset)
	local _, h = FavoritePanel:GetSize()
	FavoritePanel:SetPos(5, 5)
	FavoritePanel:SetTitle("Spray Favorites")
	FavoritePanel:MakePopup()

	FavoritePanel.Scroll = vgui.Create( "DScrollPanel", FavoritePanel ) --Create the Scroll panel
	FavoritePanel.Scroll:SetSize(width - 10, h - 20 - offset)
	FavoritePanel.Scroll:SetPos(5, offset)
	--FavoritePanel.Scroll:Dock(FILL)

	FavoritePanel.List	= vgui.Create( "DIconLayout", FavoritePanel.Scroll )
	FavoritePanel.List:SetSpaceY( 5 ) --Sets the space in between the panels on the X Axis by 5
	FavoritePanel.List:SetSpaceX( 5 ) --Sets the space in between the panels on the Y Axis by 5
	--FavoritePanel.List:Dock(FILL)
	FavoritePanel.List:SetSize(width - 10, h - 20 - offset)

	function FavoritePanel.Scroll:Paint(pw, ph)
		surface.SetTexture(0)
		surface.SetDrawColor(Color(50, 50, 50))
		surface.DrawRect(0, 0, pw, ph)
	end

	Repopulate()

	FavoritePanel.AddFavorite = vgui.Create("DButton", FavoritePanel)
	FavoritePanel.AddFavorite:SetSize(width, 20)
	FavoritePanel.AddFavorite:SetPos(0, h - 20)
	FavoritePanel.AddFavorite:SetText("Add Favorite")

	function FavoritePanel.AddFavorite:DoClick()
		Derma_StringRequest("Add a favorite", "URL","",function(text)
			if text == "" then return end
			if not CheckWhitelist(text) then
				chat.AddText(Color(255, 255, 255), "Not a whitelisted Sprayv2 URL")
				return
			end

			for k,v in pairs(currentFolder) do
				if v.url == text then return end
			end

			local tbl = {url = text, nsfw = false, superfav = false}
			table.insert(currentFolder, tbl)
			Repopulate()

			file.Write("sprayfavorites.txt", util.TableToJSON(favorites))
		end)
	end
end)

list.Set("DesktopWindows", "sprayv2", {
	title = "Spray",
	icon = "icon16/folder_image.png",
	width = 1,
	height = 1,
	onewindow = true,
	init = function(icn, pnl)
		pnl:Remove()

		RunConsoleCommand("sprayv2_openfavorites")
	end
})
