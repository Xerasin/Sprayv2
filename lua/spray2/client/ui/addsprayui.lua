local spray2 = _G.spray2
function spray2.AddSprayUI(title, text, default, callbackOK, callbackCancel, okText, cancelText)
    okText = okText or "OK"
    cancelText = cancelText or "Cancel"
    local w, h = 420, 128 + 25 + 10

    local frame = vgui.Create("DFrame")
    frame:SetTitle(title)
    frame:SetSize(w, h)
    frame:Center()
    frame:MakePopup()

    local img = vgui.Create("DSpray", frame)
    img:SetPos(10, 25)
    img:SetSize(128, 128)

    local lbl = vgui.Create("DLabel", frame)
    lbl:SetPos(128 + 20, h - 25 - 25 - 10 - 25)
    lbl:SetSize(250, 20)
    lbl:SetText(text)

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(128 + 20, h - 25 - 25 - 10)
    entry:SetSize(w - 128 - 20 - 10, 20)
    entry:SetText(default or "")
    entry:RequestFocus()
    entry.OnEnter = function()
        img:SetSpray(entry:GetText())
    end

    local btnOK = vgui.Create("DButton", frame)
    btnOK:SetSize(100, 25)
    btnOK:SetPos(128 + 20, h - 25 - 10)
    btnOK:SetText(okText)
    btnOK.DoClick = function()
        if callbackOK then callbackOK(entry:GetText()) end
        frame:Close()
    end

    local btnCancel = vgui.Create("DButton", frame)
    btnCancel:SetSize(100, 25)
    btnCancel:SetPos(310, h - 25 - 10)
    btnCancel:SetText(cancelText)
    btnCancel.DoClick = function()
        if callbackCancel then callbackCancel(entry:GetText()) end
        frame:Close()
    end
end