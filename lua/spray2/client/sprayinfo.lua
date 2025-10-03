local spray2 = _G.spray2
local surface = surface
local cam = cam

local sprayButtons = {
    {
        condition = function() return true end,
        pos_x = 0.5,
        pos_y = 0.5,
        size = 8,
        color = Color(0, 150, 0, 150),
        text = {
            {
                text = "Copy Info",
                offset_x = 0,
                offset_y = -12.5,
                font = "SprayFont",
                color = Color(255, 255, 255, 255),
            },
            {
                text = "(Left Click)",
                offset_x = 0,
                offset_y = 12.5,
                font = "SprayFont",
                color = Color(100, 100, 100, 255),
            },
        },
        click = function(tbl)
            local copyTbl = table.Copy(tbl)
            copyTbl.vec = nil
            copyTbl.ang = nil
            copyTbl.ent = nil

            local infoJSON = util.TableToJSON(copyTbl, true)
            SetClipboardText(infoJSON)
            LocalPlayer():ChatPrint("Spray info copied to clipboard!")
        end
    },
    {
        condition = function(tbl) return tbl.o_steamid ~= nil end,
        pos_x = 0.1,
        pos_y = 0.9,
        size = 4,
        color = Color(0, 0, 150, 150),
        text = {
            {
                text = "Poster's Profile",
                offset_x = 0,
                offset_y = 0,
                font = "SprayFont2",
                color = Color(255, 255, 255, 255),
            }
        },
        click = function(tbl)
            if not tbl.o_steamid then return end
            gui.OpenURL(string.format("https://steamcommunity.com/profiles/%s", tbl.o_steamid))
        end
    },
    {
        condition = function() return true end,
        pos_x = 0.9,
        pos_y = 0.9,
        size = 4,
        color = Color(150, 0, 0, 150),
        text = {
            {
                text = "Report Spray!",
                offset_x = 0,
                offset_y = 0,
                font = "SprayFont2",
                color = Color(255, 255, 255, 255),
            }
        },
        click = function(tbl)
            local ply = LocalPlayer()
            spray2.SprayReportUI(
                "Are you sure you want to report this spray?",
                "Insert reason",
                tbl.material,
                "",
                function(reason)
                    local function postReport()
                        if not spray2.IsTokenValid() then return end
                        local postData = {
                            url = tbl.material,
                            token = spray2.GetToken(),
                            reason = reason,
                            sprayer = {
                                steamid = tbl.steamID,
                                nick = tbl.nick,
                                realnick = tbl.realnick,
                                nsfw = tbl.nsfw,
                            },
                        }

                        local postBody = util.TableToJSON(postData)
                        HTTP({
                            url = URLS.REPORTSPRAY,
                            method = "POST",
                            headers = {
                                ["Content-Length"] = #postBody
                            },
                            type = "application/json",
                            body = postBody,
                            success = function(code, body, headers)
                                if code ~= 200 then
                                    if code == 429 then
                                        ply:ChatPrint("You're reporting sprays too fast! Slow down.")
                                    else
                                        ply:ChatPrint("Failed to report spray, backend error.")
                                    end
                                    return
                                end

                                local resp = util.JSONToTable(body)
                                if resp and resp.status == STATUS.SUCCESS then
                                    ply:ChatPrint("Spray reported, thank you!")
                                else
                                    ply:ChatPrint("Failed to report spray: " .. (resp and resp.status_text or "Unknown error"))
                                end
                            end,
                            failed = function(err)
                                ply:ChatPrint("Failed to report spray, backend error: " .. tostring(err))
                            end
                        })
                    end
                    if not reason or reason:Trim() == "" then
                        ply:ChatPrint("You must provide a reason to report this spray.")
                        return
                    end

                    if not spray2.IsTokenValid() then
                        spray2.PushForTokenWaiting("reportRequestToken", postReport)
                        spray2.RequestToken()
                        return
                    end

                    postReport()
                end,
                function() end,
                "Yes",
                "Cancel"
            )
        end
    }
}

local SpraySize = 64
local lastKeyAttack = false
local sprayScale = 0.1
local sprayInfoW, sprayInfoH = SpraySize * 1 / sprayScale, SpraySize * 1 / sprayScale
hook.Add("PostDrawTranslucentRenderables", "SprayInfo", function()
    local inSpeed = LocalPlayer():KeyDown(IN_SPEED)
    if not inSpeed then
        lastKeyAttack = LocalPlayer():KeyDown(IN_ATTACK)
        return
    end

    local firstClick = true
    for ply, tbl in pairs(spray2.sprays) do
        local vec = tbl.vec
        local ang = tbl.ang
        local material = tbl.material

        if IsValid(tbl.ent) then
            vec = tbl.ent:LocalToWorld(tbl.lvec)
            ang = tbl.ent:LocalToWorldAngles(tbl.lang)
        elseif tbl.ent ~= nil and tbl.ent ~= game.GetWorld() then
            continue
        end

        local ply_id = IsValid(ply) and ply:SteamID64() or tbl.steamID
        local ply_name = IsValid(ply) and ply:Nick() or tbl.nick
        local canvasOrigin = vec + ang:Up() * 0.1 - ang:Forward() * SpraySize / 2 - ang:Right() * SpraySize / 2
        cam.Start3D2D(canvasOrigin, ang, sprayScale)
            local baseY = 0
            local lineHeight = 25

            local lines = {
                { text = "Sprayer: " .. ply_name, font = "SprayFontInfo", color = Color(255, 255, 255, 255) },
                { text = "Sprayer ID: " .. ply_id, font = "SprayFontInfo", color = Color(255, 255, 255, 255) },
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

                table.insert( cir, {
                    x = x,
                    y = y,
                    u = 0.5,
                    v = 0.5
                })

                for i = 0, seg do
                    local a = math.rad( ( i / seg ) * -360 )
                    table.insert(cir, {
                        x = x + math.sin( a ) * radius,
                        y = y + math.cos( a ) * radius,
                        u = math.sin( a ) / 2 + 0.5,
                        v = math.cos( a ) / 2 + 0.5
                    })
                end

                surface.DrawPoly( cir )
            end

            local function handleButton(button)
                local selectsize = button.size

                local pos_x, pos_y = sprayInfoW * button.pos_x, sprayInfoH * button.pos_y
                surface.SetTexture(0)
                surface.SetDrawColor(button.color)

                drawCircle(pos_x, pos_y, selectsize * 1 / sprayScale, 30)

                for _, text in ipairs(button.text) do
                    draw.Text({
                        ["pos"] = {
                            pos_x + text.offset_x,
                            pos_y + text.offset_y
                        },
                        ["color"] = text.color,
                        ["text"] = text.text,
                        ["font"] = text.font,
                        ["xalign"] = TEXT_ALIGN_CENTER,
                        ["yalign"] = TEXT_ALIGN_CENTER,
                    })
                end

                local worldPos = canvasOrigin
                    + ang:Forward() * (pos_x * sprayScale)
                    + ang:Right() * (pos_y * sprayScale)

                if LocalPlayer():KeyDown(IN_ATTACK) and not lastKeyAttack then
                    local hitPos = util.IntersectRayWithPlane(
                        LocalPlayer():EyePos(),
                        LocalPlayer():GetAimVector(),
                        canvasOrigin,
                        ang:Up()
                    )
                    if hitPos and hitPos:Distance(worldPos) < selectsize and firstClick then
                        button.click(tbl)
                        firstClick = false
                    end
                end
            end

            for _, button in ipairs(sprayButtons) do
                if button.condition(tbl) then
                    handleButton(button)
                end
            end
        cam.End3D2D()
    end
    lastKeyAttack = LocalPlayer():KeyDown(IN_ATTACK)
end)