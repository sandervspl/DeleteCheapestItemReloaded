local Helpers = dofile("Tests/helpers.lua")

describe("supported client manifests", function()
    it("matches the verified client matrix and loads only shipped runtime files", function()
        local toc = Helpers.readFile("DeleteCheapestItem.toc")
        local actual, expected = {}, {}
        for value in toc:match("## Interface: ([^\r\n]+)"):gmatch("%d+") do actual[#actual + 1] = tonumber(value) end
        for _, client in ipairs(Helpers.clients) do expected[#expected + 1] = client.interface end
        assert.same(expected, actual)
        assert.is_truthy(toc:find("## Title: DeleteCheapestItem Reloaded", 1, true))
        assert.is_truthy(toc:find("## Author: Sander Vispoel (sandervspl)", 1, true))
        assert.is_truthy(toc:find("<Night Shift> Suey", 1, true))
        assert.is_truthy(toc:find("## SavedVariablesPerCharacter: DCI_DB", 1, true))
        assert.is_truthy(toc:find("Localization.lua\nDeleteCheapestItem.lua", 1, true))
    end)
end)

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " (" .. client.interface .. ", " .. client.game .. ")", function()
        local env, addon
        before_each(function()
            env = Helpers.loadAddon({ client = client })
            addon = env.addon
        end)

        it("initializes settings and opens /dci without deprecated item globals", function()
            assert.is_nil(env.GetItemInfo)
            assert.is_nil(env.GetItemIcon)
            assert.is_nil(env.GetItemQualityColor)
            assert.is_nil(env.SettingsPanel)
            env.addItem(10, 50)
            env.putItem(0, 1, 10)
            env.SlashCmdList.DCI()
            assert.is_true(env.DCIFrame:IsShown())
            assert.equals("DeleteCheapestItem Reloaded", env.DCI_TitleText.text)
            assert.equals("DeleteCheapestItem Reloaded", env.registeredCategory.name)
            assert.equals("Delete", env.DCI_DeleteButton1.text)
            env.DCI_TitleInfoButton:Fire("OnMouseUp")
            assert.equals(42, env.openedCategory)
            env.SlashCmdList.DCI()
            assert.is_false(env.DCIFrame:IsShown())
        end)

        it("sorts by stack value, deduplicates stacks, and honors item filters", function()
            env.addItem(10, 10)
            env.addItem(20, 15)
            env.addItem(30, 1, { quality = 4 })
            env.putItem(0, 1, 10, { stackCount = 2 })
            env.putItem(0, 2, 10, { stackCount = 2 })
            env.putItem(0, 3, 20)
            env.putItem(0, 4, 30)
            env.putItem(0, 5, 40, { quest = { isQuestItem = true } })
            env.putItem(0, 6, 50, { isBound = true })
            env.putItem(0, 7, 6948)
            env.putItem(1, 1, 60, { isLocked = true })
            env.putItem(1, 2, 70)
            env.putItem(1, 3, 80, { quest = { questID = 123 } })
            env.DCI_DB.IgnoredItems = { 70 }
            local items = addon.GetSortedBagItems()
            assert.equals(2, #items)
            assert.equals(20, items[1].itemID)
            assert.equals(10, items[2].itemID)
            assert.equals(20, items[2].vendorPriceTotal)
        end)

        it("waits for missing item data, then refreshes the open window", function()
            env.addItem(10, 100, { pending = true })
            env.putItem(0, 1, 10)
            assert.same({}, addon.GetSortedBagItems())
            env.SlashCmdList.DCI()
            env.items[10].pending = false
            env.fire("GET_ITEM_INFO_RECEIVED", 10, true)
            assert.equals(100, addon.GetSortedBagItems()[1].vendorPricePer)
            assert.is_true(env.DCI_Item1:IsShown())
            env.SlashCmdList.DCI()
            env.fire("GET_ITEM_INFO_RECEIVED", 10, true)
            assert.is_false(env.DCIFrame:IsShown())
        end)

        it("uses bound status fallback when the container result omits it", function()
            local item = env.putItem(0, 1, 10, { boundFallback = true })
            item.isBound = nil
            assert.same({}, addon.GetSortedBagItems())
        end)

        it("counts general bag capacity without specialty or bank slots", function()
            env.bags[0] = { size = 16, slots = {} }
            env.bags[1] = { size = 20, slots = {}, family = 32 }
            env.bags[-1] = { size = 24, slots = {} }
            env.bags[6] = { size = 24, slots = {} }
            env.putItem(0, 1, 10)
            assert.equals(15, addon.CountFreeBagSlots())
            if client.scrollBoxLoot then
                env.bags[5] = { size = 10, slots = {}, family = 2048 }
                env.putItem(5, 1, 20)
                assert.equals(15, addon.CountFreeBagSlots())
                assert.equals(2, #addon.GetSortedBagItems())
            end
        end)

        it("remembers the actual clicked loot slot with this client's UI", function()
            env.loot = { { name = "Loot", link = "item:10:0" } }
            env.fire("LOOT_OPENED")
            if client.scrollBoxLoot then
                assert.is_nil(env.LootButton1)
                env.LootFrame.selectedSlot = 7
                env.callbacks["LootFrame.ItemLooted"]()
            else
                env.LootButton1.slot = 7 -- A paged row's slot is not its button number.
                env.LootButton1:Fire("OnClick")
            end
            assert.equals(7, env.LootFrame.DCI_LootIndexUserClick)
        end)

        it("opens on full inventory errors and respects combat visibility", function()
            env.putItem(0, 1, 10)
            env.LootFrame:Show()
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            assert.is_true(env.DCIFrame:IsShown())
            env.inCombat = true
            env.fire("PLAYER_REGEN_DISABLED")
            assert.is_false(env.DCIFrame:IsShown())
            env.inCombat = false
            env.fire("PLAYER_REGEN_ENABLED")
            assert.is_true(env.DCIFrame:IsShown())
            env.fire("LOOT_CLOSED")
            assert.is_false(env.DCIFrame:IsShown())
        end)

        it("renders uncached loot and quest rewards without nil name errors", function()
            env.putItem(0, 1, 10)
            env.addItem(20, 200, { pending = true })
            env.loot = { { name = "Loot % (special)", link = "item:20:0" } }
            env.LootFrame:Show()
            addon.UpdateDCIFrame()
            env.LootFrame:Hide()
            env.choices = { { itemID = 20 } }
            env.QuestFrame:Show()
            env.QuestFrameRewardPanel:Show()
            addon.UpdateDCIFrame()
            assert.equals(env.RETRIEVING_ITEM_INFO, addon.GetQuestRewardWindowItems()[1].name)
            env.QuestInfoFrame.itemChoice = 5 -- An obsolete selection must not index a missing item.
            env.rewards = { { itemID = 10, name = "Item 10", link = env.items[10].link } }
            addon.UpdateDCIFrame()
        end)
    end)
end

describe("identity and saved settings", function()
    it("uses the loader's addon name and packaged version", function()
        local env = Helpers.loadAddon({ addonName = "RenamedAddon", version = "v7.1.0",
            saved = { MaxQuality = 0, UseAuctionPrices = false, IgnoredItems = { 22 } } })
        assert.equals("v7.1.0", env.addon.ADDON_VERSION)
        assert.equals(0, env.DCI_DB.MaxQuality)
        assert.is_false(env.DCI_DB.UseAuctionPrices)
        assert.same({ 22 }, env.DCI_DB.IgnoredItems)
        assert.is_nil(env.DCIFrame.events.ADDON_LOADED)
    end)

    it("ignores other addons' ADDON_LOADED events", function()
        local env = Helpers.loadAddon({ initialize = false })
        env.fire("ADDON_LOADED", "OtherAddon")
        assert.is_nil(env.category)
    end)

    it("keeps the new title across translated locales", function()
        for _, locale in ipairs({ "deDE", "frFR", "esES", "esMX", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }) do
            local env = Helpers.loadAddon({ locale = locale })
            assert.equals("DeleteCheapestItem Reloaded", env.registeredCategory.name)
        end
    end)
end)
