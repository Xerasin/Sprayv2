local spray2 = _G.spray2
local surface = surface
pcall(require, "urlimage")

spray2.DSprayMaterials = spray2.DSprayMaterials or {}
local MAX_INFLIGHT = 10

local imgurls = spray2.DSprayMaterials
local q = {}
local queued = {}
local pending = {}
local inflight = 0

local function q_push(url)
    if queued[url] or pending[url] then return end
    queued[url] = true
    table.insert(q, url)
end

local function q_pop()
    local url = table.remove(q, 1)
    if url then queued[url] = nil end
    return url
end

timer.Create("DSprayMaterialQueue", 0.25, 0, function()
    for url, mat in pairs(pending) do
        local w, h = mat()
        if (w and h) or (w == false) then
            pending[url] = nil
            inflight = math.max(0, inflight - 1)
        end
    end

    while inflight < MAX_INFLIGHT and #q > 0 do
        local url = q_pop()
        if url and not imgurls[url] and not pending[url] then
            local mat = surface.URLImage(url)
            imgurls[url] = mat
            pending[url] = mat
            inflight = inflight + 1
        end
    end
end)

local Spray = {}
function Spray:Init()
    self:SetText("")
    self.Checkmark = Material("icon16/accept.png")
    self.IsFolder = false
    self.SprayCacheKey = "UI"
end

function Spray:SetFavoriteTab(tab)
    self.tab = tab
end

function Spray:SetSpray(str)
    self.SprayURL = str
    self.Mat = nil
    spray2.GetSprayCache(str, self.SprayCacheKey, function(data)
        if IsValid(self) then
            self.RealSprayURL = data["url"]

            local url = self.RealSprayURL
            local cached = imgurls[url]
            if cached then
                self.Mat = cached
            else
                self.Mat = function()
                    local m = imgurls[url]
                    if not m then return nil end
                    return m()
                end
                q_push(url)
            end
        end
    end)
end

function Spray:MakeFolder()
    self.IsFolder = true
end

function Spray:Paint(pw, ph)
    surface.SetDrawColor(Color(20, 20, 20))
    surface.DrawRect(0, 0, pw, ph)

    if self.Mat then
        local w, h = self.Mat()
        if w and h then
            local x,y,w2,h2
            if w > h then
                local ratio = w / h
                w2 = pw
                h2 = pw / ratio
                y = (ph - h2) / 2
                x = 0
            else
                local ratio = h / w
                h2 = ph
                w2 = ph / ratio
                x = (pw - w2) / 2
                y = 0
            end
            surface.SetDrawColor(color_white)
            surface.DrawTexturedRect(x, y, w2, h2)
        end
    end

    if self.IsFolder then
        draw.Text({
            pos    = { pw / 2 , ph - 12 },
            color  = color_white,
            text   = self.tab.name or "???",
            font   = "SprayFavoritesFolderFont",
            xalign = TEXT_ALIGN_CENTER,
            yalign = TEXT_ALIGN_CENTER,
        })
    else
        local spray = spray2.GetCurrentSpray()
        if spray and spray.url == self.SprayURL then
            surface.SetMaterial(self.Checkmark)
            surface.SetDrawColor(color_white)
            surface.DrawTexturedRect(0, ph - 16, 16, 16)
        end
    end
end

function Spray:SetCacheKey(key)
    self.SprayCacheKey = key
end

vgui.Register("DSpray", Spray, "DImage")