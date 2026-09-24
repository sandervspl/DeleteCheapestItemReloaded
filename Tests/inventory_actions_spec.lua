local Helpers = dofile("Tests/helpers.lua")

describe("inventory actions", function()
    local env, addon, stack
    before_each(function()
        env = Helpers.loadAddon()
        addon = env.addon
        env.addItem(10, 10, { quality = 2 })
        stack = env.putItem(0, 1, 10)
    end)

    it("deletes the selected stack from a click and invokes the continuation", function()
        local calls = 0
        assert.is_true(addon.ConfirmAndDeleteBagItem(0, 1, stack, function() calls = calls + 1 end))
        assert.same({ 10 }, env.deleted)
        assert.equals(1, calls)
    end)

    it("defers deletion and looting until the confirmation is accepted", function()
        env.DCI_DB.ConfirmMinQuality = 2
        local calls = 0
        assert.is_false(addon.ConfirmAndDeleteBagItem(0, 1, stack, function() calls = calls + 1 end))
        assert.same({}, env.deleted)
        assert.equals(0, calls)
        assert.equals("DCI_RELOADED_DELETE_ITEM", env.popup.key)
        assert.is_nil(env.StaticPopupDialogs.DELETE_ITEM_CONFIRMATION)
        env.acceptPopup()
        assert.same({ 10 }, env.deleted)
        assert.equals(1, calls)
    end)

    for _, change in ipairs({ "replacement", "quantity", "link", "empty", "locked", "ignored", "quest", "bound", "cursor" }) do
        it("rejects confirmation after the stack becomes " .. change, function()
            env.DCI_DB.ConfirmMinQuality = 2
            addon.ConfirmAndDeleteBagItem(0, 1, stack)
            if change == "replacement" then env.putItem(0, 1, 20)
            elseif change == "quantity" then stack.stackCount = 2
            elseif change == "link" then stack.hyperlink = "item:10:99"
            elseif change == "empty" then env.bags[0].slots[1] = nil
            elseif change == "locked" then stack.isLocked = true
            elseif change == "ignored" then env.DCI_DB.IgnoredItems = { 10 }
            elseif change == "quest" then stack.quest = { questID = 5 }
            elseif change == "bound" then stack.isBound = true
            elseif change == "cursor" then env.cursor = { "item", 999 } end
            env.acceptPopup()
            assert.same({}, env.deleted)
        end)
    end

    it("rejects a stale displayed row before opening confirmation", function()
        local expected = addon.GetSortedBagItems()[1]
        env.putItem(0, 1, 20)
        assert.is_false(addon.ConfirmAndDeleteBagItem(0, 1, expected))
        assert.same({}, env.deleted)
    end)

    for _, failure in ipairs({ "pickupFails", "deleteFails", "wrongCursorID" }) do
        it("does not report success when " .. failure, function()
            env[failure] = failure == "wrongCursorID" and 999 or true
            local called = false
            assert.is_false(addon.ConfirmAndDeleteBagItem(0, 1, stack, function() called = true end))
            assert.same({}, env.deleted)
            assert.is_false(called)
            assert.equals(stack, env.bags[0].slots[1])
        end)
    end

    it("leaves an occupied cursor untouched", function()
        env.cursor = { "item", 999 }
        addon.ConfirmAndDeleteBagItem(0, 1, stack)
        assert.same({ "item", 999 }, env.cursor)
        assert.same({}, env.deleted)
    end)

    it("sells only while the merchant is still open and the stack still matches", function()
        assert.is_false(addon.SellBagItem(0, 1, stack))
        env.MerchantFrame:Show()
        assert.is_true(addon.SellBagItem(0, 1, stack))
        env.putItem(0, 1, 20)
        assert.is_false(addon.SellBagItem(0, 1, stack))
        assert.same({ { 0, 1 } }, env.sold)
    end)

    it("uses the selected loot slot, then visits the remaining loot in value order", function()
        env.addItem(20, 200)
        env.addItem(30, 300)
        env.loot = {
            { name = "quest", quest = true },
            { name = "Item 20", link = env.items[20].link },
            { name = "Item 30", link = env.items[30].link },
        }
        addon.TakeItemsFromLootWindow(2)
        assert.same({ 1, 2, 3 }, env.looted)
    end)

    it("continues looting from the real button only after confirming deletion", function()
        env.DCI_DB.ConfirmMinQuality = 2
        env.loot = { { name = "Quest", quest = true }, { name = "Item 10", link = env.items[10].link } }
        env.LootFrame:Show()
        env.LootFrame.DCI_LootIndexUserClick = 2
        addon.UpdateDCIFrame()
        env.DCI_DeleteButton1:Fire("OnClick")
        assert.same({}, env.looted)
        env.acceptPopup()
        assert.same({ 1, 2 }, env.looted)
    end)
end)

describe("auction comparisons", function()
    it("falls back to vendor values until item data is available", function()
        local env = Helpers.loadAddon()
        env.DCI_AuctionSource = nil
        env.Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function() return 100 end } } }
        env.addItem(10, 50, { pending = true })
        assert.is_nil(env.addon.ItemInfo[10].bestPricePer)
        env.items[10].pending = false
        env.fire("GET_ITEM_INFO_RECEIVED", 10, true)
        env.DCI_DB.AuctionPriceHidePoorQuality = false
        assert.equals(95, env.addon.ItemInfo[10].bestPricePer)
    end)

    it("sorts by vendor, auction or best stack value and applies the auction cut", function()
        local env = Helpers.loadAddon()
        env.DCI_AuctionSource = nil
        env.Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(name, id)
            assert.equals(env.addonName, name)
            return id == 10 and 100 or 10
        end } } }
        env.DCI_DB.AuctionPriceHidePoorQuality = false
        env.addItem(10, 5)
        env.addItem(20, 50)
        env.putItem(0, 1, 10)
        env.putItem(0, 2, 20)
        env.DCI_DB.CompareByPrice = env.addon.PRICE_TYPE_VENDOR
        assert.equals(10, env.addon.GetSortedBagItems()[1].itemID)
        env.DCI_DB.CompareByPrice = env.addon.PRICE_TYPE_AUCTION
        assert.equals(20, env.addon.GetSortedBagItems()[1].itemID)
        env.DCI_DB.CompareByPrice = env.addon.PRICE_TYPE_BEST
        assert.equals(20, env.addon.GetSortedBagItems()[1].itemID)
        assert.equals(95, env.addon.GetSortedBagItems()[2].bestPricePer)
    end)
end)
