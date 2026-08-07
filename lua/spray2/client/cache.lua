local spray2 = _G.spray2
local URLS, STATUS = spray2.URLS, spray2.STATUS

local sprayinfoqueue = spray2.sprayinfoqueue or {}
spray2.sprayinfoqueue = sprayinfoqueue

local cache = spray2.spraycache or {}
spray2.spraycache = cache

local inflight = spray2.sprayinflight or {}
spray2.sprayinflight = inflight

local function processQueue(url, data)
    if not sprayinfoqueue[url] then return end

    for _, cb in pairs(sprayinfoqueue[url]) do
        if data and data.status and data.status > 0 then
            if cb[1] then cb[1](data) end
        else
            if cb[2] then cb[2](data) end
        end
    end

    sprayinfoqueue[url] = nil
end

local function fetch(url, key)
    if inflight[url] then return end
    inflight[url] = true

    local function PushForToken()
        inflight[url] = nil
        spray2.PushForTokenWaiting("GetSprayCache:" .. url, function()
            spray2.GetSprayCache(url, key)
        end)
        spray2.RequestToken()
    end

    if not spray2.IsTokenValid() then
        PushForToken()
        return
    end

    http.Post(URLS.SPRAYINFO, {
        url = url,
        token = spray2.GetToken()
    }, function(body, _, _, code)
        inflight[url] = nil

        local resp = util.JSONToTable(body)
        if code ~= 200 or not resp then return end

        resp.status = tonumber(resp.status)
        resp.time_out = tonumber(resp.time_out)
        resp.version = tonumber(resp.version) or 0

        if resp.status == STATUS.REQUIRES_TOKEN then
            PushForToken()
            return
        end

        local old = cache[url]

        if not old or (resp.version or 0) >= (old.data.version or 0) then
            cache[url] = {
                data = resp,
                _time = os.time()
            }

            processQueue(url, resp)
        end
    end, function()
        inflight[url] = nil
    end)
end


function spray2.GetSprayCache(url, key, success, fail)
    if not url then return end

    sprayinfoqueue[url] = sprayinfoqueue[url] or {}
    sprayinfoqueue[url][key] = {success, fail}

    local cached = cache[url]

    if cached and cached.data then
        processQueue(url, cached.data)
    end

    fetch(url, key)
end


function spray2.UpdateCachedNSFW(url, newNSFW)
    if cache[url] and cache[url].data then
        cache[url].data.nsfw = newNSFW
    end
end