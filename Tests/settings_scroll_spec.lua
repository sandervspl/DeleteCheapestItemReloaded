local Helpers = dofile("Tests/helpers.lua")

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " scrollable settings", function()
        it("keeps all settings inside the viewport content and supports resizing and resetting", function()
            local env = Helpers.loadAddon({ client = client })
            local scroll = env.DCI_ConfigScrollFrame
            local content = env.DCI_ConfigPanel
            assert.equals(env.DCI_ConfigCanvas, env.category.frame)
            assert.equals(env.DCI_ConfigCanvas, scroll.parent)
            assert.equals(content, scroll.scrollChild)
            assert.equals(scroll, content.parent)
            assert.equals(660, content.height)
            assert.equals(27, scroll.ScrollBar.scrollStep)
            assert.equals(content, env.DCI_Config_AuctionFrame.parent)

            scroll:Fire("OnSizeChanged", 700, 400)
            assert.equals(700, content:GetWidth())
            scroll:Fire("OnSizeChanged", 640, 500)
            assert.equals(640, content:GetWidth())

            env.DCI_DB.HideSoulbound = true
            env.DCI_DB.LowSlotsThreshold = 7
            env.addon.UpdateDCISettings()
            assert.is_true(env.DCI_Config_Checkbox_HideSoulbound:GetChecked())
            assert.equals("7", env.DCI_Config_LowSlotsThreshold:GetText())
            env.addon.InitializeSavedVariables(true)
            env.addon.UpdateDCISettings()
            assert.equals(env.DCI_DB.HideSoulbound, env.DCI_Config_Checkbox_HideSoulbound:GetChecked())
        end)
    end)
end
