local Helpers = dofile("Tests/helpers.lua")
local SHARD = 6265

local function setup(client, saved)
    local env = Helpers.loadAddon({ client = client })
    env.addItem(SHARD, 0, { name = "Soul Shard", quality = 1, maxStackSize = 1 })
    env.addItem(10, 5)
    for key, value in pairs(saved or {}) do env.addon.db[key] = value end
    env.addon.RegisterFrameEvents()
    return env
end

local function putShards(env, bag, count, family)
    env.bags[bag] = env.bags[bag] or { size = 16, slots = {}, family = family }
    for slot = 1, count do env.putItem(bag, slot, SHARD) end
end

local function countShards(env)
    local count = 0
    for _, bag in pairs(env.bags) do
        for _, item in pairs(bag.slots) do
            if item.itemID == SHARD then count = count + 1 end
        end
    end
    return count
end

local function listedIDs(env)
    local ids = {}
    for _, item in ipairs(env.addon.GetSortedBagItems()) do ids[#ids + 1] = item.itemID end
    return ids
end

local function bagUpdate(env, bag)
    env.fire("BAG_UPDATE", bag or 0)
    env.runTimers()
end

for _, client in ipairs(Helpers.clients) do
    local supported = client.game ~= "mists"

    describe(client.name .. " soul bags", function()
        it("never lists items stored in a soul bag", function()
            local env = setup(client)
            env.putItem(0, 1, 10)
            env.bags[1] = { size = 16, slots = {}, family = 4 }
            env.putItem(1, 1, SHARD)
            assert.same({ 10 }, listedIDs(env))
        end)
    end)

    if not supported then
        describe(client.name .. " Soul Shard limit", function()
            it("hides the section and ignores saved limit settings where shards are a resource", function()
                local env = setup(client, { SoulShardLimitEnabled = true, SoulShardLimit = 0, SoulShardAutoDelete = true })
                assert.is_nil(env.DCI_Config_SoulShardLimit)
                assert.equals(1054, env.DCI_ConfigPanel.height)
                assert.equals(-734, env.DCI_ProfileControls.point[3])
                putShards(env, 0, 3)
                bagUpdate(env)
                assert.equals(3, countShards(env))
                assert.equals(0, env.addon.CountExtraSoulShards())
                assert.is_false(env.DCIFrame.events.ITEM_LOCK_CHANGED or false)
            end)
        end)
    else
        describe(client.name .. " Soul Shard limit", function()
            it("defaults to off with a limit of 10 and chat announcements on", function()
                local env = setup(client)
                assert.is_false(env.addon.db.SoulShardLimitEnabled)
                assert.equals(10, env.addon.db.SoulShardLimit)
                assert.is_false(env.addon.db.SoulShardAutoDelete)
                assert.is_true(env.addon.db.SoulShardAnnounce)
            end)

            it("adds a section below auction prices and moves profiles and the content bounds down", function()
                local env = setup(client)
                local section = env.DCI_Config_Checkbox_SoulShardLimitEnabled.parent
                assert.equals(-714, section.point[5])
                assert.equals(5 * 27 + 16, section.height)
                assert.equals(-905, env.DCI_ProfileControls.point[3])
                assert.equals(1054 + 171, env.DCI_ConfigPanel.height)
                -- Dependent rows only work once the limit is on.
                assert.is_false(env.DCI_Config_SoulShardLimit.enabled)
                assert.is_false(env.DCI_Config_Checkbox_SoulShardAutoDelete.enabled)
                assert.is_false(env.DCI_Config_Checkbox_SoulShardAnnounce.enabled)
                env.DCI_Config_Checkbox_SoulShardLimitEnabled:SetChecked(true)
                env.DCI_Config_Checkbox_SoulShardLimitEnabled:Fire("OnClick")
                assert.is_true(env.DCI_Config_SoulShardLimit.enabled)
                assert.is_true(env.DCI_Config_Checkbox_SoulShardAutoDelete.enabled)
                assert.is_false(env.DCI_Config_Checkbox_SoulShardAnnounce.enabled)
            end)

            it("lists shards as before while the limit is off", function()
                local env = setup(client)
                putShards(env, 0, 3)
                assert.same({ SHARD }, listedIDs(env))
                env.addon.db.MaxQuality = 0
                assert.same({}, listedIDs(env))
            end)

            it("lists shards only beyond the limit, regardless of other filters, ignoring soul bags", function()
                local env = setup(client, { SoulShardLimitEnabled = true, SoulShardLimit = 3, MaxQuality = 0 })
                putShards(env, 0, 3)
                putShards(env, 1, 5, 4)
                assert.same({}, listedIDs(env))
                env.putItem(0, 4, SHARD)
                assert.same({ SHARD }, listedIDs(env))
                assert.equals(1, env.addon.CountExtraSoulShards())
                -- A displayed extra shard can be deleted even though Poor is the max quality.
                assert.is_true(env.addon.ConfirmAndDeleteBagItem(0, 1))
                assert.same({ SHARD }, env.deleted)
                assert.is_nil(env.addon.GetActionableBagItem(0, 2))
            end)

            it("leaves ignored shards alone", function()
                local env = setup(client, { SoulShardLimitEnabled = true, SoulShardLimit = 0, SoulShardAutoDelete = true })
                env.addon.SaveIgnoredItem(SHARD)
                putShards(env, 0, 4)
                bagUpdate(env)
                assert.equals(4, countShards(env))
                assert.same({}, listedIDs(env))
            end)

            it("deletes extra shards after bag changes and announces them once", function()
                local env = setup(client, { SoulShardLimitEnabled = true, SoulShardLimit = 2, SoulShardAutoDelete = true })
                assert.is_true(env.DCIFrame.events.ITEM_LOCK_CHANGED)
                putShards(env, 0, 5)
                putShards(env, 1, 4, 4)
                bagUpdate(env)
                assert.same({ SHARD, SHARD, SHARD }, env.deleted)
                assert.equals(2 + 4, countShards(env))
                assert.equals(1, #env.messages)
                assert.is_truthy(env.messages[1]:find("Deleted extra Soul Shards: 3. Keeping 2.", 1, true))
            end)

            it("stays quiet when announcements are off", function()
                local env = setup(client, { SoulShardLimitEnabled = true, SoulShardLimit = 0,
                    SoulShardAutoDelete = true, SoulShardAnnounce = false })
                putShards(env, 0, 2)
                bagUpdate(env)
                assert.equals(0, countShards(env))
                assert.equals(0, #env.messages)
            end)

            it("waits for combat, the cursor, and locked shards to clear", function()
                local env = setup(client, { SoulShardLimitEnabled = true, SoulShardLimit = 1, SoulShardAutoDelete = true })
                putShards(env, 0, 2)
                env.bags[0].slots[2].isLocked = true
                env.inCombat = true
                bagUpdate(env)
                assert.same({}, env.deleted)
                env.inCombat = false
                env.cursor = { "item", 10 }
                env.fire("PLAYER_REGEN_ENABLED")
                env.runTimers()
                assert.same({}, env.deleted)
                env.cursor = nil
                env.fire("ITEM_LOCK_CHANGED", 0, 2)
                env.runTimers()
                -- The unlocked shard is deleted; the locked one waits for its unlock.
                assert.same({ SHARD }, env.deleted)
                assert.is_true(env.bags[0].slots[2] ~= nil)
            end)

            it("does not count a deleted shard twice before its bag updates", function()
                local env = setup(client, { SoulShardLimitEnabled = true, SoulShardLimit = 1, SoulShardAutoDelete = true })
                putShards(env, 0, 2)
                bagUpdate(env)
                assert.equals(1, #env.deleted)
                -- Simulate the server not having removed the deleted shard yet.
                env.putItem(0, 1, SHARD)
                env.fire("ITEM_LOCK_CHANGED", 0, 1)
                env.runTimers()
                assert.equals(1, #env.deleted)
                assert.same({}, listedIDs(env))
                bagUpdate(env, 0)
                assert.equals(2, #env.deleted)
            end)

            it("asks before a settings change deletes shards, and turns auto-delete off when declined", function()
                local env = setup(client, { SoulShardLimitEnabled = true, SoulShardLimit = 2 })
                putShards(env, 0, 5)
                local auto = env.DCI_Config_Checkbox_SoulShardAutoDelete
                auto:SetChecked(true)
                auto:Fire("OnClick")
                assert.equals("DCI_SOUL_SHARD_CLEANUP", env.popup.key)
                assert.equals(3, env.popup.text1)
                -- Bag changes wait for the answer.
                bagUpdate(env)
                assert.same({}, env.deleted)
                env.StaticPopupDialogs.DCI_SOUL_SHARD_CLEANUP.OnCancel()
                assert.is_false(env.addon.db.SoulShardAutoDelete)
                assert.is_false(auto:GetChecked())
                bagUpdate(env)
                assert.same({}, env.deleted)

                auto:SetChecked(true)
                auto:Fire("OnClick")
                env.acceptPopup()
                assert.equals(3, #env.deleted)
            end)

            it("applies a typed limit only when editing finishes", function()
                local env = setup(client, { SoulShardLimitEnabled = true, SoulShardLimit = 10, SoulShardAutoDelete = true })
                putShards(env, 0, 12)
                bagUpdate(env)
                assert.equals(2, #env.deleted)
                local box = env.DCI_Config_SoulShardLimit
                box:SetText("1")
                assert.equals(10, env.addon.db.SoulShardLimit)
                box:SetText("4")
                box:Fire("OnEditFocusLost")
                assert.equals(4, env.addon.db.SoulShardLimit)
                assert.equals("DCI_SOUL_SHARD_CLEANUP", env.popup.key)
                assert.equals(6, env.popup.text1)
                env.acceptPopup()
                assert.equals(4, countShards(env))
                -- Raising the limit never asks.
                env.popup = nil
                box:SetText("20")
                box:Fire("OnEditFocusLost")
                assert.is_nil(env.popup)
            end)

            it("asks before a profile change deletes shards", function()
                local env = setup(client)
                putShards(env, 0, 3)
                local original = env.addon.Profiles:GetCurrentProfile()
                env.addon.CreateProfile("Shards")
                env.addon.db.SoulShardLimitEnabled = true
                env.addon.db.SoulShardLimit = 1
                env.addon.db.SoulShardAutoDelete = true
                env.addon.SelectProfile(original)
                assert.is_nil(env.popup)
                env.addon.SelectProfile("Shards")
                assert.equals("DCI_SOUL_SHARD_CLEANUP", env.popup.key)
                assert.same({}, env.deleted)
            end)
        end)
    end
end
