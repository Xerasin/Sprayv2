local spray2 = _G.spray2
local URLS = spray2.URLS

local SprayPanel = {}
function SprayPanel:Init()
    self:SetText("")

    self.InnerSpray = vgui.Create("DSpray", self)
    self.InnerSpray:Dock(FILL)
    self.InnerSpray:SetMouseInputEnabled(false)
    self.InnerSpray:SetKeyboardInputEnabled(false)

    self.RemoveButton = vgui.Create("DImageButton", self)
    self.RemoveButton:SetSize(16, 16)
    self.RemoveButton:SetImage("icon16/cross.png")

    self.NSFWButton = vgui.Create("DImageButton", self)
    self.NSFWButton:SetSize(16, 16)
    self.NSFWButton:SetImage("icon16/information.png")
    self.NSFWButton:SetEnabled(false)

    function self.RemoveButton.DoClick()
        local parent = self:GetParentSprayList()

        local str = "Are you sure you want to delete this spray?"
        if parent:IsFavorites() then
            str = "Are you sure you want to delete this spray?\n\nThis will only delete it locally. It will still exist on the backend and may continue to appear in roulettes. Use `sprayv2_viewsprays` in console to delete it permanently."
        end
        Derma_Query(
            str,
            "Deletion",
            "Yes",function()
                if not IsValid(parent) then return end

                parent:DeleteSpray(self.tab)
            end,
            "No", function() end)
    end

    function self.NSFWButton.DoClick()
        if self.Locked then return end
        self.Locked = true

        local newState = not self.tab.nsfw

        http.Post(URLS.SPRAYNSFW, {
            url = self.tab.url,
            token = spray2.GetToken(),
            nsfw = newState and "1" or "0"
        }, function(data, _, _, code)
            if not IsValid(self) then return end

            if code == 200 then
                local json = util.JSONToTable(data)
                if not json or json.status ~= spray2.STATUS.SUCCESS then
                    self.Locked = false
                    return
                end

                spray2.UpdateCachedNSFW(self.tab.url, json.nsfw)
                self.tab.nsfw = json.nsfw
                self:UpdateNSFW()
            end

            self.Locked = false
        end)

        self:UpdateNSFW()
    end

    self:Droppable("spraypanel")
    self:Receiver("spraypanel", self.HandleDrop)

    self.readOnly = false
    self.dontHideDelete = false
end

function SprayPanel:SetReadOnly(readOnly, dontHideDelete)
    self.readOnly = readOnly
    self.dontHideDelete = dontHideDelete

    if IsValid(self.RemoveButton) then
        self.RemoveButton:SetVisible((not readOnly) or dontHideDelete)
    end

    if IsValid(self.RenameButton) then
        self.RenameButton:SetVisible(not readOnly)
    end

    if IsValid(self.ChangeImageButton) then
        self.ChangeImageButton:SetVisible(not readOnly)
    end
end

function SprayPanel:HandleDrop(tableOfDroppedPanels, isDropped, menuIndex, mouseX, mouseY)
    if self.readOnly then return end
    if not isDropped then return end
    if type(tableOfDroppedPanels) ~= "table" then return end

    local filtered = {}
    for _, pnl in ipairs(tableOfDroppedPanels) do
        if IsValid(pnl) and not pnl.IsBack then
            table.insert(filtered, pnl)
        end
    end

    if #filtered == 0 then return end

    local parent = self:GetParentSprayList()
    if not IsValid(parent) then return end

    if self.InnerSpray.IsFolder then
        local drop = self.tab
        if self.InnerSpray.PreviousButton then
            drop = parent:GetLastFolder()
            if not drop then return end
        end
        parent:MoveSpraysToFolder(drop, filtered)
    elseif not self.IsBack then
        Derma_StringRequest(
            "Create Folder",
            "Name the new folder",
            "",
            function(str)
                parent:CreateFolderWithPanels(str, filtered, self)
            end,
            function() end,
            "Create",
            "Cancel"
        )
    end
end

function SprayPanel:PopulateParent()
    local parent = self:GetParentSprayList()
    if IsValid(parent) then
        parent:Populate()
    end
end

function SprayPanel:UpdateNSFW()
    if not IsValid(self.NSFWButton) then return end
    self.NSFWButton:SetImage(self.tab.nsfw and "icon16/error.png" or "icon16/information.png")
    self.NSFWButton:SetEnabled(self.tab.steamid == LocalPlayer():SteamID64())
    self.NSFWButton:SetTooltip(self.tab.nsfw and "NSFW" or "SFW")
end

function SprayPanel:SetFavoriteTab(tab)
    self.tab = tab
    self.InnerSpray:SetFavoriteTab(tab)

    if IsValid(self.NSFWButton) then
        self.NSFWButton:SetEnabled(false)

        spray2.GetSprayCache(self.tab.url, self.InnerSpray.SprayCacheKey .. "2", function(data)
            if not IsValid(self) or not data then return end

            self.tab.steamid = data.steamid

            if data.nsfw ~= nil then
                self.tab.nsfw = tobool(data.nsfw)
            end

            self:UpdateNSFW()
        end)
        self:UpdateNSFW()
    end
end

function SprayPanel:MakeFolder(previous)
    self.IsBack = false
    self.InnerSpray.IsFolder = true
    self.InnerSpray.PreviousButton = previous

    if IsValid(self.NSFWButton) then
        self.NSFWButton:Remove()
    end

    if previous then
        self.RemoveButton:Remove()
        self.IsBack = true
    else
        self.RenameButton = vgui.Create("DImageButton", self)
        self.RenameButton:SetSize(16, 16)
        self.RenameButton:SetImage("icon16/pencil.png")
        function self.RenameButton.DoClick()
            Derma_StringRequest("Rename Folder", "Enter a new name", self.tab.name, function(str)
                self.tab.name = str
                spray2.WriteFavorites()
                self:PopulateParent()
            end, function() end, "Rename", "Cancel")
        end

        self.ChangeImageButton = vgui.Create("DImageButton", self)
        self.ChangeImageButton:SetSize(16, 16)
        self.ChangeImageButton:SetImage("icon16/image_edit.png")
        function self.ChangeImageButton.DoClick()
            Derma_StringRequest("Change Folder Image", "Enter a new image", self.tab.url, function(str)
                self.tab.url = str
                spray2.WriteFavorites()
                self:PopulateParent()
            end, function()
                self.tab.url = "https://raw.githubusercontent.com/Xerasin/Sprayv2/master/files/folder_forward.png"
                spray2.WriteFavorites()
                self:PopulateParent()
            end, "Change", "Default")
        end
    end
end

function SprayPanel:SetSpray(str)
    self.SprayURL = str
    self.InnerSpray:SetSpray(str)
end

function SprayPanel:PerformLayout()
    local w, h = self:GetSize()
    self.InnerSpray:SetSize(w, h)
    self.InnerSpray:SetPos(0, 0)

    if IsValid(self.RemoveButton) then
        self.RemoveButton:SetPos(w - 16, 0)
    end

    if IsValid(self.RenameButton) then
        self.RenameButton:SetPos(w - 16, h - 16)
    end

    if IsValid(self.ChangeImageButton) then
        self.ChangeImageButton:SetPos(0, 0)
    end

    if IsValid(self.NSFWButton) then
        self.NSFWButton:SetPos(0, 0)
    end
end

function SprayPanel:DoClick()
    if self.InnerSpray.IsFolder then
        local parent = self:GetParentSprayList()
        if self.InnerSpray.PreviousButton then
            parent:PopFolder()
        else
            parent:PushFolder(self.tab.contents)
        end
        parent:Populate()
        return
    end

    if CurTime() - (self.lastSelect or 0) <= 0.2 then return end
    self.lastSelect = CurTime()

    local currentSpray = spray2.GetCurrentSpray()
    if currentSpray and currentSpray.url == self.SprayURL then
        spray2.SetCurrentSpray(nil)
    else
        spray2.SetCurrentSpray(self.tab)
        http.Post(URLS.SPRAYADD, {
            ["url"]   = self.tab.url,
            ["token"] = spray2.GetToken(),
            ["nsfw"]  = self.tab.nsfw and "1" or "0"
        })
    end

    spray2.WriteFavorites()
end

function SprayPanel:DoRightClick()
    if not self.InnerSpray.IsFolder then
        local dMenu = DermaMenu(self)
        dMenu:AddOption("Copy URL", function()
            if self.SprayURL then
                SetClipboardText(self.SprayURL)
            end
        end)
        dMenu:Open()
    end
end

function SprayPanel:GetParentSprayList()
    local parent = self:GetParent()

    while IsValid(parent) do
        if parent.CreateFolderWithPanels then
            return parent
        end

        parent = parent:GetParent()
    end
end

vgui.Register("DSprayPanel", SprayPanel, "DButton")