local Helpers = dofile("Tests/helpers.lua")

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " threshold persistence", function()
        for _, event in ipairs({ "OnEnterPressed", "OnEscapePressed", "OnHide", "OnEditFocusLost" }) do
            it("retains the displayed threshold after " .. event .. " and reload", function()
                local env = Helpers.loadAddon({ client = client,
                    saved = { Auto_Loot = false, Auto_LowSlots = true, LowSlotsThreshold = 2 } })
                local threshold = env.DCI_Config_LowSlotsThreshold
                -- End editing before a pending OnTextChanged callback is delivered.
                threshold:SetText("17")
                threshold:Fire(event)
                assert.equals(17, env.DCI_DB.LowSlotsThreshold)
                threshold:Fire("OnTextChanged", false)
                assert.equals(17, env.DCI_DB.LowSlotsThreshold)
                assert.equals("17", threshold:GetText())

                local reloaded = Helpers.loadAddon({ client = client, saved = env.DCI_DB })
                assert.equals("17", reloaded.DCI_Config_LowSlotsThreshold:GetText())
                reloaded.bags[0] = { size = 18, slots = {} }
                reloaded.putItem(0, 1, 10)
                reloaded.loot = { { name = "Loot", link = "item:10:0" } }
                reloaded.fire("LOOT_OPENED", true)
                reloaded.runTimers()
                assert.is_true(reloaded.DCIFrame:IsShown())
            end)
        end

        it("keeps the last amount for an empty edit, saves zero, and resets without reviving stale text", function()
            local env = Helpers.loadAddon({ client = client, saved = { LowSlotsThreshold = 17 } })
            local threshold = env.DCI_Config_LowSlotsThreshold
            threshold:SetText("")
            threshold:Fire("OnHide")
            assert.equals(17, env.DCI_DB.LowSlotsThreshold)
            assert.equals("17", threshold:GetText())
            threshold:SetText("0")
            threshold:Fire("OnEscapePressed")
            local reloaded = Helpers.loadAddon({ client = client, saved = env.DCI_DB })
            assert.equals(0, reloaded.DCI_DB.LowSlotsThreshold)
            assert.equals("0", reloaded.DCI_Config_LowSlotsThreshold:GetText())

            threshold:SetText("34")
            threshold:Fire("OnEnterPressed")
            env.addon.InitializeSavedVariables(true)
            env.addon.UpdateDCISettings()
            threshold:Fire("OnHide")
            assert.equals(0, env.DCI_DB.LowSlotsThreshold)
            assert.equals("0", threshold:GetText())
        end)
    end)
end
