local tbMod = GameMain:NewMod("XiuXianAssistant")

function tbMod:RegisterBridgeHotkey()
    if self._bridgeRegistered then
        return
    end

    local Bridge = GameMain:GetMod("Jai_HotkeyAdapter")
    if Bridge ~= nil then
        Bridge:register("XiuXian Assistant", "Open Window",
            function()
                self:ToggleMainWindow()
            end
        )
        self._bridgeRegistered = true
        print("[XiuXian Assistant] Jai_HotkeyAdapter registered")
    end
end

function tbMod:OnInit()
    print("[XiuXian Assistant] Initialization complete")
    XIAUXIAN_ITEMS.OnInit()
    self.isOpen = false
    self._bridgeRegistered = false
    self:RegisterBridgeHotkey()
end

function tbMod:OnSetHotKey()
    print("[XiuXian Assistant] Hotkey setup")
    self:RegisterBridgeHotkey()
    return {
        { ID = "OpenAssistant", Name = "Open XiuXian Assistant Window", Type = "Mod", InitialKey1 = "F8" }
    }
end

function tbMod:OnHotKey(ID, state)
    self:RegisterBridgeHotkey()
    if ID == "OpenAssistant" and state == "down" then
        self:ToggleMainWindow()
    end
end

function tbMod:ToggleMainWindow()
    local Windows = GameMain:GetMod("Windows")
    local home = Windows:CreateWindow("XiuXianHome")
    print(home.window.isShowing)
    if home.window.isShowing then
        home:Hide()
    else
        home:Show()
    end

end


function tbMod:OnSave()
    print("[XiuXian Assistant] Saving...")
    return {
        isOpen = self.isOpen,
        exampleValue = 42
    }
end

