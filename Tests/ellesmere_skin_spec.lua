local Helpers = dofile("Tests/helpers.lua")

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " optional EllesmereUI skin", function()
        it("keeps native themes with an absent, missing or disabled API", function()
            for _, eui in ipairs({ false, {}, { RegisterSkin = function() end } }) do
                local env = Helpers.loadAddon({ client = client, ellesmereUI = eui or nil })
                env.addon.UpdateDCIFrame()
                env.DCI_DB.HideBronzeTheme = true
                env.addon.UpdateWindowTheme()
                if client.game == "camelot" then
                    assert.is_true(env.DCIFrame.RegularTheme:IsShown())
                    env.DCI_DB.HideBronzeTheme = false
                    env.addon.UpdateWindowTheme()
                    assert.is_true(env.DCIFrame.NineSlice:IsShown())
                end
                assert.is_true(env.DCIFrame:IsShown())
            end
        end)

        it("skins early and late widgets and retains controls through refresh and theme resets", function()
            for _, early in ipairs({ true, false }) do
                local apply, registered
                local skin = {}
                local looksChanged, fontRevision = nil, 1
                if early then
                    skin.OnLooksChanged = function(callback) looksChanged = callback end
                end
                for _, kind in ipairs({ "Shell", "Panel", "CloseButton", "Button", "Checkbox",
                    "EditBox", "Dropdown", "ScrollBar", "Inset", "Font" }) do
                    skin[kind] = function(frame)
                        frame.skinKind = kind
                        if kind == "Font" then frame.fontRevision = fontRevision end
                    end
                end
                -- Older public facades need not provide StateButtonLabel or tabs.
                local env = Helpers.loadAddon({ client = client, initialize = false,
                    ellesmereUI = { RegisterSkin = function(name, callback)
                        registered, apply = name, callback
                        if early then callback(skin) end
                    end } })
                assert.equals(env.addonName, registered)
                env.fire("ADDON_LOADED", env.addonName)
                env.addItem(10, 20)
                env.putItem(0, 1, 10)
                env.addItem(20, 10)
                env.putItem(0, 2, 20)
                env.addon.UpdateDCIFrame()
                if not early then
                    env.DCI_DB.HideBronzeTheme = true
                    env.addon.UpdateWindowTheme()
                    apply(skin)
                end
                assert.equals("Shell", env.DCIFrame.skinKind)
                assert.equals("CloseButton", env.DCIFrame.CloseButton.skinKind)
                assert.equals("Panel", env.DCI_ConfigPanel.skinKind)
                assert.equals("Checkbox", env.DCI_Config_Checkbox_HideSoulbound.skinKind)
                assert.equals("EditBox", env.DCI_Config_LowSlotsThreshold.skinKind)
                assert.equals("ScrollBar", env.DCI_ScrollParent.ScrollBar.skinKind)
                assert.equals("Font", env.DCI_TitleText.skinKind)
                assert.equals("Button", env.DCI_DeleteButton1.skinKind)
                assert.is_nil(env.DCI_ItemIcon1.skinKind)
                env.DCIFrame.CloseButton:Fire("OnClick")
                assert.is_false(env.DCIFrame:IsShown())
                env.SlashCmdList.DCI()
                assert.is_true(env.DCIFrame:IsShown())
                env.fire("BAG_UPDATE", 0)
                env.addon.InitializeSavedVariables(true)
                env.addon.UpdateDCISettings()
                fontRevision = 2
                if looksChanged then
                    looksChanged()
                    assert.equals(2, env.DCI_TitleText.fontRevision)
                end
                if client.game == "camelot" and env.DCIFrame.RegularTheme then
                    assert.is_false(env.DCIFrame.RegularTheme:IsShown())
                end
                env.DCI_DeleteButton1:Fire("OnClick")
                assert.same({ 20 }, env.deleted)
                assert.equals("Shell", env.DCIFrame.skinKind)
            end
        end)
    end)
end
