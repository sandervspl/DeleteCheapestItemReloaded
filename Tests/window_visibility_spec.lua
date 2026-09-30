local Helpers = dofile("Tests/helpers.lua")

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " loot window visibility", function()
        local env, addon
        before_each(function()
            env = Helpers.loadAddon({ client = client, saved = { AllowInCombat = false } })
            addon = env.addon
            env.putItem(0, 1, 10)
            env.bags[0].size = 1
            env.loot = { { name = "Loot", link = "item:10:0" } }
        end)

        it("remembers the first inventory error in combat until combat ends", function()
            env.inCombat = true
            env.LootFrame:Show()
            env.fire("LOOT_OPENED", true)
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())
            env.inCombat = false
            env.fire("PLAYER_REGEN_ENABLED")
            assert.is_true(env.DCIFrame:IsShown())
        end)

        it("waits for the loot frame when the error and event arrive before it is shown", function()
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            env.fire("LOOT_OPENED", true)
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())
            env.LootFrame:Show()
            env.runTimers()
            assert.is_true(env.DCIFrame:IsShown())
            assert.equals(env.LootFrame, env.DCIFrame.point[2])
            assert.equals(1, addon.windowContext)
        end)

        it("cancels a combat retry when loot closes, even while the addon is hidden", function()
            env.inCombat = true
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            env.fire("LOOT_OPENED", true)
            env.LootFrame:Show()
            env.fire("LOOT_CLOSED")
            env.LootFrame:Hide()
            env.runTimers()
            env.LootFrame:Show()
            env.fire("LOOT_OPENED", false)
            env.inCombat = false
            env.fire("PLAYER_REGEN_ENABLED")
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())
        end)

        it("does not close a merchant window in response to an unrelated loot close", function()
            env.MerchantFrame:Show()
            env.SlashCmdList.DCI()
            env.fire("LOOT_CLOSED")
            assert.is_true(env.DCIFrame:IsShown())
        end)

        it("does not open for ordinary loot or unrelated UI errors", function()
            env.LootFrame:Show()
            env.fire("LOOT_OPENED", true)
            env.fire("UI_ERROR_MESSAGE", 2, "You are too far away")
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())
        end)

        it("honors disabled automatic looting even with diagnostics enabled", function()
            env.DCI_DB.Auto_Loot = false
            env.SlashCmdList.DCI("debug on")
            env.LootFrame:Show()
            env.fire("LOOT_OPENED", true)
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())
        end)

        it("does not reopen a window dismissed before a deferred update", function()
            env.LootFrame:Show()
            env.fire("LOOT_OPENED", true)
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            assert.is_true(env.DCIFrame:IsShown())
            env.DCIFrame.CloseButton:Fire("OnClick")
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())
        end)

        it("keeps a new session's retry when an older deferred update was canceled", function()
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            env.fire("LOOT_OPENED", true)
            env.fire("LOOT_CLOSED")
            env.fire("LOOT_OPENED", true)
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            env.LootFrame:Show()
            env.runTimers()
            assert.is_true(env.DCIFrame:IsShown())
            env.fire("LOOT_CLOSED")
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())
        end)

        it("treats a loot frame still animating closed as a finished loot session", function()
            env.LootFrame:Show()
            env.fire("LOOT_OPENED", true)
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            env.fire("LOOT_CLOSED")
            assert.is_false(env.DCIFrame:IsShown())
            -- Forever leaves LootFrame shown while its closing animation plays.
            env.SlashCmdList.DCI()
            assert.is_true(env.DCIFrame:IsShown())
            assert.equals(0, addon.windowContext)
            env.runTimers()
            env.fire("LOOT_CLOSED")
            assert.is_true(env.DCIFrame:IsShown())
        end)

        it("keeps showing through combat changes with fresh or reset defaults", function()
            env = Helpers.loadAddon({ client = client })
            env.putItem(0, 1, 10)
            env.bags[0].size = 1
            env.loot = { { name = "Loot", link = "item:10:0" } }
            env.SlashCmdList.DCI("debug on")
            env.inCombat = true
            env.LootFrame:Show()
            env.fire("LOOT_OPENED", true)
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            env.runTimers()
            assert.is_true(env.DCIFrame:IsShown())
            for _ = 1, 2 do
                env.inCombat = false
                env.fire("PLAYER_REGEN_ENABLED")
                env.inCombat = true
                env.fire("PLAYER_REGEN_DISABLED")
                env.fire("BAG_UPDATE", 0)
                assert.is_true(env.DCIFrame:IsShown())
            end

            env.DCI_DB.AllowInCombat = false
            env.addon.RegisterFrameEvents()
            env.fire("PLAYER_REGEN_DISABLED")
            assert.is_false(env.DCIFrame:IsShown())
            env.addon.InitializeSavedVariables(true)
            env.SlashCmdList.DCI()
            assert.is_true(env.DCIFrame:IsShown())
        end)
    end)
end

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " optional inventory triggers", function()
        it("waits for combat to end while inventory stays open", function()
            local env = Helpers.loadAddon({ client = client,
                saved = { Auto_Inventory = true, Auto_Loot = false, AllowInCombat = false } })
            env.putItem(0, 1, 10)
            env.inCombat = true
            env.openBags[0] = true
            env.fire("BAG_OPEN", 0)
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())

            env.inCombat = false
            env.fire("PLAYER_REGEN_ENABLED")
            assert.is_true(env.DCIFrame:IsShown())

            env.inCombat = true
            env.fire("PLAYER_REGEN_DISABLED")
            assert.is_false(env.DCIFrame:IsShown())
            env.openBags[0] = nil
            env.fire("BAG_CLOSED", 0)
            env.runTimers()
            env.inCombat = false
            env.fire("PLAYER_REGEN_ENABLED")
            assert.is_false(env.DCIFrame:IsShown())
        end)

        it("follows multiple open bags and keeps the window through a loot session", function()
            local env = Helpers.loadAddon({ client = client, saved = { Auto_Loot = false } })
            env.putItem(0, 1, 10)
            assert.is_false(env.DCI_DB.Auto_Inventory)
            assert.is_false(env.DCI_DB.Auto_LowSlots)
            assert.equals(0, env.DCI_DB.LowSlotsThreshold)

            local checkbox = env.DCI_Config_Checkbox_Auto_Inventory
            checkbox:SetChecked(true)
            checkbox:Fire("OnClick")
            env.openBags[0] = true
            env.fire("BAG_OPEN", 0)
            env.runTimers()
            assert.is_true(env.DCIFrame:IsShown())

            env.DCIFrame.CloseButton:Fire("OnClick")
            env.openBags[1] = true
            env.fire("BAG_OPEN", 1)
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())
            env.openBags[0], env.openBags[1] = nil, nil
            env.fire("BAG_CLOSED", 0)
            env.fire("BAG_CLOSED", 1)
            env.runTimers()
            env.openBags[0] = true
            env.fire("BAG_OPEN", 0)
            env.runTimers()
            assert.is_true(env.DCIFrame:IsShown())

            env.openBags[1] = true
            env.fire("BAG_OPEN", 1)
            env.openBags[0] = nil
            env.fire("BAG_CLOSED", 0)
            env.runTimers()
            assert.is_true(env.DCIFrame:IsShown())

            env.DCI_DB.Auto_LowSlots = true
            env.addon.RegisterFrameEvents()
            env.loot = { { name = "Loot", link = "item:10:0" } }
            env.LootFrame:Show()
            env.fire("LOOT_OPENED", true)
            env.runTimers()
            assert.equals(1, env.addon.windowContext)
            env.fire("LOOT_CLOSED")
            assert.is_true(env.DCIFrame:IsShown())
            assert.equals(0, env.addon.windowContext)

            env.openBags[1] = nil
            env.fire("BAG_CLOSED", 1)
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())

            env.SlashCmdList.DCI()
            env.openBags[0] = true
            env.fire("BAG_OPEN", 0)
            env.openBags[0] = nil
            env.fire("BAG_CLOSED", 0)
            env.runTimers()
            assert.is_true(env.DCIFrame:IsShown())
        end)

        it("opens at the configured free-slot threshold during looting and respects dismissal", function()
            local env = Helpers.loadAddon({ client = client, saved = { Auto_Loot = false } })
            env.bags[0] = { size = 5, slots = {} }
            env.putItem(0, 1, 10)
            env.loot = { { name = "Loot", link = "item:10:0" } }
            local checkbox = env.DCI_Config_Checkbox_Auto_LowSlots
            checkbox:SetChecked(true)
            checkbox:Fire("OnClick")
            local threshold = env.DCI_Config_LowSlotsThreshold
            threshold:SetText("3")
            threshold:Fire("OnTextChanged", true)
            assert.equals(3, env.DCI_DB.LowSlotsThreshold)
            env.addon.UpdateDCISettings()
            assert.equals("3", threshold:GetText())
            threshold:Fire("OnEditFocusLost")
            assert.equals(3, env.DCI_DB.LowSlotsThreshold)
            assert.equals("3", threshold:GetText())

            env.LootFrame:Show()
            env.fire("LOOT_OPENED", true)
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())

            env.putItem(0, 2, 11)
            env.fire("BAG_UPDATE", 0)
            env.runTimers()
            assert.is_true(env.DCIFrame:IsShown())
            assert.equals(1, env.addon.windowContext)

            env.DCIFrame.CloseButton:Fire("OnClick")
            env.putItem(0, 3, 12)
            env.fire("BAG_UPDATE", 0)
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())

            env.fire("LOOT_CLOSED")
            env.LootFrame:Hide()
            env.fire("LOOT_OPENED", true)
            env.LootFrame:Show()
            env.runTimers()
            assert.is_true(env.DCIFrame:IsShown())
            env.fire("LOOT_CLOSED")
            assert.is_false(env.DCIFrame:IsShown())
        end)
    end)
end

describe("Forever inventory frame callbacks", function()
    it("follows the combined bag frame even without bag events or callbacks", function()
        local env = Helpers.loadAddon({ client = Helpers.clients[4],
            saved = { Auto_Inventory = true, Auto_Loot = false } })
        env.putItem(0, 1, 10)
        env.runTimers()
        env.ContainerFrameCombinedBags:Show()
        env.DCIInventoryWatcher:Fire("OnUpdate", 0.21)
        env.runTimers()
        assert.is_true(env.DCIFrame:IsShown())

        env.DCIFrame.CloseButton:Fire("OnClick")
        env.DCIInventoryWatcher:Fire("OnUpdate", 0.21)
        env.runTimers()
        assert.is_false(env.DCIFrame:IsShown())

        env.ContainerFrameCombinedBags:Hide()
        env.DCIInventoryWatcher:Fire("OnUpdate", 0.21)
        env.runTimers()
        env.ContainerFrameCombinedBags:Show()
        env.DCIInventoryWatcher:Fire("OnUpdate", 0.21)
        env.runTimers()
        assert.is_true(env.DCIFrame:IsShown())
        env.ContainerFrameCombinedBags:Hide()
        env.DCIInventoryWatcher:Fire("OnUpdate", 0.21)
        env.runTimers()
        assert.is_false(env.DCIFrame:IsShown())
    end)

    it("opens and closes with the visible bag UI without bag data events", function()
        local env = Helpers.loadAddon({ client = Helpers.clients[4],
            saved = { Auto_Inventory = true, Auto_Loot = false } })
        env.putItem(0, 1, 10)
        env.openBags[0] = true
        env.callbacks["ContainerFrame.OpenBag"]()
        env.runTimers()
        assert.is_true(env.DCIFrame:IsShown())

        env.openBags[0] = nil
        env.callbacks["ContainerFrame.CloseBag"]()
        env.runTimers()
        assert.is_false(env.DCIFrame:IsShown())

        env.openBags[0] = true
        local checkbox = env.DCI_Config_Checkbox_Auto_Inventory
        checkbox:SetChecked(false)
        checkbox:Fire("OnClick")
        checkbox:SetChecked(true)
        checkbox:Fire("OnClick")
        env.runTimers()
        assert.is_true(env.DCIFrame:IsShown())
    end)
end)

describe("chat window diagnostics", function()
    it("toggles tracing without toggling the window and reports why it hides", function()
        local env = Helpers.loadAddon({ client = Helpers.clients[4] })
        env.putItem(0, 1, 10)
        env.SlashCmdList.DCI("debug on")
        assert.is_false(env.DCIFrame:IsShown())
        env.LootFrame:Show()
        env.fire("LOOT_OPENED", true)
        env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
        env.time = 0.42
        env.fire("LOOT_CLOSED")
        local log = table.concat(env.messages, "\n")
        assert.is_truthy(log:find("UI_ERROR_MESSAGE", 1, true))
        assert.is_truthy(log:find("ERR_INV_FULL", 1, true))
        assert.is_truthy(log:find("hidden: LOOT_CLOSED", 1, true))
        assert.is_truthy(log:find("0.42", 1, true))
        env.SlashCmdList.DCI("status")
        assert.is_false(env.DCIFrame:IsShown())
        assert.is_truthy(env.messages[#env.messages]:find("interface=16001", 1, true))
        env.SlashCmdList.DCI("debug off")
        local count = #env.messages
        env.fire("LOOT_OPENED", true)
        env.fire("UI_ERROR_MESSAGE", 2, "Unrelated error")
        env.runTimers()
        assert.equals(count, #env.messages)
    end)

    it("reports parent visibility and manual dismissal without changing the window", function()
        local env = Helpers.loadAddon()
        env.SlashCmdList.DCI()
        env.SlashCmdList.DCI("status")
        assert.is_true(env.DCIFrame:IsShown())
        env.UIParent:Hide()
        env.SlashCmdList.DCI("status")
        assert.is_truthy(env.messages[#env.messages]:find("shown=yes visible=no", 1, true))
        env.UIParent:Show()
        env.DCIFrame.CloseButton:Fire("OnClick")
        env.SlashCmdList.DCI("status")
        assert.is_truthy(env.messages[#env.messages]:find("hidden: close button or external hide", 1, true))
        assert.is_false(env.DCIFrame:IsShown())
    end)

    it("keeps normal looting quiet until diagnostics are enabled", function()
        local env = Helpers.loadAddon()
        env.putItem(0, 1, 10)
        local count = #env.messages
        env.LootFrame:Show()
        env.fire("LOOT_OPENED", true)
        env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
        env.fire("LOOT_CLOSED")
        env.runTimers()
        assert.equals(count, #env.messages)
    end)
end)
