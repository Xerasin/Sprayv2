local spray2 = _G.spray2

function spray2.SprayReportUI(matName, callbackOK, callbackCancel)
    local w, h = 420, 188

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Are you sure you want to report this spray?")
    frame:SetSize(w, h)
    frame:Center()
    frame:MakePopup()

    local imgSize = 128
    local margin = 10
    local rightX = imgSize + margin * 2

    local img = vgui.Create("DSpray", frame)
    img:SetSpray(matName)
    img:SetPos(margin, 50)
    img:SetSize(imgSize, imgSize)
    img:SetCacheKey("ReportUI")

    local lbl2 = vgui.Create("DLabel", frame)
    lbl2:SetPos(margin, 25)
    lbl2:SetSize(400, 20)
    lbl2:SetText(matName)

    local y = h - 25 * 3 - margin

    local lbl = vgui.Create("DLabel", frame)
    lbl:SetPos(rightX, y)
    lbl:SetSize(250, 20)
    lbl:SetText("Reason")

    y = y + 25

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(rightX, y)
    entry:SetSize(w - rightX - margin, 20)
    entry:SetText("")
    entry:RequestFocus()

    y = y + 25

    local btnOK = vgui.Create("DButton", frame)
    btnOK:SetPos(rightX, y)
    btnOK:SetSize(100, 25)
    btnOK:SetText("Yes")

    btnOK.DoClick = function()
        if callbackOK then
            callbackOK(entry:GetText())
        end

        frame:Close()
    end

    local btnCancel = vgui.Create("DButton", frame)
    btnCancel:SetPos(rightX + 110, y)
    btnCancel:SetSize(100, 25)
    btnCancel:SetText("Cancel")

    btnCancel.DoClick = function()
        if callbackCancel then
            callbackCancel(entry:GetText())
        end

        frame:Close()
    end
end