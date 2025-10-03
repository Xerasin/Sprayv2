AddCSLuaFile()

_G.spray2 = _G.spray2 or {}

local function IncludeDir(dir, realm)
    local files, dirs = file.Find(dir .. "/*.lua", "LUA")

    for _, f in ipairs(files) do
        local path = dir .. "/" .. f

        if realm == "shared" then
            if SERVER then AddCSLuaFile(path) include(path) else include(path) end
        elseif realm == "server" then
            if SERVER then include(path) end
        elseif realm == "client" then
            if SERVER then AddCSLuaFile(path) else include(path) end
        end
    end

    for _, d in ipairs(dirs) do
        IncludeDir(dir .. "/" .. d, realm)
    end
end

IncludeDir("spray2", "shared")

IncludeDir("spray2/server", "server")

IncludeDir("spray2/client", "client")
IncludeDir("spray2/client/ui", "client")