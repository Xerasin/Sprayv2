local spray2 = _G.spray2
local URLS, _, _, _ = spray2.URLS, spray2.STATUS, spray2.STATUS_NAME, spray2.NET

concommand.Add("sprayv2_random", function(ply, cmd, args)
    if not spray2.IsTokenValid() then
        return spray2.RequestToken()
    end

    http.Post(URLS.RANDOMSPRAY, {["token"] = spray2.GetToken()}, function(data, _, _, code)
        if code ~= 200 then return end

        spray2.SetCurrentSpray({url = data, nsfw = true})

        spray2.WriteFavorites()
        if LocalPlayer().SetNetData then LocalPlayer():SetNetData("sprayv2", spray2.GetCurrentSpray()) end

        if (not args or #args == 0) or tobool(args[1]) then
           spray2.SendSpray()
        end
    end)
end)


concommand.Add("sprayv2_clear", function(ply, cmd, args)
    spray2.SetCurrentSpray(nil)

    spray2.WriteFavorites()
    if LocalPlayer().SetNetData then LocalPlayer():SetNetData("sprayv2", spray2.GetCurrentSpray()) end
end)

concommand.Add("sprayv2_openfavorites", function()
    if IsValid(spray2.FavoritePanel) then
        spray2.FavoritePanel:Remove()
    end

    spray2.FavoritePanel = vgui.Create("DSprayFavoritePanel")
    spray2.FavoritePanel:SetCurrentFolder(spray2.GetFavorites())
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
end)