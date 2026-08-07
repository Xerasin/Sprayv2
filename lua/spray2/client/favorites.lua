local spray2 = _G.spray2
local _, _, _, _ = spray2.URLS, spray2.STATUS, spray2.STATUS_NAME, spray2.NET
local path = "sprayfavorites.txt"

function spray2.LoadFavorites()
    if not file.Exists(path, "DATA") then
        return {}
    end

    local raw = file.Read(path, "DATA")
    if not raw or raw == "" then
        return {}
    end

    local data = util.JSONToTable(raw)

    if not istable(data) then
        local KEY = "Spray2_FavoritesError"

        hook.Add("InitPostEntity", KEY, function()
            hook.Remove("InitPostEntity", KEY)

            local ply = LocalPlayer()
            if IsValid(ply) then
                ply:ChatPrint("Your spray favorites couldn't be loaded (file is corrupted).")
            end
        end)

        return {}
    end

    return data
end

spray2.favorites = spray2.LoadFavorites()

function spray2.GetFavorites()
    return spray2.favorites
end

function spray2.SetCurrentSpray(tab)
    spray2.favorites.selected = tab
    spray2.WriteFavorites()
    if LocalPlayer().SetNetData then
        LocalPlayer():SetNetData("sprayv2", tab)
    end
end

function spray2.GetCurrentSpray(ply)
    if IsValid(ply) and ply ~= LocalPlayer() then
        if ply.GetNetData then
            return ply:GetNetData("sprayv2")
        else
            return
        end
    end
    return spray2.favorites and spray2.favorites.selected
end

function spray2.WriteFavorites()
    file.Write("sprayfavorites.txt", util.TableToJSON(spray2.favorites))
end

function spray2.CheckFailedSprays(doneCallback)
    local leaves = {}

    local function gather(list)
        for _, spray in ipairs(list) do
            if spray.contents then
                gather(spray.contents)
            else
                table.insert(leaves, {parent = list, spray = spray})
            end
        end
    end

    gather(spray2.favorites)

    if #leaves == 0 then
        if doneCallback then doneCallback({}) end
        return
    end

    local remaining = #leaves
    local failed = {}

    for _, entry in ipairs(leaves) do
        spray2.GetSprayCache(entry.spray.url, "FavoriteCheck",
            function(data)
                remaining = remaining - 1
                if remaining == 0 and doneCallback then
                    doneCallback(failed)
                end
            end,
            function(data)
                if data and data.status < 0 then
                    table.insert(failed, {parent = entry.parent, spray = entry.spray, data = data})
                end
                remaining = remaining - 1
                if remaining == 0 and doneCallback then
                    doneCallback(failed)
                end
            end
        )
    end
end