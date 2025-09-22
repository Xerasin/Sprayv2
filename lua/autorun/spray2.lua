pcall(require, "urlimage")
local SPRAYINFO_URL = "https://sprays.xerasin.com/v1/get"
local SPRAYADD_URL = "https://sprays.xerasin.com/v1/add"
local SPRAYLOGIN_URL = "https://sprays.xerasin.com/v1/login"
local RANDOMSPRAY_URL = "https://sprays.xerasin.com/v1/random"
local REPORTSPRAY_URL = "https://sprays.xerasin.com/v1/report"
module("spray2", package.seeall)
local _M = _M
local M = setmetatable({},{__index = function(s,k) return rawget(_M,k) end,__newindex = _M})
_M.M = M

local STATUS = {
	DELETED        = -7,
	NEEDS_CREATED  = -6,
	REQUIRES_TOKEN = -5,
	BLACKLIST      = -4,
	ERR_OTHER      = -3,
	CANNOT_PROCESS = -2,
	FAILED         = -1,
	PROCESSING     = 0,
	SUCCESS        = 1,
}
M.STATUS = STATUS

local STATUS_NAME = {}
for k, v in pairs(STATUS) do
	STATUS_NAME[v] = k
end
M.STATUS_NAME = STATUS_NAME

local NET = {
	Spray = 0,
	ClearSpray = 1,
	Token = 2,
}
M.NET = NET

if SERVER then
	local server_token = nil
	local function createTable()
		if not sql.TableExists("spraytoken") then
			sql.Query([[
				CREATE TABLE IF NOT EXISTS spraytoken (
					id INTEGER PRIMARY KEY,
					token TEXT NOT NULL
				);
			]])
		end
	end

	local function saveToken(newToken)
		createTable()
		sql.Query(string.format([[
			INSERT INTO spraytoken (id, token)
			VALUES (1, '%s')
			ON CONFLICT(id) DO UPDATE SET token=excluded.token;
		]], sql.SQLStr(newToken, true)))
		server_token = newToken
	end

	local function loadToken()
		createTable()
		local sql_token = sql.QueryValue([[SELECT token FROM spraytoken WHERE id = 1 LIMIT 1;]])
		local err = sql.LastError()
		if not err and sql_token then
			server_token = sql_token
		end
	end

	concommand.Add("sprayv2_token", function(ply, cmd, args)
		if not ply:IsSuperAdmin() then return end
		if #args ~= 1 then return end
		saveToken(args[1])
		ply:ChatPrint(string.format("Set sprayv2 server token to %s.", args[1]))
	end)

	local function sendToken(ply, valid, token_data)
		if not IsValid(ply) then return end

		net.Start("Sprayv2")
			net.WriteInt(NET.Token, 8)
			net.WriteBool(valid)
			if valid and token_data and token_data.token and token_data.expiry then
				net.WriteString(token_data.token)
				net.WriteUInt(token_data.expiry, 32)
			end
		net.Send(ply)
	end

	local tokenCache = {}
	local function onReceiveTokenRequest(ply)
		if not IsValid(ply) then return end
		local steamid = ply:SteamID64()
		local cached = tokenCache[steamid]

		if cached and cached.expiry > os.time() then
			sendToken(ply, true, cached)
			return
		end

		if not server_token then
			loadToken()
		end

		http.Post(SPRAYLOGIN_URL, {["server_token"] = server_token, ["steamid"] = steamid}, function(data, _, _, code)
			if code == 200 then
				local token_data = util.JSONToTable(data)
				if not token_data or not token_data["token"] then
					print("Invalid token response:", data)
					return
				end
				if IsValid(ply) then
					cached = {
						token = token_data["token"],
						expiry = token_data["expiry_unix"],
					}
					tokenCache[steamid] = cached
					sendToken(ply, true, cached)
				end
			else
				local error_data = data

				if code == 400 then
					local json = util.JSONToTable(data)
					if json and json["error"] then
						error_data = json["error"]
					end
				end

				if IsValid(ply) then
					sendToken(ply, false)
				end

				if error_data == "Valid token already exists." then
					return
				end

				print(string.format("Sprayv2 token generation failed for %s (HTTP %d): %s", steamid, code, error_data))
			end
		end)
	end

	hook.Add("Initialize", "sprayv2", function()
		loadToken()
	end)

	util.AddNetworkString("Sprayv2")
	net.Receive("Sprayv2", function(len, ply)
		local networkID = net.ReadInt(8)
		if networkID == NET.Spray then
			ply:PostSpray(net.ReadTable())
		elseif networkID == NET.Token then
			onReceiveTokenRequest(ply)
		end
	end)

	hook.Add("PlayerSpray", "Sprayv2", function(ply)
		if ply:PostSpray() then return true end
	end)

	hook.Add("NetData", "sprayv2", function(pl, key, value)
		if key == "sprayv2" then
			return not value or (type(value) == "table" and value.url and value.url ~= "")
		end
	end)

	local function addcmd()
		aowl.AddCommand({"spraymenu", "sprays", "spray", "sprayv2"}, function(ply, line)
			ply:ConCommand("sprayv2_openfavorites")
		end)

		aowl.AddCommand("clearspray2", function(ply, line, target)
			if target and ply:IsSuperAdmin() then
				local targetPly = easylua.FindEntity(target)
				if IsValid(targetPly) and targetPly:IsPlayer() then
					targetPly:StripSpray2()
				end
			else
				ply:StripSpray2()
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
		net.Start("Sprayv2")
			net.WriteInt(NET.ClearSpray, 8)
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
		["prop_dynamic"] = true,
		["prop_static"] = true
	}
	local function IsValidSprayTrace(trace)
		if trace.HitPos:Distance(trace.StartPos) > 200 then return false end
		if trace.HitWorld then return true end
		if trace.Hit and IsValid(trace.Entity) and whitelist[trace.Entity:GetClass()] then return true end
		return false
	end

	function pmeta:PostSpray(sprayData)
		if not IsValid(self) then return end
		local spray = sprayData or (self.GetNetData and self:GetNetData("sprayv2"))
		if not spray or not spray.url or spray.url == "" then return end

		if (not self.LastSpray or (CurTime() - self.LastSpray) > 2.5) then
			local trace = self:GetEyeTrace()
			if IsValidSprayTrace(trace) then
				self.LastSpray = CurTime()
				net.Start("Sprayv2")
					net.WriteInt(NET.Spray, 8)
					net.WriteEntity(self)
					net.WriteString(spray.url)
					net.WriteVector(trace.HitPos)
					net.WriteVector(trace.HitNormal)
					net.WriteInt(trace.Entity:EntIndex(), 32)
					net.WriteBool(trace.HitWorld)
					net.WriteTable({nsfw = spray.nsfw})
				net.Broadcast()
			end
		end
		return true
	end
	return
end

local surface = surface
local cam = cam

--local CurrentSpray = CreateClientConVar("sprayv2_spray", "", true, true)
local sprayProps = CreateClientConVar("sprayv2_entities", "0", true, false, nil, 0, 1)
local maxVertex = CreateClientConVar("sprayv2_entities_maxvertexes", "512", true, false, "Max Vertexes that can be sprayed on", 10)
local playSounds = CreateClientConVar("sprayv2_sounds", "1", true, false, nil, 0, 1)
local showNSFW = CreateClientConVar("sprayv2_nsfw", "0", true, false, nil, 0, 1)

local baseSprayURL = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/basespray.png"
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
local spraycache = M.spraycache or {}
M.spraycache = spraycache
local entitycache = M.entitycache or {}
M.entitycache = entitycache
local nsfwcache = M.nsfwcache or {}
M.nsfwcache = nsfwcache
local favorites = file.Exists("sprayfavorites.txt", "DATA") and util.JSONToTable(file.Read("sprayfavorites.txt", "DATA")) or {}
M.favorites = favorites
local sprayinfoqueue = M.sprayinfoqueue or {}
M.sprayinfoqueue = sprayinfoqueue
local sprayinfo = M.sprayinfo or {}
M.sprayinfo = sprayinfo

local requestingToken = false
function requestToken()
	if requestingToken then return end
	requestingToken = true
	net.Start("Sprayv2")
		net.WriteInt(NET.Token, 8)
	net.SendToServer()
end

function isTokenValid()
	if not favorites.token or type(favorites.token) == "string" then
		return false
	end

	return favorites.token.expiry > os.time()
end

function getToken()
	if not isTokenValid() then
		requestToken()
	end

	if favorites.token and type(favorites.token) == "table" then
		return favorites.token.token
	end
end

local function WriteFavorites()
	file.Write("sprayfavorites.txt", util.TableToJSON(favorites))
end

local shouldUseAdd = {
	["UI"] = true,
	["Preview"] = true,
}

function GetSprayCache(url, key, success, fail)
	if sprayinfo[url] then
		local sprayData = sprayinfo[url]
		if sprayData["status"] == 0 and (sprayData["time_out"] or 0) > os.time() then return
		elseif sprayData["status"] > 0 and success then return success(sprayData)
		elseif sprayData["status"] < 0 and fail then return fail(sprayData) end
	end

	if not sprayinfoqueue[url] then sprayinfoqueue[url] = {} end
	sprayinfoqueue[url][key] = {success, fail}

	local timerName = "spraydata_" .. util.CRC(url)
	if timer.Exists(timerName) then return end

	local function processQueue(sprayData)
		if sprayinfoqueue[url] then
			for k,v in pairs(sprayinfoqueue[url]) do
				if sprayData["status"] > 0 and v[1] then
					v[1](sprayData)
				elseif sprayData["status"] < 0 and v[2] then
					v[2](sprayData)
				end
			end
			sprayinfoqueue[url] = nil
		end
	end

	local running = false
	local getData getData = function()
		if running then return end
		running = true
		if not isTokenValid() then
			requestToken()
		end
		local useAdd = shouldUseAdd[key] == true
		http.Post(useAdd and SPRAYADD_URL or SPRAYINFO_URL, {["url"] = url, ["token"] = getToken()}, function(data, _, _, code)
			running = false
			local sprayData = util.JSONToTable(data)
			if code ~= 200 or not sprayData then
				timer.Remove(timerName)
				sprayinfo[url] = {["status"] = -3, ["status_text"] = ("Backend error %s"):format(code)}
				if fail then fail(sprayinfo[url]) end
				return
			end

			sprayData["status"] = tonumber(sprayData["status"])
			sprayData["time_out"] = tonumber(sprayData["time_out"])

			if sprayData["status"] == 0 and (sprayData["time_out"] or 0) < os.time() then
				if not timer.Exists(timerName) then
					timer.Create(timerName, 0.1, 30, getData)
				end
			else
				timer.Remove(timerName)
				sprayinfo[url] = sprayData

				if (sprayData["time_out"] or 0) > os.time() then
					local msg = ("Sprayv2: %q is being rated limited by Imgur nothing I can do. Retrying at %s."):format(url, os.date("%x %X", sprayData["time_out"]))
					print(msg)
					return
				else
					processQueue(sprayData)
				end
			end
		end, function(err)
			running = false
			timer.Remove(timerName)
			sprayinfo[url] = {["status"] = -3, ["status_text"] = ("Backend error %s"):format(err)}
			if fail then fail(sprayinfo[url]) end
		end)
	end
	getData()
end

local currentFolder = favorites
local previousFolderStack = {}
local waitingForToken = {}
local baseMaterial = nil
local FavoritePanel

local function AddSpray(tbl)
	if not tbl or tbl.url == "" then return end

	for k, v in pairs(currentFolder) do
		if tonumber(k) and v.url == tbl.url then
			return
		end
	end

	if not isTokenValid() then
		return requestToken()
	end

	http.Post(SPRAYADD_URL, {["url"] = tbl.url, ["token"] = getToken()}, function(data, _, _, code)
		local sprayData = util.JSONToTable(data)
		if code ~= 200 or not sprayData then return end

		local status = tonumber(sprayData.status)
		sprayData.status = status

		if status >= 0 then
			table.insert(currentFolder, tbl)
			WriteFavorites()
			if IsValid(FavoritePanel) then
				FavoritePanel:Populate()
			end

		elseif status == STATUS.REQUIRES_TOKEN then
			table.insert(waitingForToken, tbl)
			requestToken()

		else
			LocalPlayer():ChatPrint(string.format(
				"Cannot process %s (%s): %s",
				tbl.url,
				STATUS_NAME[status] or status,
				sprayData.status_text or "Unknown error"
			))
		end
	end)
end
local function processWaitingQueue()
	while #waitingForToken > 0 do
		local tbl = table.remove(waitingForToken, 1)
		AddSpray(tbl)
	end
end

local is_down = false
hook.Add("PlayerBindPress", "sprayv2", function(ply, bind, pressed)
	if pressed and bind and bind:find("impulse 201") and favorites.selected then
		local trace = LocalPlayer():GetEyeTrace()
		if trace.StartPos:Distance(trace.HitPos) <= 200 then
			is_down = true
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

	if is_down and input.WasKeyReleased(keyCode) and favorites.selected then
		is_down = false
		net.Start("Sprayv2")
			net.WriteInt(NET.Spray, 8)
			net.WriteTable(favorites.selected)
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
		local spray = favorites.selected
		if not spray then return end

		local material = spray.url
		if spray.nsfw and not showNSFW:GetBool() then
			material = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/nsfw.png"
		end

		if not material or material == "" then return end


		local trace = LocalPlayer():GetEyeTrace()
		local vec = trace.HitPos
		local norm = trace.HitNormal

		local outputURL, errorText
		GetSprayCache(material, "Preview", function(data)
			outputURL = data["url"]
		end, function(data)
			errorText = data["status_text"]
		end)

		if not outputURL then
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
					["text"] = errorText or "Loading...",
					["font"] = "SprayFont",
					["xalign"] = TEXT_ALIGN_CENTER,
					["yalign"] = TEXT_ALIGN_CENTER,
				})
				surface.SetAlphaMultiplier(1)
			cam.End3D2D()
			return
		end

		local mat = imgurls[outputURL] or surface.URLImage(outputURL)
		imgurls[outputURL] = mat

		local w, h, httpMat
		if spraycache[material] then
			w, h, httpMat = unpack(spraycache[material])
		else
			w, h, httpMat = mat()
		end

		if w and h then
			spraycache[material] = {w, h, httpMat}

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
end

function DetectCrashEnd()
	file.Delete("_spray2_crash.txt")
end

local CrashDetected = file.Exists("_spray2_crash.txt", "DATA") and file.Read("_spray2_crash.txt", "DATA") == "BEGIN"
cvars.AddChangeCallback("sprayv2_entities", function(cvar, oldValue, newValue)
	if tobool(newValue) and CrashDetected then
		CrashDetected = false
		file.Delete("_spray2_crash.txt")
	end
end)

net.Receive("Sprayv2", function()
	local networkID = net.ReadInt(8)
	if networkID == NET.Spray then
		local ply = net.ReadEntity()
		if not IsValid(ply) then return end
		local material = net.ReadString()
		local vec = net.ReadVector()
		local norm = net.ReadVector()
		local targetEntIndex = net.ReadInt(32)
		local isWorld = net.ReadBool()

		local sprayData = net.ReadTable() or {}

		local targetEnt = Entity(targetEntIndex)

		if IsValid(targetEnt) or isWorld then
			spray2.Spray(ply, material, vec, norm, targetEnt, not playSounds:GetBool(), sprayData)
		elseif not isWorld then
			entitycache[ply:SteamID64()] = {targetEntIndex, ply, material, vec, norm, sprayData}
		end
	elseif networkID == NET.ClearSpray then
		local ply = net.ReadEntity()
		if IsValid(ply) and ply:IsPlayer() then
			ply:StripSpray2()
		end
	elseif networkID == NET.Token then
		wasCreated = net.ReadBool()
		requestingToken = false
		if wasCreated then
			sprayToken = net.ReadString()
			expiryTime = net.ReadUInt(32)
			if sprayToken then
				processWaitingQueue()
				favorites.token = {token = sprayToken, expiry = expiryTime}
				WriteFavorites()
			end
		end
	end
end)

hook.Add("OnEntityCreated", "Sprayv2Check", function(ent)
	if not IsValid(ent) then return end
	for k,v in pairs(entitycache) do
		if ent:EntIndex() == v[1] and IsValid(v[2]) then
			spray2.Spray(v[2], v[3], v[4], v[5], ent, not playSounds:GetBool(), v[6])
			entitycache[k] = nil
		end
	end
end)

local pmeta = FindMetaTable("Player")
function pmeta:StripSpray2()
	if sprays[self] then
		local sprayMat = sprays[self]["spraymat"]

		local thinkKey = "URLDownload" .. self:EntIndex()
		hook.Remove("Think", thinkKey)
		hook.Remove("PostDrawTranslucentRenderables", thinkKey)
		if sprayMat then
			_, _, baseMaterial = baseSpray()
			sprayMat:SetString("$alpha", "0")
			sprayMat:SetString("$alphatest", "1")
			sprayMat:SetString("$ignorez", "1")
			sprayMat:SetString("$basetexturetransform", "center 0.5 0.5 scale 0 0 rotate 0 translate 0 0")
			--sprays[player]:GetTexture("$basetexture"):Download()
			if baseMaterial then
				sprayMat:SetTexture("$basetexture", baseMaterial:GetTexture("$basetexture"))
			else
				sprayMat:SetTexture("$basetexture", "vgui/notices/error")
			end
		end
		sprays[self] = nil
	end
end

hook.Add("InitPostEntity", "Sprayv2", function()
	if favorites and favorites.selected and favorites.selected.url and favorites.selected.url ~= "" and LocalPlayer().SetNetData then
		LocalPlayer():SetNetData("sprayv2", favorites.selected)
	end

	timer.Simple(0, function() if not isTokenValid() then requestToken() end end)
end)

cvars.AddChangeCallback("sprayv2_nsfw", function(name, old, new)
	if tobool(new) and table.Count(nsfwcache) > 0 then
		for k,v in pairs(nsfwcache) do
			if IsValid(v[1]) then
				spray2.Spray(unpack(v))
			end
		end
		nsfwcache = {}
	end
end, "Spray2NSFW")

SpraySize = 64
function Spray(ply, material, vec, norm, targetEnt, noSound, sprayData)
	if not surface.URLImage then return end
	if not IsValid(ply) then return end

	if sprayData and sprayData.nsfw and not showNSFW:GetBool() then
		nsfwcache[ply:SteamID64()] = {ply, material, vec, norm, targetEnt, noSound, sprayData}
		material = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/nsfw.png"
	end

	ply:StripSpray2()
	local thinkKey = "URLDownload" .. ply:EntIndex()


	local up = Vector(0, 0, 1)
	if norm.Z == 1 then up = Vector(0, 1, 0) end
	if norm.Z == -1 then up = Vector(0, -1, 0) end
	local ang = norm:AngleEx(up)
	ang:RotateAroundAxis(ang:Up(), 90)
	ang:RotateAroundAxis(ang:Forward(), 90)

	sprays[ply] =
	{
		["material"] = material,
		["steamID"] = ply:SteamID(),
		["nick"] = ply:Nick(),
		["realnick"] = ply.RealNick and ply:RealNick() or "",
		["vec"] = vec,
		["ang"] = ang,
		["ent"] = targetEnt,
		["nsfw"] = sprayData.nsfw
	}


	if IsValid(targetEnt) then
		sprays[ply]["lvec"] = targetEnt:WorldToLocal(vec)
		sprays[ply]["lang"] = targetEnt:WorldToLocalAngles(ang)

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

	hook.Add("PostDrawTranslucentRenderables", thinkKey, function()
		local w, h = loadingMat()

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

	local function clean()
		hook.Remove("PostDrawTranslucentRenderables", thinkKey)
		hook.Remove("Think", thinkKey)
	end
	local function downloadImage(data)
		hook.Add("Think", thinkKey, function()
			local w, h, httpMat

			if spraycache[material] then
				w, h, httpMat = unpack(spraycache[material])
			else
				local mat = imgurls[data["url"]] or surface.URLImage(data["url"])
				imgurls[data["url"]] = mat
				w, h, httpMat = mat()
			end

			if w == nil or not IsValid(ply) or sprays[ply].material ~= material then clean() return end
			if not w then return end
			spraycache[material] = {w, h, httpMat}

			local _, _, baseSprayMat = baseSpray()
			if not baseSprayMat then return end

			clean()

			local matname = ("Sprayv2_%s_%s"):format(os.time(), util.CRC(material) or "")
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
					["Proxies"] = {AnimatedTexture = {animatedTextureVar = "$basetexture", animatedTextureFrameNumVar = "$frame", animatedTextureFrameRate = tonumber(data["frame_rate"]) or 8}},
					["$decal"] = 1
				})
			end

			local tex = httpMat:GetTexture("$basetexture")
			if tempMat and tex then
				tempMat:SetTexture("$basetexture", tex)
				tempMat:GetTexture("$basetexture"):Download()

				if not tempMat:IsError() and not tempMat:GetTexture("$basetexture"):IsError() then
					if not noSound and (sound and type(sound) == "table" and sound.Play) then
						sound.Play("SprayCan.Paint", vec)
					end

					local validEnt = IsValid(targetEnt)
					if validEnt then DetectCrash() end
					util.DecalEx(tempMat, validEnt and targetEnt or game.GetWorld(), vec, norm, Color(255, 255, 255), 0, 0, 1)
					if validEnt then timer.Simple(0.05, DetectCrashEnd) end

					sprays[ply]["spraymat"] = tempMat
					if data["steamid"] then
						sprays[ply]["o_steamid"] = data["steamid"]
					end
					hook.Remove("PostDrawTranslucentRenderables", ply:UniqueID() .. "SprayInfo")
				end
			end
		end)
	end

	GetSprayCache(material, "Spray", function(data)
		downloadImage(data)
	end,
	function(data)
		clean()
	end)
end

local function SprayReportUI(title, text, matName, default, callbackOK, callbackCancel, okText, cancelText)
	okText = okText or "OK"
	cancelText = cancelText or "Cancel"
	local w, h = 420, 128 + 50 + 10

	local frame = vgui.Create("DFrame")
	frame:SetTitle(title)
	frame:SetSize(w, h)
	frame:Center()
	frame:MakePopup()

	local img = vgui.Create("DImage", frame)
	img:SetPos(10, 50)
	img:SetSize(128, 128)
	local mat = spraycache[matName] and spraycache[matName][3]
	if mat and not mat:IsError() then
		img:SetMaterial(mat)
	end
	img.Paint = function(self, iW, iH)
		surface.SetDrawColor(40, 40, 40, 255)
		surface.DrawRect(0, 0, iW, iH)

		DImage.Paint(self, iW, iH)
	end

	local lbl2 = vgui.Create("DLabel", frame)
	lbl2:SetPos(10, 25)
	lbl2:SetSize(400, 20)
	lbl2:SetText(matName)

	local lbl = vgui.Create("DLabel", frame)
	lbl:SetPos(128 + 20, h -25 - 25 - 10 - 25)
	lbl:SetSize(250, 20)
	lbl:SetText(text)

	local entry = vgui.Create("DTextEntry", frame)
	entry:SetPos(128 + 20, h - 25 - 25 - 10)
	entry:SetSize(w - 128 - 20 - 10, 20)
	entry:SetText(default or "")
	entry:RequestFocus()

	local btnOK = vgui.Create("DButton", frame)
	btnOK:SetSize(100, 25)
	btnOK:SetPos(128 + 20, h - 25 - 10)
	btnOK:SetText(okText)
	btnOK.DoClick = function()
		if callbackOK then callbackOK(entry:GetText()) end
		frame:Close()
	end

	local btnCancel = vgui.Create("DButton", frame)
	btnCancel:SetSize(100, 25)
	btnCancel:SetPos(310, h - 25 - 10)
	btnCancel:SetText(cancelText)
	btnCancel.DoClick = function()
		if callbackCancel then callbackCancel(entry:GetText()) end
		frame:Close()
	end
end

local function handleClick(tbl)
	local ply = LocalPlayer()

	local function reportSpray()
		SprayReportUI(
			"Are you sure you want to report this spray?",
			"Insert reason",
			tbl.material,
			"",
			function(reason)
				if not reason or reason:Trim() == "" then
					ply:ChatPrint("You must provide a reason to report this spray.")
					return
				end

				if not isTokenValid() then
					requestToken()
					ply:ChatPrint("Requesting token, try again in a moment.")
					return
				end

				http.Post(REPORTSPRAY_URL, { url = tbl.material, token = getToken(), reason = reason },
					function(data, _, _, code)
						if code ~= 200 then
							if code == 429 then
								ply:ChatPrint("You're reporting sprays too fast! Slow down.")
							else
								ply:ChatPrint("Failed to report spray, backend error.")
							end
							return
						end

						local resp = util.JSONToTable(data)
						if resp and resp.status == STATUS.SUCCESS then
							ply:ChatPrint("Spray reported, thank you!")
						else
							ply:ChatPrint("Failed to report spray: " .. (resp and resp.status_text or "Unknown error"))
						end
					end,
					function()
						ply:ChatPrint("Failed to report spray, backend error.")
					end
				)
			end,
			function() end,
			"Yes",
			"Cancel"
		)
	end

	if ply:KeyDown(IN_WALK) then
		if ply:KeyDown(IN_DUCK) then
			reportSpray()
		elseif tbl.o_steamid then
			gui.OpenURL(string.format("https://steamcommunity.com/profiles/%s", tbl.o_steamid))
		end
		return
	end

	local copyTbl = table.Copy(tbl)
	copyTbl.vec = nil
	copyTbl.ang = nil
	copyTbl.ent = nil

	local infoJSON = util.TableToJSON(copyTbl, true)
	SetClipboardText(infoJSON)
	ply:ChatPrint("Spray info copied to clipboard!")
end

local lastKeyAttack = false
hook.Add("PostDrawTranslucentRenderables", "SprayInfo", function()
	local inSpeed = LocalPlayer():KeyDown(IN_SPEED)
	local firstClick = true
	for k,tbl in pairs(sprays) do
		if tbl and inSpeed then
			local vec = tbl.vec
			local ply = tbl.ply
			local ang = tbl.ang
			local material = tbl.material

			if IsValid(tbl.ent) then
				vec = tbl.ent:LocalToWorld(tbl.lvec)
				ang = tbl.ent:LocalToWorldAngles(tbl.lang)
			end

			local ply_id = IsValid(ply) and ply:SteamID() or tbl.steamID
			local ply_name = IsValid(ply) and ply:Nick() or tbl.nick
			local scale = 0.1
			cam.Start3D2D(vec + ang:Up() * 0.1 - ang:Forward() * SpraySize / 2 - ang:Right() * SpraySize / 2, ang, scale)
				local w,h = SpraySize * 1 / scale, SpraySize * 1 / scale
				local baseY = 0
				local lineHeight = 25

				local lines = {
					{ text = "Player: " .. ply_name, font = "SprayFontInfo", color = Color(255, 255, 255, 255) },
					{ text = "Player ID: " .. ply_id, font = "SprayFontInfo", color = Color(255, 255, 255, 255) },
				}

				if tbl.o_steamid then
					table.insert(lines, { text = "Poster ID: " .. tbl.o_steamid, font = "SprayFontInfo", color = Color(255, 255, 255) })
				end

				table.insert(lines, { text = "URL: " .. material, font = "SprayFontInfo2", color = Color(255, 255, 255, 255) })
				if tbl.nsfw then
					table.insert(lines, { text = "!! Marked NSFW !!", font = "SprayFontInfo", color = Color(255, 0, 0) })
				end

				for i, line in ipairs(lines) do
					draw.Text({
						pos = {0, baseY + lineHeight * (i - 1)},
						color = line.color,
						text = line.text,
						font = line.font,
						xalign = TEXT_ALIGN_LEFT,
						yalign = TEXT_ALIGN_TOP,
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
				if LocalPlayer():KeyDown(IN_ATTACK) and not lastKeyAttack then
					local trace = LocalPlayer():GetEyeTrace()
					if trace.HitPos:Distance(vec) < selectsize and firstClick then
						handleClick(tbl)
						firstClick = false
					end
				end
			cam.End3D2D()
		end
	end
	lastKeyAttack = LocalPlayer():KeyDown(IN_ATTACK)
end)

concommand.Add("sprayv2_random", function(ply, cmd, args)
	if not isTokenValid() then
		return requestToken()
	end

	http.Post(RANDOMSPRAY_URL, {["token"] = getToken()}, function(data, _, _, code)
		if code ~= 200 then return end

		favorites.selected = {url = data, nsfw = true}
		if (not args or #args == 0) or tobool(args[1]) then
			-- Send a request to spray the image
			net.Start("Sprayv2")
				net.WriteInt(NET.Spray, 8)
				net.WriteTable(favorites.selected)
			net.SendToServer()
		end

		WriteFavorites()
		if LocalPlayer().SetNetData then LocalPlayer():SetNetData("sprayv2", favorites.selected) end
	end)
end)


concommand.Add("sprayv2_clear", function(ply, cmd, args)
	favorites.selected = nil

	WriteFavorites()
	if LocalPlayer().SetNetData then LocalPlayer():SetNetData("sprayv2", favorites.selected) end
end)


concommand.Add("sprayv2_openfavorites", function()
	if IsValid(FavoritePanel) then
		FavoritePanel:Remove()
	end

	FavoritePanel = vgui.Create("DSprayFavoritePanel")
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
					if tonumber(k) and v == self.tab then
						self.Index = tonumber(k)
					end
				end

				if not self.Index then
					self:PopulateParent()
					return
				end

				table.remove(currentFolder, self.Index)
				WriteFavorites()
				self:PopulateParent()
			end
		end,"No",function() end)
	end

	function self.NSFWButton.DoClick(button)
		self.tab.nsfw = not self.tab.nsfw
		if favorites.selected and favorites.selected.url == self.tab.url then
			favorites.selected = self.tab
		end

		http.Post(SPRAYADD_URL, {["url"] = favorites.selected.url, ["token"] = getToken(), ["nsfw"] = favorites.selected.nsfw and "1" or "0"})
		WriteFavorites()
		self:PopulateParent()
	end

	self.Checkmark = Material("icon16/accept.png")
	self.IsFolder = false
	self:Droppable( "spraypanel" )
	self:Receiver("spraypanel", self.HandleDrop)
end

function SprayPanel:HandleDrop(tableOfDroppedPanels, isDropped, menuIndex, mouseX, mouseY)
	if not isDropped then return end
	if self.IsFolder then
		local drop = self.tab.contents
		if self.PreviousButton then
			drop = previousFolderStack[#previousFolderStack]
		end
		for k,v in pairs(tableOfDroppedPanels) do
			if self ~= v then
				table.insert(drop, v.tab)
				for k2,v2 in pairs(currentFolder) do
					if v2 == v.tab then v.Index = k2 end
				end

				if isnumber(v.Index) then
					table.remove(currentFolder, v.Index)
				end
			end
		end
		WriteFavorites()
		self:PopulateParent()
	else
		Derma_StringRequest("Create Folder", "Name the new folder", "", function(str)
			local newFolder = {}
			newFolder.isFolder = true
			newFolder.name = str
			newFolder.url = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/folder_forward.png"
			newFolder.contents = {}
			local function AddPanel(v)
				table.insert(newFolder.contents, v.tab)
				for k2,v2 in pairs(currentFolder) do
					if v2 == v.tab then v.Index = k2 end
				end

				if isnumber(v.Index) then
					table.remove(currentFolder, v.Index)
				end
			end

			for k,v in pairs(tableOfDroppedPanels) do
				if v ~= self then
					AddPanel(v)
				end
			end
			AddPanel(self)
			table.insert(currentFolder, newFolder)
			WriteFavorites()
			self:PopulateParent()
		end, function() end, "Create", "Cancel")
	end
end

function SprayPanel:PopulateParent()
	local t = self
	while IsValid(t) and not t.Populate do
		t = t:GetParent()
	end
	if not IsValid(t) or not t.Populate then return end
	t:Populate()
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
				WriteFavorites()
				self:PopulateParent()
			end, function() end, "Rename", "Cancel")
		end

		self.ChangeImageButton = vgui.Create("DImageButton", self)
		self.ChangeImageButton:SetSize(16, 16)
		self.ChangeImageButton:SetImage("icon16/image_edit.png")
		function self.ChangeImageButton.DoClick(button)
			Derma_StringRequest("Change Folder Image", "Enter a new image", self.tab.url, function(str)
				self.tab.url = str
				WriteFavorites()
				self:PopulateParent()
			end, function()
				self.tab.url = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/folder_forward.png"
				WriteFavorites()
				self:PopulateParent()
			end, "Change", "Default")
		end
	end
end

function SprayPanel:SetSpray(str)
	self.SprayURL = str
	GetSprayCache(str, "UI", function(data)
		if IsValid(self) then
			self.Mat = surface.URLImage(data["url"])
		end
	end)
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

	if IsValid(self.ChangeImageButton) then
		self.ChangeImageButton:SetPos(0, 0)
	end

	if IsValid(self.NSFWButton) then
		self.NSFWButton:SetPos(0, 0)
	end
end

function SprayPanel:Paint(pw, ph)
	surface.SetDrawColor(Color(20, 20, 20))
	surface.DrawRect(0, 0, pw, ph)
	if self.Mat then
		local w, h = self.Mat()
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
	else
		local spray = favorites.selected
		if spray and spray.url == self.SprayURL then
			surface.SetMaterial(self.Checkmark)
			surface.SetDrawColor(Color(255, 255, 255))
			surface.DrawTexturedRect(0, ph - 16, 16, 16)
		end
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
		self:PopulateParent()
		return
	end

	if CurTime() - (self.lastSelect or 0) <= 0.2 then return end
	self.lastSelect = CurTime()

	local spray = favorites.selected
	if spray and spray.url == self.SprayURL then
		favorites.selected = nil
	else
		favorites.selected = self.tab
		http.Post(SPRAYADD_URL, {["url"] = favorites.selected.url, ["token"] = getToken(), ["nsfw"] = favorites.selected.nsfw and "1" or "0"})
	end

	WriteFavorites()
	if LocalPlayer().SetNetData then LocalPlayer():SetNetData("sprayv2", favorites.selected) end
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

local DFavoritePanel = {}
function DFavoritePanel:Init()
	self:SetCookieName("Sprayv2Favorites")
	self:SetSize(self:GetCookieNumber("w", 420), self:GetCookieNumber("h", 525))
	self:SetPos(self:GetCookieNumber("x", 5), self:GetCookieNumber("y", 5))
	self:SetTitle("Spray Favorites")
	self:SetSizable(true)
	self:SetDraggable(true)

	self.Scroll = vgui.Create( "DScrollPanel", self)
	function self.Scroll:Paint(pw, ph)
		surface.SetTexture(0)
		surface.SetDrawColor(Color(50, 50, 50))
		surface.DrawRect(0, 0, pw, ph)
	end

	self.List = vgui.Create( "DIconLayout", self.Scroll)

	self.SprayRoulette = vgui.Create("DImageButton", self)
	self.SprayRoulette:SetSize(16, 16)
	self.SprayRoulette:SetImage("icon16/cog.png")
	self.SprayRoulette:SetTooltip("Random Spray! (use with caution)")
	function self.SprayRoulette:DoClick()
		RunConsoleCommand("sprayv2_random", "0")
	end

	self.ClearSpray = vgui.Create("DImageButton", self)
	self.ClearSpray:SetSize(16, 16)
	self.ClearSpray:SetImage("icon16/bomb.png")
	self.ClearSpray:SetTooltip("Clear Spray Selection")
	function self.ClearSpray:DoClick()
		RunConsoleCommand("sprayv2_clear")
	end

	self.SaveSpray = vgui.Create("DImageButton", self)
	self.SaveSpray:SetSize(16, 16)
	self.SaveSpray:SetImage("icon16/picture_save.png")
	self.SaveSpray:SetTooltip("Save current spray")
	function self.SaveSpray:DoClick()
		AddSpray(favorites.selected)
	end

	self.AddFavorite = vgui.Create("DButton", self)
	self.AddFavorite:SetSize(10, 20)
	self.AddFavorite:Dock(BOTTOM)
	self.AddFavorite:SetText("Add Favorite")
	function self.AddFavorite:DoClick()
		Derma_StringRequest("Add a favorite", "URL", "", function(text)
			AddSpray{url = text, nsfw = false}
		end)
	end

	self.Scale = vgui.Create("DNumSlider", self)
	self.Scale:SetText("")
	self.Scale:SetSize(200, 16)
	self.Scale:SetMin(0.25)
	self.Scale:SetMax(2)
	self.Scale:SetValue(self:GetCookieNumber("scale", 1))
	function self.Scale.OnValueChanged()
		self:Populate()
	end

	self:Populate()
	self:MakePopup()
end

function DFavoritePanel:OnClose()
	local w, h = self:GetSize()
	local x, y = self:GetPos()
	self:SetCookie("w", w)
	self:SetCookie("h", h)
	self:SetCookie("x", x)
	self:SetCookie("y", y)
	self:SetCookie("scale", self.Scale:GetValue())

	DFrame.OnClose(self)
end

function DFavoritePanel:PerformLayout()
	local w, _ = self:GetSize()

	self.Scroll:Dock(FILL)
	self.List:Dock(FILL)
	self.List:SetSpaceY( 5 )
	self.List:SetSpaceX( 5 )


	self.SaveSpray:SetPos(w - 120, 5)
	self.ClearSpray:SetPos(w - 144, 5)
	self.SprayRoulette:SetPos(w - 168, 5)
	self.Scale:SetPos(w - 168 - 200, 5)

	DFrame.PerformLayout(self)
end

function DFavoritePanel:Populate()
	self.List:Clear()

	local sizeMul = self.Scale:GetValue()
	local function AddButton(v, folder, tab)
		local SprayPan = vgui.Create("DSprayPanel", self.List)
		SprayPan:SetSize(128 / sizeMul, 128 / sizeMul)
		SprayPan:SetSpray(v.url or "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/folder_forward.png")
		SprayPan:SetFavoriteTab(v)
		if folder then
			SprayPan:MakeFolder(tab)
		end
		self.List:Add(SprayPan)
	end

	local files, folders = {}, {}
	for k,v in pairs(currentFolder) do
		if not tonumber(k) then continue end
		if v.isFolder or (v.name and v.name ~= "") then
			table.insert(folders, v)
		elseif v.url and v.url ~= "" then
			if v.superfav ~= nil then v.superfav = nil end
			table.insert(files, v)
		end
	end

	table.sort(files, function(a, b) return a.url < b.url end)
	table.sort(folders, function(a, b) return a.name < b.name end)

	if #previousFolderStack > 0 then
		AddButton({url = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/folder_back.png", name = "Back"}, true, previousFolderStack[#previousFolderStack])
	end

	for k,v in pairs(folders) do
		AddButton(v, true)
	end

	for k,v in pairs(files) do
		AddButton(v)
	end

	self.List:Layout()
	self.Scroll:PerformLayout()
end

vgui.Register("DSprayFavoritePanel", DFavoritePanel, "DFrame")


list.Set("DesktopWindows", "sprayv2", {
	title = "Sprays",
	icon = "icon16/folder_image.png",
	width = 1,
	height = 1,
	onewindow = true,
	init = function(icn, pnl)
		pnl:Remove()

		RunConsoleCommand("sprayv2_openfavorites")
	end
})