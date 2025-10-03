local spray2 = _G.spray2
local surface = surface
local URLS, STATUS, STATUS_NAME, _ = spray2.URLS, spray2.STATUS, spray2.STATUS_NAME, spray2.NET

local DFavoritePanel = {}

function DFavoritePanel:Init()
    self:SetCookieName("Sprayv2Favorites")
    self:SetSize(self:GetCookieNumber("w", 420), self:GetCookieNumber("h", 525))
    self:SetPos(self:GetCookieNumber("x", 5), self:GetCookieNumber("y", 5))
    self:SetTitle("Spray Favorites")
    self:SetSizable(true)
    self:SetDraggable(true)

    self.Scroll = vgui.Create( "DScrollPanel", self)
    function self.Scroll:Paint(pw, ph)
        surface.SetTexture(0)
        surface.SetDrawColor(Color(50, 50, 50))
        surface.DrawRect(0, 0, pw, ph)
    end

    self.List = vgui.Create( "DIconLayout", self.Scroll)

    self.SprayRoulette = vgui.Create("DImageButton", self)
    self.SprayRoulette:SetSize(16, 16)
    self.SprayRoulette:SetImage("icon16/cog.png")
    self.SprayRoulette:SetTooltip("Random Spray! (use with caution)")
    function self.SprayRoulette:DoClick()
        RunConsoleCommand("sprayv2_random", "0")
    end

    self.ClearSpray = vgui.Create("DImageButton", self)
    self.ClearSpray:SetSize(16, 16)
    self.ClearSpray:SetImage("icon16/bomb.png")
    self.ClearSpray:SetTooltip("Clear Spray Selection")
    function self.ClearSpray:DoClick()
        RunConsoleCommand("sprayv2_clear")
    end

    self.SaveSpray = vgui.Create("DImageButton", self)
    self.SaveSpray:SetSize(16, 16)
    self.SaveSpray:SetImage("icon16/picture_save.png")
    self.SaveSpray:SetTooltip("Save current spray")
    function self.SaveSpray.DoClick(_self)
        self:AddSpray(spray2.GetCurrentSpray())
    end

    self.AddFavorite = vgui.Create("DButton", self)
    self.AddFavorite:SetSize(10, 20)
    self.AddFavorite:Dock(BOTTOM)
    self.AddFavorite:SetText("Add Favorite")
    function self.AddFavorite.DoClick(_self)
        spray2.AddSprayUI("Add a favorite", "URL", "", function(text)
            self:AddSpray{url = text, nsfw = false}
        end)
    end

    self.Scale = vgui.Create("DNumSlider", self)
    self.Scale:SetText("")
    self.Scale:SetSize(200, 16)
    self.Scale:SetMin(0.25)
    self.Scale:SetMax(2)
    self.Scale:SetValue(self:GetCookieNumber("scale", 1))
    function self.Scale.OnValueChanged()
        self:Populate()
    end

    self:Populate()
    self:MakePopup()

    self.previousFolderStack = {}
    self.currentFolder = nil
end

function DFavoritePanel:OnClose()
    local w, h = self:GetSize()
    local x, y = self:GetPos()
    self:SetCookie("w", w)
    self:SetCookie("h", h)
    self:SetCookie("x", x)
    self:SetCookie("y", y)
    self:SetCookie("scale", self.Scale:GetValue())

    DFrame.OnClose(self)
end

function DFavoritePanel:PerformLayout()
    local w, _ = self:GetSize()

    self.Scroll:Dock(FILL)
    self.List:Dock(FILL)
    self.List:SetSpaceY( 5 )
    self.List:SetSpaceX( 5 )


    self.SaveSpray:SetPos(w - 120, 5)
    self.ClearSpray:SetPos(w - 144, 5)
    self.SprayRoulette:SetPos(w - 168, 5)
    self.Scale:SetPos(w - 168 - 200, 5)

    DFrame.PerformLayout(self)
end

function DFavoritePanel:Populate()
    if not self.currentFolder then return end

    self.List:Clear()

    local sizeMul = self.Scale:GetValue()
    local function AddButton(v, folder, tab)
        local SprayPan = vgui.Create("DSprayPanel", self.List)
        SprayPan:SetSize(128 / sizeMul, 128 / sizeMul)
        SprayPan:SetSpray(v.url or "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/folder_forward.png")
        SprayPan:SetFavoriteTab(v)
        if folder then
            SprayPan:MakeFolder(tab)
        end
        self.List:Add(SprayPan)
    end

    local files, folders = {}, {}
    for k,v in pairs(self.currentFolder) do
        if not tonumber(k) then continue end
        if v.isFolder or (v.name and v.name ~= "") then
            table.insert(folders, v)
        elseif v.url and v.url ~= "" then
            if v.superfav ~= nil then v.superfav = nil end
            table.insert(files, v)
        end
    end

    table.sort(files, function(a, b) return a.url < b.url end)
    table.sort(folders, function(a, b) return a.name < b.name end)

    if #self.previousFolderStack > 0 then
        local backTabDisplay = {
            url = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/folder_back.png",
            IsBack = true,
            name = "Back"
        }
        local prevFolder = self.previousFolderStack[#self.previousFolderStack]

        local SprayPan = vgui.Create("DSprayPanel", self.List)
        SprayPan:SetSize(128 / sizeMul, 128 / sizeMul)
        SprayPan:SetSpray(backTabDisplay.url)
        SprayPan:SetFavoriteTab(backTabDisplay)
        SprayPan:MakeFolder(prevFolder)
        SprayPan.IsBack = true

        function SprayPan:DoClick()
            local parent = self:GetParentSprayList()
            parent:PopFolder()
        end

        local targetFolder = prevFolder
        function SprayPan:OnDrop(dropped)
            local parent = self:GetParentSprayList()

            local droppedPanels = {}
            if istable(dropped) then
                droppedPanels = dropped
            else
                table.insert(droppedPanels, dropped)
            end

            parent:MoveSpraysToFolder(targetFolder, droppedPanels)
        end

        self.List:Add(SprayPan)
    end

    for k,v in pairs(folders) do
        AddButton(v, true)
    end

    for k,v in pairs(files) do
        AddButton(v)
    end

    self.List:Layout()
    self.Scroll:PerformLayout()
end

function DFavoritePanel:PopFolder()
    if not self.currentFolder then return end

    self.currentFolder = table.remove(
        self.previousFolderStack,
        #self.previousFolderStack
    )
    self:Populate()
end

function DFavoritePanel:PushFolder(folder)
    if not self.currentFolder then return end
    table.insert(self.previousFolderStack, self.currentFolder)
    self.currentFolder = folder
    self:Populate()
end

function DFavoritePanel:SetCurrentFolder(folder)
    self.currentFolder = folder
    self:Populate()
end

function DFavoritePanel:GetLastFolder()
    return self.previousFolderStack[#self.previousFolderStack]
end


function DFavoritePanel:AddSpray(tbl)
    if not tbl or tbl.url == "" then return end

    for k, v in pairs(self.currentFolder) do
        if tonumber(k) and v.url == tbl.url then
            return
        end
    end

    if not spray2.IsTokenValid() then
        return spray2.RequestToken()
    end

    http.Post(URLS.SPRAYADD, {["url"] = tbl.url, ["token"] = spray2.GetToken()}, function(data, _, _, code)
        local sprayData = util.JSONToTable(data)
        if code ~= 200 or not sprayData then return end

        local status = tonumber(sprayData.status)
        sprayData.status = status

        if status >= 0 then
            table.insert(self.currentFolder, tbl)
            spray2.WriteFavorites()
            self:Populate()

        elseif status == STATUS.REQUIRES_TOKEN then
            spray2.PushForTokenWaiting("lastAddRequestToken", self.AddSpray, self, tbl)
            spray2.RequestToken()
        else
            LocalPlayer():ChatPrint(string.format(
                "Cannot process %s (%s): %s",
                tbl.url,
                STATUS_NAME[status] or status,
                sprayData.status_text or "Unknown error"
            ))
        end
    end)
end


local function IsDescendant(folder, candidate)
    if folder == candidate then return true end
    if not folder.contents then return false end
    for _, child in ipairs(folder.contents) do
        if child == candidate then
            return true
        elseif child.isFolder and IsDescendant(child, candidate) then
            return true
        end
    end
    return false
end

function DFavoritePanel:CreateFolderWithPanels(folderName, tableOfDroppedPanels, otherPanel)
    local newFolder = {
        isFolder = true,
        name = folderName,
        url = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/folder_forward.png",
        contents = {}
    }

    local toRemove = {}

    local function AddPanel(v)
        if not v or not v.tab then return end

        local tab = v.tab

        if tab.IsBack then return end
        if tab.isFolder and IsDescendant(tab, newFolder) then
            LocalPlayer():ChatPrint("Cannot put a folder inside itself or its children.")
            return
        end

        table.insert(newFolder.contents, tab)

        for k2, v2 in ipairs(self.currentFolder) do
            if v2 == tab then
                table.insert(toRemove, k2)
                break
            end
        end
    end

    for _, v in ipairs(tableOfDroppedPanels) do
        if v ~= otherPanel then
            AddPanel(v)
        end
    end
    AddPanel(otherPanel)

    table.sort(toRemove, function(a, b) return a > b end)
    for _, idx in ipairs(toRemove) do
        table.remove(self.currentFolder, idx)
    end

    table.insert(self.currentFolder, newFolder)

    spray2.WriteFavorites()
    self:Populate()
end

function DFavoritePanel:MoveSpraysToFolder(droppedOnFolder, droppedPanels)
    if not droppedOnFolder then return end

    local target = droppedOnFolder.contents or droppedOnFolder
    if not istable(target) then return end

    local toRemove = {}

    for _, panel in ipairs(droppedPanels) do
        if panel ~= self and panel.tab then
            local tab = panel.tab

            if tab.IsBack then continue end
            if tab.isFolder and IsDescendant(tab, droppedOnFolder) then
                LocalPlayer():ChatPrint("Cannot move a folder into itself or its children.")
                continue
            end

            table.insert(target, tab)

            for k, v in ipairs(self.currentFolder) do
                if v == tab then
                    table.insert(toRemove, k)
                    break
                end
            end
        end
    end

    table.sort(toRemove, function(a, b) return a > b end)
    for _, idx in ipairs(toRemove) do
        table.remove(self.currentFolder, idx)
    end

    spray2.WriteFavorites()
    self:Populate()
end

function DFavoritePanel:DeleteSpray(tab)
    if not tab or not self.currentFolder then return end
    if tab.IsBack then return end

    if tab.isFolder and tab == self.currentFolder then
        LocalPlayer():ChatPrint("Cannot delete the current folder.")
        return
    end

    local sprayIndex = nil
    for k, v in ipairs(self.currentFolder) do
        if v == tab then
            sprayIndex = k
            break
        end
    end

    if not sprayIndex then
        self:Populate()
        return
    end

    table.remove(self.currentFolder, sprayIndex)
    spray2.WriteFavorites()
    self:Populate()
end

vgui.Register("DSprayFavoritePanel", DFavoritePanel, "DFrame")