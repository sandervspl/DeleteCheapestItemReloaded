local Helpers = dofile("Tests/helpers.lua")

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " quest acceptance with full bags", function()
        local env
        before_each(function()
            env = Helpers.loadAddon({ client = client })
            env.putItem(0, 1, 10)
            env.bags[0].size = 1
            env.GetQuestID = function() return 123 end
            -- Quest offers can come from items or NPCs that are not targeted.
            env.UnitGUID = function() return nil end
            env.QuestFrame:Show()
            env.QuestFrameDetailPanel:Show()
            env.fire("QUEST_DETAIL")
        end)

        it("opens on failed acceptance, refreshes after freeing space, and closes with the quest", function()
            assert.is_false(env.DCIFrame:IsShown())
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            assert.is_true(env.DCIFrame:IsShown())
            assert.equals(env.QuestFrame, env.DCIFrame.point[2])
            assert.equals(2, env.addon.windowContext)

            env.bags[0].slots[1] = nil
            env.fire("BAG_UPDATE", 0)
            assert.is_true(env.DCIFrame:IsShown())
            assert.equals(1, env.addon.CountFreeBagSlots())
            env.QuestFrame:Hide()
            assert.is_false(env.DCIFrame:IsShown())
        end)

        it("switches an already open window to the failed quest acceptance", function()
            env.SlashCmdList.DCI()
            assert.equals(0, env.addon.windowContext)
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            assert.equals(2, env.addon.windowContext)
            assert.equals(env.QuestFrame, env.DCIFrame.point[2])
            env.QuestFrame:Hide()
            assert.is_false(env.DCIFrame:IsShown())
        end)

        for _, event in ipairs({ "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE" }) do
            it("opens for a localized quest bag-full message through " .. event, function()
                env.GetGameMessageInfo = function(messageType)
                    if messageType == 171 then return "ERR_QUEST_FAILED_BAG_FULL_S" end
                end
                env.fire(event, 171, "Een moeilijke opdracht mislukt: inventaris is vol.")
                assert.is_true(env.DCIFrame:IsShown())
                assert.equals(2, env.addon.windowContext)
                assert.equals(env.QuestFrame, env.DCIFrame.point[2])
            end)
        end

        it("ignores unrelated errors and disabled automatic quest acceptance", function()
            env.fire("UI_ERROR_MESSAGE", 2, "You are too far away")
            assert.is_false(env.DCIFrame:IsShown())
            env.DCI_DB.Auto_QuestAccept = false
            env.DCI_DB.Auto_Loot = false
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            env.runTimers()
            assert.is_false(env.DCIFrame:IsShown())
        end)

        it("does not treat a hidden quest frame's detail panel as an active quest", function()
            env.QuestFrame:Hide()
            env.DCI_DB.Auto_Loot = false
            env.fire("UI_ERROR_MESSAGE", 1, env.ERR_INV_FULL)
            assert.is_false(env.DCIFrame:IsShown())
            assert.is_false(env.addon.QuestGaveError)
        end)
    end)
end
