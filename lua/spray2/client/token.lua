local spray2 = _G.spray2
local _, _, _, NET = spray2.URLS, spray2.STATUS, spray2.STATUS_NAME, spray2.NET

function spray2.IsTokenValid()
    local favorites = spray2.GetFavorites()
    if not favorites.token or type(favorites.token) == "string" then
        return false
    end

    return favorites.token.expiry > os.time()
end

function spray2.GetToken()
    local favorites = spray2.GetFavorites()
    if not spray2.IsTokenValid() then
        spray2.RequestToken()
    end

    if favorites.token and type(favorites.token) == "table" then
        return favorites.token.token
    end
end

local requestingToken = false
function spray2.SetToken(tokenTbl)
    local favorites = spray2.GetFavorites()
    favorites.token = tokenTbl

    requestingToken = false

    spray2.WriteFavorites()
    spray2.ProcessWaitingQueue()
end


function spray2.RequestToken()
    if requestingToken then return end
    requestingToken = true
    net.Start("Sprayv2")
        net.WriteInt(NET.Token, 8)
    net.SendToServer()
end

local waitingForToken = {}
function spray2.PushForTokenWaiting(key, func, ...)
    waitingForToken[key] = {func = func, args = {...}}
end

function spray2.ProcessWaitingQueue()
    for _, tbl in pairs(waitingForToken) do
        tbl.func(unpack(tbl.args))
    end

    waitingForToken = {}
end