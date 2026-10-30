local Helpers = dofile("Tests/helpers.lua")
for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " full-stack display", function()
        it("toggles current/max values without changing actual-stack ordering", function()
            local env = Helpers.loadAddon({ client = client })
            local addon = env.addon
            env.addItem(10, 10, { maxStackSize = 20 })
            env.addItem(20, 15, { maxStackSize = 5 })
            env.putItem(0, 1, 10, { stackCount = 2 })
            env.putItem(0, 2, 20, { stackCount = 2 })
            assert.is_false(env.DCI_DB.ShowFullStackValues)
            env.SlashCmdList.DCI()
            assert.equals("2", env.DCI_ItemIconCountText1.text)
            env.DCI_Config_Checkbox_ShowFullStackValues:SetChecked(true)
            env.DCI_Config_Checkbox_ShowFullStackValues:Fire("OnClick")
            assert.equals("2|cff888888/20|r", env.DCI_ItemIconCountText1.text)
            assert.is_truthy(env.DCI_ItemInfo_TextBottomRight1.text:find("/ 2s 0c", 1, true))
            assert.equals(10, addon.GetSortedBagItems()[1].itemID)
            assert.equals(20, addon.GetSortedBagItems()[1].vendorPriceTotal)
            env.DCI_Config_Checkbox_ShowFullStackValues:SetChecked(false)
            env.DCI_Config_Checkbox_ShowFullStackValues:Fire("OnClick")
            assert.equals("2", env.DCI_ItemIconCountText1.text)
            assert.equals(290, env.DCIFrame.width)
        end)
        it("shows separate full-stack vendor and auction values", function()
            local env = Helpers.loadAddon({ client = client })
            env.DCI_AuctionSource = nil
            env.DCI_DB.AuctionPriceHidePoorQuality = false
            env.Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function() return 100 end } } }
            env.addItem(10, 10, { maxStackSize = 20 })
            env.putItem(0, 1, 10, { stackCount = 2 })
            env.DCI_DB.ShowFullStackValues = true
            env.DCI_DB.ShowBothPrices = true
            env.SlashCmdList.DCI()
            assert.is_truthy(env.DCI_ItemInfo_TextTopRight1.text:find("/ 2s 0c", 1, true))
            assert.is_truthy(env.DCI_ItemInfo_TextBottomRight1.text:find("/ 19s 0c", 1, true))
        end)
        it("leaves nonstackable and unknown-capacity values alone", function()
            local env = Helpers.loadAddon({ client = client })
            env.DCI_DB.ShowFullStackValues = true
            local addon = env.addon
            assert.equals(addon.GetMoneyStringTruncated(100), addon.GetStackValueString(100, 1, 1))
            assert.equals(addon.GetMoneyStringTruncated(100), addon.GetStackValueString(100, 1, nil))
            assert.is_truthy(addon.GetStackValueString(0, 2, 20):find("/ 0c", 1, true))
        end)
    end)
end
