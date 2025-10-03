local spray2 = _G.spray2

local URLS = {
    SPRAYINFO = "https://sprays.xerasin.com/v1/get",
    SPRAYADD = "https://sprays.xerasin.com/v1/add",
    SPRAYLOGIN = "https://sprays.xerasin.com/v1/login",
    RANDOMSPRAY = "https://sprays.xerasin.com/v1/random",
    REPORTSPRAY = "https://sprays.xerasin.com/v1/report",
}
spray2.URLS = URLS

local STATUS = {
    DELETED = -7,
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