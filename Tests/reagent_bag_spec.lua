local Helpers = dofile("Tests/helpers.lua")
for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " reagent bag marker", function()
        it("marks only items stored in the reagent bag", function()
            local env = Helpers.loadAddon({ client = client })
            env.addItem(10, 1)
            env.addItem(20, 2)
            env.putItem(0, 1, 10)
            env.putItem(5, 1, 20)
            env.SlashCmdList.DCI()
            local icon1, icon2 = env.DCI_ItemReagentBagIcon1, env.DCI_ItemReagentBagIcon2
            assert.equals("Professions_Tracking_Herb", icon1.atlas)
            assert.is_false(icon1:IsShown())
            if client.scrollBoxLoot then
                assert.is_true(icon2:IsShown())
            else
                -- Clients without a reagent bag never scan bag 5.
                assert.is_false(icon2:IsShown())
            end
        end)
    end)
end
