local spray2 = _G.spray2
local URLS = spray2.URLS

local sprayinfoqueue = spray2.sprayinfoqueue or {}
spray2.sprayinfoqueue = sprayinfoqueue

local sprayinfo = spray2.sprayinfo or {}
spray2.sprayinfo = sprayinfo

local shouldUseAdd = {
    UI = true,
    Preview = true,
}

if not sql.TableExists("spray_cache") then
    sql.Query([[
        CREATE TABLE spray_cache (
            url TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            last_update INTEGER NOT NULL
        )
    ]])
end

local CACHE_TTL = 60 * 60 * 24 * 2 -- 2 days
sql.Query("DELETE FROM spray_cache WHERE last_update < " .. sql.SQLStr(os.time() - CACHE_TTL))

local function loadFromSQLite(url)
    local row = sql.QueryRow("SELECT data, last_update FROM spray_cache WHERE url = " .. sql.SQLStr(url))
    if not row then return nil end

    local decoded = util.JSONToTable(row.data or "")
    local ts = tonumber(row.last_update) or 0
    if not decoded then return nil end

    if (os.time() - ts) > CACHE_TTL then
        return nil
    end

    return decoded
end

local function saveToSQLite(url, data)
    sql.Query("REPLACE INTO spray_cache (url, data, last_update) VALUES (" ..
        sql.SQLStr(url) .. "," ..
        sql.SQLStr(util.TableToJSON(data)) .. "," ..
        sql.SQLStr(os.time()) .. ")")
end

function spray2.GetSprayCache(url, key, success, fail)
    if not url then return end

    sprayinfoqueue[url] = sprayinfoqueue[url] or {}
    sprayinfoqueue[url][key] = {success, fail}

    local cached = sprayinfo[url] or loadFromSQLite(url)
    if cached then
        sprayinfo[url] = cached
    end

    local timerName = "spraydata_" .. util.CRC(url)
    if timer.Exists(timerName) then return end

    local function processQueue(data)
        if not sprayinfoqueue[url] then return end
        for _, cb in pairs(sprayinfoqueue[url]) do
            if data.status > 0 and cb[1] then
                cb[1](data)
            elseif data.status < 0 and cb[2] then
                cb[2](data)
            end
        end
        sprayinfoqueue[url] = nil
    end

    local running = false
    local function fetch()
        if running then return end
        running = true

        if not spray2.IsTokenValid() then
            spray2.RequestToken()
        end

        local useAdd   = shouldUseAdd[key] == true
        local endpoint = useAdd and URLS.SPRAYADD or URLS.SPRAYINFO

        http.Post(endpoint, {url = url, token = spray2.GetToken()}, function(data, _, headers, code)
            running = false
            local resp = util.JSONToTable(data)

            if code == 429 then
                local retryDelay = tonumber(headers and headers["retry-after"]) or 2
                retryDelay = math.max(retryDelay, 1)
                timer.Create(timerName, retryDelay, 1, fetch)
                return
            end

            if code ~= 200 or not resp then
                timer.Remove(timerName)
                local failData = {status = -3, status_text = ("Backend error %s"):format(code)}
                sprayinfo[url] = failData
                saveToSQLite(url, failData)
                processQueue(failData)
                return
            end

            resp.status   = tonumber(resp.status)
            resp.time_out = tonumber(resp.time_out)
            sprayinfo[url] = resp
            saveToSQLite(url, resp)

            if resp.status == 0 and (resp.time_out or 0) < os.time() then
                timer.Create(timerName, 0.1, 30, fetch)
                return
            end

            timer.Remove(timerName)

            if (resp.time_out or 0) > os.time() then
                print(("Sprayv2: %q is rate limited, retrying at %s."):format(
                    url, os.date("%x %X", resp.time_out)
                ))
                return
            end

            processQueue(resp)
        end, function(err)
            running = false
            timer.Remove(timerName)
            local failData = {status = -3, status_text = ("Backend error %s"):format(err)}
            sprayinfo[url] = failData
            saveToSQLite(url, failData)
            processQueue(failData)
        end)
    end

    fetch()

    if cached then
        processQueue(cached)
    end
end