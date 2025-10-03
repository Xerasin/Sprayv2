pcall(require, "urlimage")
local spray2 = _G.spray2
local _, _, _, NET = spray2.URLS, spray2.STATUS, spray2.STATUS_NAME, spray2.NET
local surface = surface
local cam = cam

-- Turns out this is still needed, I'd like for it not to be cause it's a hack
-- RunConsoleCommand("r_drawbatchdecals", "0")

--local CurrentSpray = CreateClientConVar("sprayv2_spray", "", true, true)
local NSFW_SPRAY = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/nsfw.png"
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

local sprays = spray2.sprays or {}
spray2.sprays = sprays
local spraymaterialcache = spray2.spraymaterialcache or {}
spray2.spraymaterialcache = spraymaterialcache
local entitycache = spray2.entitycache or {}
spray2.entitycache = entitycache
local nsfwcache = spray2.nsfwcache or {}
spray2.nsfwcache = nsfwcache

local is_down = false
local lastSprayTime = 0
local sprayCooldown = 0.25

local function getSprayTrace()
    local trace = LocalPlayer():GetEyeTrace()
    return trace, trace.StartPos:Distance(trace.HitPos)
end

hook.Add("PlayerBindPress", "sprayv2", function(ply, bind, pressed)
    if pressed and bind and bind:find("impulse 201") and spray2.GetCurrentSpray() then
        local _, dist = getSprayTrace()
        if dist <= 200 then
            is_down = true
            return true
        end
    elseif pressed and bind == "+attack" and is_down then
        is_down = false
        return true
    end
end)

hook.Add("Think", "sprayv2", function()
    if is_down then
        local _, dist = getSprayTrace()
        if dist >= 205 then
            is_down = false
        end
    end
end)

hook.Add("CreateMove", "sprayv2", function()
    local key = input.LookupBinding("impulse 201")
    if not key then return end
    local keyCode = input.GetKeyCode(key)
    local currentSpray = spray2.GetCurrentSpray()

    if is_down and input.WasKeyReleased(keyCode) and currentSpray then
        is_down = false
        spray2.SendSpray(currentSpray)
    end
end)

function spray2.SendSpray(currentSpray)
    currentSpray = currentSpray or spray2.GetCurrentSpray()
    if CurTime() - lastSprayTime >= sprayCooldown then
        lastSprayTime = CurTime()

        net.Start("Sprayv2")
            net.WriteInt(NET.Spray, 8)
            net.WriteTable(currentSpray)
        net.SendToServer()
    else
        sound.Play("ui/beep_error01.wav", LocalPlayer():GetPos(), 75, 100, 0.5)
    end
end

hook.Add("HUDPaint", "sprayv2_preview", function()
    if not is_down then return end

    local keyName = input.LookupBinding("+attack", true) or "<+attack not bound>"
    local bound = keyName ~= "<+attack not bound>"
    keyName = "[" .. keyName:upper() .. "]"

    local helpText = " to cancel"
    surface.SetFont("CloseCaption_Normal")
    local tw, th = surface.GetTextSize(keyName .. helpText)
    local x, y = ScrW() / 2 - tw / 2, ScrH() / 2 + th * 2

    surface.SetTextPos(x + 2, y + 2)
    surface.SetTextColor(0, 0, 0, 128)
    surface.DrawText(keyName .. helpText)

    surface.SetTextPos(x, y)
    surface.SetTextColor(bound and Color(128, 255, 128) or Color(255, 128, 128))
    local kw = surface.GetTextSize(keyName)
    surface.DrawText(keyName)

    surface.SetTextPos(x + kw, y)
    surface.SetTextColor(Color(192, 192, 192))
    surface.DrawText(helpText)
end)

local imgurls = {}
local function drawSprayPreview(spray, vec, norm)
    local material = (spray.nsfw and not showNSFW:GetBool()) and NSFW_SPRAY or spray.url
    if not material or material == "" then return end

    local outputURL, errorText
    spray2.GetSprayCache(material, "Preview",
        function(data) outputURL = data.url end,
        function(data) errorText = data.status_text end
    )

    local mat
    if outputURL then
        mat = imgurls[outputURL] or surface.URLImage(outputURL)
        imgurls[outputURL] = mat
    end

    local w, h, httpMat
    if spraymaterialcache[material] then
        w, h, httpMat = unpack(spraymaterialcache[material])
    elseif mat then
        w, h, httpMat = mat()
        if w and h then spraymaterialcache[material] = {w, h, httpMat} end
    end

    local alpha = 0.5
    local angUp = Vector(0, 0, 1)
    if norm.Z == 1 then angUp = Vector(0, 1, 0) end
    if norm.Z == -1 then angUp = Vector(0, -1, 0) end
    local ang = norm:AngleEx(angUp)
    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(vec + ang:Up() * 0.1, ang, w and h and 1 or 0.35)
        surface.SetAlphaMultiplier(alpha)
        if httpMat then
            surface.SetMaterial(httpMat)
            surface.SetDrawColor(Color(255, 255, 255))
            surface.DrawTexturedRect(-32, -32, 64, 64)
        else
            local lw, lh = loadingMat()
            if lw and lh then
                surface.SetDrawColor(Color(255, 255, 255))
                surface.DrawTexturedRect(-32, -32 - 16, 64, 64)
            end
            draw.Text({
                pos = {0, 32},
                color = Color(100, 100, 255, 255),
                text = errorText or "Loading...",
                font = "SprayFont",
                xalign = TEXT_ALIGN_CENTER,
                yalign = TEXT_ALIGN_CENTER,
            })
        end
        surface.SetAlphaMultiplier(1)
    cam.End3D2D()
end

hook.Add("PostDrawTranslucentRenderables", "sprayv2_preview", function()
    if not is_down or not surface.URLImage then return end

    local spray = spray2.GetCurrentSpray()
    if not spray then return end

    local trace = LocalPlayer():GetEyeTrace()
    drawSprayPreview(spray, trace.HitPos, trace.HitNormal)
end)

surface.CreateFont("SprayFavoritesFolderFont", {
    font = "arial",
    size = 12,
    weight = 450,
    antialias = true,
    outline = false,
    additive = false,
    shadow = false
} )

surface.CreateFont( "SprayFont", {
    font         = "Default",
    size         = 25,
    weight         = 450,
    antialias     = true,
    additive     = false,
    shadow         = false,
    outline     = false
} )

surface.CreateFont( "SprayFont2", {
    font         = "Default",
    size         = 12,
    weight         = 450,
    antialias     = true,
    additive     = false,
    shadow         = false,
    outline     = false
} )


surface.CreateFont( "SprayFontInfo", {
    font         = "Default",
    size         = 25,
    weight         = 450,
    antialias     = true,
    additive     = false,
    shadow         = false,
    outline     = true
} )

surface.CreateFont( "SprayFontInfo2", {
    font         = "Default",
    size         = 15,
    weight         = 450,
    antialias     = true,
    additive     = false,
    shadow         = false,
    outline     = true
} )

function spray2.DetectCrash()
    file.Write("_spray2_crash.txt", "BEGIN")
end

function spray2.DetectCrashEnd()
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
        local wasCreated = net.ReadBool()
        if wasCreated then
            local sprayToken = net.ReadString()
            local expiryTime = net.ReadUInt(32)
            if sprayToken then
                spray2.SetToken{token = sprayToken, expiry = expiryTime}
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

hook.Add("InitPostEntity", "Sprayv2", function()
    local currentSpray = spray2.GetCurrentSpray()
    if favorites and currentSpray and currentSpray.url and currentSpray.url ~= "" and LocalPlayer().SetNetData then
        LocalPlayer():SetNetData("sprayv2", currentSpray)
    end

    timer.Simple(0, function()
        if not spray2.IsTokenValid() then
            spray2.RequestToken()
        end
    end)
end)

cvars.AddChangeCallback("sprayv2_nsfw", function(name, old, new)
    if tobool(new) and table.Count(nsfwcache) > 0 then
        for k, v in pairs(nsfwcache) do
            if IsValid(v[1]) then
                spray2.Spray(unpack(v))
            end
        end
        nsfwcache = {}
    end
end, "Spray2NSFW")

local pmeta = FindMetaTable("Player")

function pmeta:StripSpray2()
    if not sprays[self] then return end

    local sprayMat = sprays[self]["spraymat"]
    local thinkKey = "URLDownload" .. self:EntIndex()

    hook.Remove("Think", thinkKey)
    hook.Remove("PostDrawTranslucentRenderables", thinkKey)

    if sprayMat then
        sprayMat:SetString("$alpha", "0")
        sprayMat:SetString("$alphatest", "1")
        sprayMat:SetString("$ignorez", "1")
        sprayMat:SetString("$basetexturetransform", "center 0.5 0.5 scale 0 0 rotate 0 translate 0 0")

        local _, _, baseMat = baseSpray()
        if baseMat then
            sprayMat:SetTexture("$basetexture", baseMat:GetTexture("$basetexture"))
        else
            sprayMat:SetTexture("$basetexture", "vgui/notices/error")
        end
    end

    sprays[self] = nil
end

local function CreateSprayMaterial(baseMat, materialName, data, targetEnt)
    local matname = ("Sprayv2_%s_%s"):format(os.time(), util.CRC(materialName) or "")
    if IsValid(targetEnt) then
        return CreateMaterial(matname, "VertexLitGeneric", {
            ["$basetexture"] = baseMat:GetString("$basetexture"),
            ["$basetexturetransform"] = "center 0.5 0.5 scale 1 1 rotate 0 translate 0 0",
            ["$vertexalpha"] = 1,
            ["$decal"] = 1
        })
    else
        return CreateMaterial(matname, "LightmappedGeneric", {
            ["$basetexture"] = baseMat:GetString("$basetexture"),
            ["$basetexturetransform"] = "center 0.5 0.5 scale 1 1 rotate 0 translate 0 0",
            ["$vertexcolor"] = 1,
            ["$vertexalpha"] = 1,
            ["$transparent"] = 1,
            ["$nolod"] = 1,
            ["Proxies"] = {
                AnimatedTexture = {
                    animatedTextureVar = "$basetexture",
                    animatedTextureFrameNumVar = "$frame",
                    animatedTextureFrameRate = tonumber(data["frame_rate"]) or 8
                }
            },
            ["$decal"] = 1
        })
    end
end

function spray2.Spray(ply, material, vec, norm, targetEnt, noSound, sprayData)
    if not IsValid(ply) or not surface.URLImage then return end
    if not material then return end

    if sprays[ply] and sprays[ply].inProgress then return end
    sprays[ply] = sprays[ply] or {}
    sprays[ply].inProgress = true

    if sprayData and sprayData.nsfw and not showNSFW:GetBool() then
        nsfwcache[ply:SteamID64()] = {ply, material, vec, norm, targetEnt, noSound, sprayData}
        material = NSFW_SPRAY
    end

    ply:StripSpray2()
    local thinkKey = "URLDownload" .. ply:EntIndex()

    local up = Vector(0, 0, 1)
    if norm.Z == 1 then up = Vector(0, 1, 0) end
    if norm.Z == -1 then up = Vector(0, -1, 0) end

    local ang = norm:AngleEx(up)
    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    sprays[ply] = {
        ["material"] = material,
        ["steamID"] = ply:SteamID64(),
        ["nick"] = ply:Nick(),
        ["realnick"] = ply.RealNick and ply:RealNick() or "",
        ["vec"] = vec,
        ["ang"] = ang,
        ["ent"] = targetEnt,
        ["nsfw"] = sprayData.nsfw,
        ["inProgress"] = true
    }

    if IsValid(targetEnt) then
        sprays[ply]["lvec"] = targetEnt:WorldToLocal(vec)
        sprays[ply]["lang"] = targetEnt:WorldToLocalAngles(ang)

        if not sprayProps:GetBool() then
            sound.Play("ui/beep_error01.wav", vec, 75, 100, 0.5)
            sprays[ply].inProgress = nil
            return false
        end

        if CrashDetected then
            sound.Play("ui/beep_error01.wav", vec, 75, 100, 0.5)
            chat.AddText(Color(255, 0, 0), "WARNING! ", Color(255, 255, 255), "Spraying on entities has been disabled due to you crashing, renable with sprayv2_entities 1.")
            sprayProps:SetInt(0)
            sprays[ply].inProgress = nil
            return false
        end

        local vertCount = 0
        if targetEnt:GetModel() then
            local modelMesh = util.GetModelMeshes(targetEnt:GetModel())
            if modelMesh then
                for k, v in pairs(modelMesh) do
                    if v["verticies"] then
                        vertCount = vertCount + #v["verticies"]
                    end
                end

                if vertCount > maxVertex:GetInt() then
                    sound.Play("ui/beep_error01.wav", vec, 75, 100, 0.5)
                    sprays[ply].inProgress = nil
                    return false
                end
            else
                sprays[ply].inProgress = nil
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
        if sprays[ply] then
            sprays[ply].inProgress = nil
        end
    end

    local downloadImage
    downloadImage = function(data)
        if material ~= NSFW_SPRAY then
            if data["steamid"] and data["steamid"] ~= "0" then
                sprays[ply]["o_steamid"] = data["steamid"]
            end

            if data["nsfw"] and not showNSFW:GetBool() then
                nsfwcache[ply:SteamID64()] = {ply, material, vec, norm, targetEnt, noSound, sprayData}
                material = NSFW_SPRAY
                sprays[ply].material = material
                spray2.GetSprayCache(material, "Spray", downloadImage, clean)
                return
            end
        end

        hook.Add("Think", thinkKey, function()
            local w, h, httpMat

            if spraymaterialcache[material] then
                w, h, httpMat = unpack(spraymaterialcache[material])
            else
                local mat = imgurls[data["url"]] or surface.URLImage(data["url"])
                imgurls[data["url"]] = mat
                w, h, httpMat = mat()
            end

            if w == nil or not IsValid(ply) or sprays[ply].material ~= material then clean() return end
            if not w then return end
            spraymaterialcache[material] = {w, h, httpMat}

            local _, _, baseSprayMat = baseSpray()
            if not baseSprayMat then return end

            clean()

            local tempMat = CreateSprayMaterial(baseSprayMat, material, data, targetEnt)

            local tex = httpMat:GetTexture("$basetexture")
            if tempMat and tex then
                tempMat:SetTexture("$basetexture", tex)
                tempMat:GetTexture("$basetexture"):Download()

                if not tempMat:IsError() and not tempMat:GetTexture("$basetexture"):IsError() then
                    if not noSound then
                        sound.Play("SprayCan.Paint", vec)
                    end

                    local validEnt = IsValid(targetEnt)
                    if validEnt then spray2.DetectCrash() end
                    util.DecalEx(tempMat, validEnt and targetEnt or game.GetWorld(), vec, norm, Color(255, 255, 255), 0, 0, 1)
                    if validEnt then timer.Simple(0.05, spray2.DetectCrashEnd) end

                    sprays[ply]["spraymat"] = tempMat
                end
            end
        end)
    end

    spray2.GetSprayCache(material, "Spray", function(data)
        downloadImage(data)
    end, function(data)
        clean()
    end)
end

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