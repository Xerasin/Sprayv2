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
    self.NSFWButton:SetImage("icon16/error.png")

    function self.RemoveButton.DoClick()
        Derma_Query("Are you sure you want to delete this?", "Deletion", "Yes", function()
            self:GetParentSprayList():DeleteSpray(self.tab)
        end,"No",function() end)
    end

    function self.NSFWButton.DoClick()
        self.tab.nsfw = not self.tab.nsfw
        local current = spray2.GetCurrentSpray()
        if current and current.url == self.tab.url then
            spray2.SetCurrentSpray(self.tab)
        end

        http.Post(URLS.SPRAYADD, {
            ["url"]   = self.tab.url,
            ["token"] = spray2.GetToken(),
            ["nsfw"]  = self.tab.nsfw and "1" or "0"
        })
        spray2.WriteFavorites()
        self:PopulateParent()
    end

    self:Droppable("spraypanel")
    self:Receiver("spraypanel", self.HandleDrop)
end

function SprayPanel:HandleDrop(tableOfDroppedPanels, isDropped, menuIndex, mouseX, mouseY)
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

function SprayPanel:SetFavoriteTab(tab)
    self.tab = tab
    self.InnerSpray:SetFavoriteTab(tab)

    if IsValid(self.NSFWButton) then
        self.NSFWButton:SetColor(self.tab.nsfw and Color(255, 255, 255, 255) or Color(255, 255, 255, 100))
        self.NSFWButton:SetIcon(self.tab.nsfw and "icon16/exclamation.png" or "icon16/error.png")
        self.NSFWButton:SetTooltip(self.tab.nsfw and "Marked as NSFW" or "Mark as NSFW")
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
    if LocalPlayer().SetNetData then
        LocalPlayer():SetNetData("sprayv2", spray2.GetCurrentSpray())
    end
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
    while IsValid(parent) and not parent.CreateFolderWithPanels do
        parent = parent:GetParent()
    end
    return parent
end

vgui.Register("DSprayPanel", SprayPanel, "DButton")