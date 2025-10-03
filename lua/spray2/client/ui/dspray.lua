local spray2 = _G.spray2
local surface = surface
pcall(require, "urlimage")

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

local imgurls = {}
function Spray:SetSpray(str)
    self.SprayURL = str
    spray2.GetSprayCache(str, self.SprayCacheKey, function(data)
        if IsValid(self) then
            imgurls[data["url"]] = imgurls[data["url"]] or surface.URLImage(data["url"])
            self.Mat = imgurls[data["url"]]
        end
    end)
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