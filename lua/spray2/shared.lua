local spray2 = _G.spray2

local DOMAIN = "https://sprays.xerasin.com"
if not DOMAIN or DOMAIN == "" then
    error("spray2: DOMAIN not set! Please set spray2.DOMAIN to the correct domain in lua/spray2/shared.lua")
end
spray2.DOMAIN = DOMAIN

local URLS = {
    SPRAYINFO   = DOMAIN .. "/v1/get",
    SPRAYADD    = DOMAIN .. "/v1/add",
    SPRAYNSFW   = DOMAIN .. "/v1/nsfw",
    SPRAYLOGIN  = DOMAIN .. "/v1/login",
    RANDOMSPRAY = DOMAIN .. "/v2/random",
    REPORTSPRAY = DOMAIN .. "/v1/report",
    GETALL      = DOMAIN .. "/v1/getall",
    DELETE      = DOMAIN .. "/v1/delete",
}
spray2.URLS = URLS

local STATUS = {
    USER_DELETED = -8, -- Deleted by a user
    DELETED = -7, -- Deleted by admin
    NEEDS_CREATED  = -6,
    REQUIRES_TOKEN = -5,
    BLACKLIST = -4,
    ERR_OTHER = -3,
    CANNOT_PROCESS = -2,
    FAILED = -1,
    PROCESSING = 0,
    SUCCESS = 1,
}
spray2.STATUS = STATUS

local STATUS_NAME = {}
for k, v in pairs(STATUS) do
    STATUS_NAME[v] = k
end
spray2.STATUS_NAME = STATUS_NAME

local NET = {
    Spray = 0,
    ClearSpray = 1,
    Token = 2,
}
spray2.NET = NET