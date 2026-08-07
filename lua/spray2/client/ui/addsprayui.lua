local spray2 = _G.spray2

function spray2.AddSprayUI(parent, callbackOK, callbackCancel)

    local imgSize = 128
    local margin = 10
    local rightX = imgSize + margin * 2

    local w, h = 420, imgSize + 25 + margin

    local frame = vgui.Create("DFrame", parent)
    frame:SetTitle("Add a favorite")
    frame:SetSize(w, h)
    frame:Center()
    frame:MakePopup()


    local img = vgui.Create("DSpray", frame)
    img:SetPos(margin, 25)
    img:SetSize(imgSize, imgSize)

    local y = h - 25 * 4 - margin

    local lbl = vgui.Create("DLabel", frame)
    lbl:SetPos(rightX, y)
    lbl:SetSize(250, 20)
    lbl:SetText("URL")

    y = y + 25

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(rightX, y)
    entry:SetSize(w - rightX - margin, 20)
    entry:SetText("")
    entry:RequestFocus()

    entry.OnEnter = function()
        img:SetSpray(entry:GetText())
    end

    y = y + 25

    local nsfw = vgui.Create("DCheckBoxLabel", frame)
    nsfw:SetPos(rightX, y)
    nsfw:SetText("NSFW?")
    nsfw:SetChecked(false)
    nsfw:SizeToContents()

    y = y + 25

    local btnOK = vgui.Create("DButton", frame)
    btnOK:SetPos(rightX, y)
    btnOK:SetSize(100, 25)
    btnOK:SetText("Ok")

    btnOK.DoClick = function()
        if callbackOK then
            callbackOK(entry:GetText(), nsfw:GetChecked())
        end

        frame:Close()
    end

    local btnCancel = vgui.Create("DButton", frame)
    btnCancel:SetPos(rightX + 110, y)
    btnCancel:SetSize(100, 25)
    btnCancel:SetText("Cancel")

    btnCancel.DoClick = function()
        if callbackCancel then
            callbackCancel(entry:GetText(), nsfw:GetChecked())
        end

        frame:Close()
    end
end