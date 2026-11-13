local Helpers = dofile("Tests/helpers.lua")

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " ignored item management", function()
        it("manages a long saved list with duplicates and delayed item data through the UI", function()
            local saved = { IgnoredItems = { 10, 10, 20 } }
            for id = 30, 60 do table.insert(saved.IgnoredItems, id) end
            local env = Helpers.loadAddon({ client = client, saved = saved })
            local addon = env.addon
            env.addItem(10, 1)
            env.addItem(20, 2, { pending = true })
            env.putItem(0, 1, 10)
            env.putItem(0, 2, 20)
            assert.equals(0, #addon.GetSortedBagItems())

            env.DCI_Config_Button_IgnoredIte:Fire("OnClick")
            local frame = addon.IgnoredItemsFrame
            assert.is_true(frame:IsShown())
            assert.equals(33, #frame.rows)
            assert.equals(env.items[10].name, frame.rows[1].label:GetText())
            assert.equals("Item ID: 20", frame.rows[2].label:GetText())
            assert.equals("Item ID: 60", frame.rows[33].label:GetText())
            frame.scroll:SetVerticalScroll(800)
            frame.rows[33].remove:Fire("OnClick")
            assert.is_false(addon.IsItemIgnored(60))
            assert.is_false(frame.rows[33]:IsShown())

            env.items[20].pending = false
            env.fire("GET_ITEM_INFO_RECEIVED", 20, true)
            assert.equals(env.items[20].name, frame.rows[2].label:GetText())
            frame.rows[1].remove:Fire("OnClick")
            assert.is_false(addon.IsItemIgnored(10))
            assert.equals(10, addon.GetSortedBagItems()[1].itemID)
            assert.equals(20, frame.rows[1].itemID)
            frame.rows[1].remove:Fire("OnClick")
            assert.is_false(addon.IsItemIgnored(20))
            assert.equals(2, #addon.GetSortedBagItems())
            addon.SaveIgnoredItem(20)
            addon.SaveIgnoredItem(20)
            assert.equals(31, #saved.IgnoredItems)

            frame.CloseButton:Fire("OnClick")
            assert.is_false(frame:IsShown())
            env.SlashCmdList.DCI(" ignored ")
            assert.equals(frame, addon.IgnoredItemsFrame)
            assert.is_true(frame:IsShown())
            assert.equals(0, frame.scroll.scroll)
            for _, button in ipairs(frame.children) do
                if button:GetText() == "Reset Ignored Items" then button:Fire("OnClick") end
            end
            assert.same({}, saved.IgnoredItems)
            assert.equals("No ignored items.", frame.empty:GetText())
            assert.is_false(frame.rows[1]:IsShown())
            assert.equals(2, #addon.GetSortedBagItems())
        end)

        it("opens an empty character list and removes unavailable items without needing item data", function()
            local env = Helpers.loadAddon({ client = client })
            env.SlashCmdList.DCI("ignored")
            local frame = env.addon.IgnoredItemsFrame
            assert.equals("No ignored items.", frame.empty:GetText())
            env.addon.SaveIgnoredItem(999)
            assert.equals("Item ID: 999", frame.rows[1].label:GetText())
            frame.rows[1].remove:Fire("OnClick")
            assert.same({}, env.DCI_DB.IgnoredItems)
            assert.equals("No ignored items.", frame.empty:GetText())
        end)
    end)
end
