AddCSLuaFile()

_G.spray2 = _G.spray2 or {}

local function IncludeDir(dir, realm, loadfirst)
    local files, dirs = file.Find(dir .. "/*.lua", "LUA")

    local firstSet = {}
    if loadfirst then
        for _, f in ipairs(loadfirst) do
            firstSet[f] = true
        end
    end

    local function doInclude(path)
        if realm == "shared" then
            if SERVER then AddCSLuaFile(path) end
            include(path)
        elseif realm == "server" then
            if SERVER then include(path) end
        elseif realm == "client" then
            if SERVER then AddCSLuaFile(path) else include(path) end
        end
    end

    if loadfirst then
        for _, f in ipairs(loadfirst) do
            local path = dir .. "/" .. f
            if file.Exists(path, "LUA") then
                doInclude(path)
            end
        end
    end

    for _, f in ipairs(files) do
        local path = dir .. "/" .. f
        if not firstSet[f] then
            doInclude(path)
        end
    end

    for _, d in ipairs(dirs) do
        IncludeDir(dir .. "/" .. d, realm)
    end
end


IncludeDir("spray2", "shared")
IncludeDir("spray2/server", "server")
IncludeDir("spray2/client", "client", {"spray2/client/favorites.lua"})
IncludeDir("spray2/client/ui", "client")