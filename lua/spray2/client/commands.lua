local spray2 = _G.spray2
local URLS, STATUS_NAME = spray2.URLS, spray2.STATUS_NAME

local nextTime = -1
concommand.Add("sprayv2_random", function(ply, cmd, args)
    if nextTime > CurTime() then
        return
    end

    local nsfw = GetConVar("sprayv2_nsfw"):GetBool()
    local runRandom runRandom = function()
        local function PushForToken()
            spray2.PushForTokenWaiting("RandomSpray", runRandom)
            spray2.RequestToken()
        end

        if not spray2.IsTokenValid() then
            return PushForToken()
        end

        http.Post(URLS.RANDOMSPRAY, {["token"] = spray2.GetToken(), ["nsfw"] = nsfw}, function(data, _, _, code)
            if code ~= 200 then return end

            data = util.JSONToTable(data)
            if not data or not data["status"] or data["status"] < 0 then
                LocalPlayer():ChatPrint("Error fetching random spray: Invalid response")
                return
            end

            nextTime = CurTime() + (data["next_spray_time"] or 0.1)
            spray2.SetCurrentSpray({url = data["random_url_hash"], nsfw = data["nsfw"]})
            spray2.WriteFavorites()

            if (not args or #args == 0) or tobool(args[1]) then
                spray2.SendSpray()
            end
        end)
    end

    runRandom()
end)


concommand.Add("sprayv2_clear", function(ply, cmd, args)
    spray2.SetCurrentSpray(nil)

    spray2.WriteFavorites()
end, nil, "Clears your currently selected Sprayv2 spray.")

concommand.Add("sprayv2_openfavorites", function()
    if IsValid(spray2.FavoritePanel) then
        spray2.FavoritePanel:Remove()
    end

    spray2.FavoritePanel = vgui.Create("DSprayFavoritePanel")
    spray2.FavoritePanel:SetCurrentFolder(spray2.GetFavorites())

    spray2.FavoritePanel.OnChanged = function(self)
        spray2.WriteFavorites()
    end
end)

local function post_deletion(tab, done)
    http.Post(URLS.DELETE, {
        ["url"]   = tab.url,
        ["token"] = spray2.GetToken(),
    }, function(body, len, headers, code)
        if code ~= 200 then
            LocalPlayer():ChatPrint("Error deleting spray: Invalid response")
            return
        end

        local resp = util.JSONToTable(body)
        if not resp or not resp.status then
            LocalPlayer():ChatPrint("Error deleting spray: Invalid response")
            return
        end

        if resp.status < 0 then
            LocalPlayer():ChatPrint(string.format("Error deleting spray: %s", STATUS_NAME[resp.status]))
            return
        end

        PrintTable(resp)
        LocalPlayer():ChatPrint("Spray deleted successfully.")
        if done then done() end
    end)
end

concommand.Add("sprayv2_viewsprays", function(ply, cmd, args)
    local runViewSprays runViewSprays = function()
        local function PushForToken()
            spray2.PushForTokenWaiting("ViewSprays", runViewSprays)
            spray2.RequestToken()
        end

        if not spray2.IsTokenValid() then
            return PushForToken()
        end

        local steamid = LocalPlayer():SteamID64()
        if args and #args > 0 then
            steamid = args[1]
        end

        http.Post(URLS.GETALL, {token = spray2.GetToken(), steamid = steamid}, function(body, len, headers, code)
            if code ~= 200 then return end

            local sprayList = util.JSONToTable(body)
            if not sprayList or not sprayList.status then
                LocalPlayer():ChatPrint("Error fetching owned sprays: Invalid response")
                return
            end
            if sprayList.status == spray2.STATUS.REQUIRES_TOKEN then
                PushForToken()
                return
            end

            if sprayList.status < 0 then
                LocalPlayer():ChatPrint(string.format("Error fetching owned sprays: %s", STATUS_NAME[sprayList.status]))
                return
            end

            local fakeFavorites = {}
            for _, sprayURL in ipairs(sprayList.sprays or {}) do
                table.insert(fakeFavorites, {
                    url = sprayURL
                })
            end

            if table.Count(fakeFavorites) == 0 then
                LocalPlayer():ChatPrint(string.format("%s has no sprays uploaded.", steamid))
                return
            end

            if IsValid(spray2.SprayViewer) then
                spray2.SprayViewer:Remove()
            end

            spray2.SprayViewer = vgui.Create("DSprayFavoritePanel")
            if ply:SteamID64() == steamid or ply:IsAdmin() then
                spray2.SprayViewer:SetTitle(("Sprays cached on backend by %s (deletions are permanent)"):format(steamid))
                spray2.SprayViewer:SetReadOnly(true, true)

                function spray2.SprayViewer.DeleteSpray(self, tab)
                    post_deletion(tab, runViewSprays)
                end
            end

            spray2.SprayViewer:SetCurrentFolder(fakeFavorites)
        end)
    end

    runViewSprays()
end)


concommand.Add("sprayv2_clear_errors", function()
    spray2.CheckFailedSprays(function(failedList)
        for _, entry in ipairs(failedList) do
            local parent = entry.parent
            for i = #parent, 1, -1 do
                if parent[i] == entry.spray then
                    print("Removing failed spray:", entry.spray.url)
                    table.remove(parent, i)
                    break
                end
            end
        end
        spray2.WriteFavorites()
    end)
end, nil, "Removes any sprays that fail to load from your favorites.")

concommand.Add("sprayv2_recover_sprays", function()
    spray2.CheckFailedSprays(function(f)
        for _, spray in ipairs(f) do
            if spray.data.status == spray2.STATUS.NEEDS_CREATED then
                http.Post(spray2.URLS.SPRAYADD, {url = spray.spray.url, token = spray2.GetToken()}, function(body)
                    print(body)
                end)
            end
        end
    end)
end, nil, "Attempts to re-add sprays that are missing from the backend.")