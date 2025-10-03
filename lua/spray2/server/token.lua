local spray2 = _G.spray2
local URLS, _, _, NET = spray2.URLS, spray2.STATUS, spray2.STATUS_NAME, spray2.NET

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

local function SaveToken(newToken)
    createTable()
    sql.Query(string.format([[
        INSERT INTO spraytoken (id, token)
        VALUES (1, '%s')
        ON CONFLICT(id) DO UPDATE SET token=excluded.token;
    ]], sql.SQLStr(newToken, true)))
    server_token = newToken
end

local function LoadToken()
    createTable()
    local sql_token = sql.QueryValue([[SELECT token FROM spraytoken WHERE id = 1 LIMIT 1;]])
    local err = sql.LastError()
    if not err and sql_token then
        server_token = sql_token
    end
end

local function SendToken(ply, valid, token_data)
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
local requestCache = setmetatable({}, { __mode = "k" })
function spray2.OnReceiveTokenRequest(ply)
    if not IsValid(ply) then return end
    local steamid = ply:SteamID64()
    local cached = tokenCache[steamid]

    if cached and cached.expiry > os.time() then
        SendToken(ply, cached.success, cached)
        return
    end

    if not server_token then
        LoadToken()
    end

    if requestCache[ply] then
        return
    end
    requestCache[ply] = true
    http.Post(URLS.SPRAYLOGIN, {["server_token"] = server_token, ["steamid"] = steamid}, function(data, _, _, code)
        requestCache[ply] = nil
        if code == 200 then
            local token_data = util.JSONToTable(data)
            if not token_data or not token_data["token"] then
                print("Invalid token response:", data)
                return
            end
            if IsValid(ply) then
                cached = {
                    success = true,
                    token = token_data["token"],
                    expiry = tonumber(token_data["expiry_unix"]) or (os.time() + 60 * 5)
                }
                tokenCache[steamid] = cached
                SendToken(ply, true, cached)
            end
        else
            local error_data = util.JSONToTable(data) or {["error"] = data}

            cached = {
                success = false,
                error = error_data["error"],
                expiry = tonumber(error_data["expiry_unix"]) or (os.time() + 60 * 5),
            }

            tokenCache[steamid] = cached
            if IsValid(ply) then
                SendToken(ply, false, cached)
            end

            if error_data["error"] == "Valid token already exists." or code == 403 then
                return
            end

            print(string.format(
                "Sprayv2 token generation failed for %s (HTTP %d): %s",
                steamid, code, error_data["error"] or tostring(data)
            ))
        end
    end)
end


hook.Add("Initialize", "sprayv2", function()
    LoadToken()
end)


concommand.Add("sprayv2_token", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then return end
    if #args ~= 1 then return end
    server_token = args[1]
    SaveToken(server_token)
    ply:ChatPrint(string.format("Set sprayv2 server token to %s.", server_token))
end)