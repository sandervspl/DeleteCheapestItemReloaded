local Helpers = dofile("Tests/helpers.lua")

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = Copy(entry) end
    return result
end

local function Reload(env, name, character, saved)
    return Helpers.loadAddon({ client = env.client, name = name,
        profiles = Copy(env.DCI_ProfilesDB), character = Copy(character or env.DCI_CharDB),
        saved = Copy(saved or env.DCI_DB) })
end

local function Login(env)
    for _, frame in ipairs(env.frames) do
        if frame.events.PLAYER_LOGIN then frame:Fire("OnEvent", "PLAYER_LOGIN") end
    end
end

local function Choose(dropdown, choice)
    local entries = {}
    dropdown.menu(dropdown, { CreateButton = function(_, name, callback) entries[name] = callback end })
    assert.is_truthy(entries[choice])
    entries[choice]()
end

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " profiles", function()
        it("migrates two characters independently, shares deliberate edits and keeps protections through copy/reset/reload", function()
            local legacyA = { MaxQuality = 0, HideSoulbound = false, IgnoredItems = { 10, 20 },
                WindowPosition = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 80, y = -40 },
                Minimap = { hide = true, minimapPos = 62 } }
            local a = Helpers.loadAddon({ client = client, name = "Alpha", saved = legacyA })
            local originalA = a.addon.Profiles:GetCurrentProfile()
            assert.equals(0, a.addon.db.MaxQuality)
            assert.is_false(a.addon.db.HideSoulbound)
            assert.is_nil(a.addon.db.IgnoredItems)
            a.addon.Character.IgnoredItems[1] = 30
            assert.same({ 10, 20 }, legacyA.IgnoredItems)
            assert.is_true(a.addon.CreateProfile("Shared"))
            a.addon.db.MaxQuality = 1
            a.addon.db.Minimap.minimapPos = 120
            local charA = Copy(a.DCI_CharDB)
            local b = Reload(a, "Beta", {}, { MaxQuality = 2, IgnoredItems = { 40 } })
            local originalB = b.addon.Profiles:GetCurrentProfile()
            assert.is_true(originalA ~= originalB)
            assert.equals(2, b.addon.db.MaxQuality)
            assert.same({ 40 }, b.addon.Character.IgnoredItems)
            Choose(b.DCI_ProfileSelect, "Shared")
            assert.equals(1, b.addon.db.MaxQuality)
            b.addon.db.MaxQuality = 0
            assert.is_false(b.addon.DeleteProfile("Shared"))
            a = Reload(b, "Alpha", charA, legacyA)
            assert.equals("Shared", a.addon.Profiles:GetCurrentProfile())
            assert.equals(0, a.addon.db.MaxQuality)
            assert.same({ 30, 20 }, a.addon.Character.IgnoredItems)
            a.DCI_ProfileName:SetText("Independent")
            a.DCI_ProfileCreate:Fire("OnClick")
            Choose(a.DCI_ProfileCopy, "Shared")
            a.acceptPopup()
            assert.equals(120, a.addon.db.Minimap.minimapPos)
            a.addon.db.Minimap.minimapPos = 250
            assert.equals(120, a.addon.Profiles.profiles.Shared.Minimap.minimapPos)
            a.DCI_Config_Button_ResetProfi:Fire("OnClick")
            a.acceptPopup()
            assert.equals(2, a.addon.db.MaxQuality)
            assert.same({ 30, 20 }, a.addon.Character.IgnoredItems)
            assert.equals(0, a.addon.Profiles.profiles.Shared.MaxQuality)
            Choose(a.DCI_ProfileSelect, originalA)
            Choose(a.DCI_ProfileDelete, "Independent")
            a.acceptPopup()
            assert.is_nil(a.addon.Profiles.profiles.Independent)
            a = Reload(a, "Alpha")
            assert.equals(originalA, a.addon.Profiles:GetCurrentProfile())
            assert.equals(0, a.addon.db.MaxQuality)
            assert.same({ 30, 20 }, a.addon.Character.IgnoredItems)
        end)

        it("switches sizes, positions and minimap visibility, ending old drags before rebinding", function()
            local env = Helpers.loadAddon({ client = client })
            Login(env)
            local dci = env.addon
            local first = dci.Profiles:GetCurrentProfile()
            dci.ShowIgnoredItems()
            dci.db.WindowSize = { width = 450, height = 380 }
            dci.db.IgnoredWindowSize = { width = 510, height = 400 }
            dci.db.WindowPosition = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 150, y = -80 }
            dci.db.IgnoredWindowPosition = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 240, y = 90 }
            dci.db.Minimap = { hide = true, minimapPos = 32 }
            dci.ApplyProfile()
            assert.equals(450, env.DCIFrame.width)
            assert.equals(510, dci.IgnoredItemsFrame.width)
            assert.equals(240, dci.IgnoredItemsFrame.point[4])
            for _, child in ipairs(dci.IgnoredItemsFrame.children) do
                if child:GetObjectType() == "Frame" and child:GetScript("OnMouseDown") then
                    child:Fire("OnMouseDown", "LeftButton")
                    dci.IgnoredItemsFrame:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 240, 95)
                    dci.IgnoredItemsFrame:Hide()
                    assert.equals(95, dci.db.IgnoredWindowPosition.y)
                end
            end
            dci.ShowIgnoredItems()
            local icon = env.LibStub("LibDBIcon-1.0"):GetMinimapButton(env.addonName)
            assert.is_false(icon:IsShown())
            env.DCIFrame.ResizeGrip:Fire("OnMouseDown", "LeftButton")
            env.DCIFrame:SetSize(480, 420)
            assert.is_true(dci.CreateProfile("Other layout"))
            assert.is_false(env.DCIFrame.DCI_Resizing)
            assert.equals(480, dci.Profiles.profiles[first].WindowSize.width)
            assert.equals(290, env.DCIFrame.width)
            assert.equals(310, dci.IgnoredItemsFrame.width)
            assert.is_true(icon:IsShown())
            assert.equals(dci.db.Minimap, icon.db)
            assert.is_true(dci.SelectProfile(first))
            assert.equals(480, env.DCIFrame.width)
            assert.equals(420, env.DCIFrame.height)
            assert.equals(150, env.DCIFrame.point[4])
            assert.equals(510, dci.IgnoredItemsFrame.width)
            assert.equals(240, dci.IgnoredItemsFrame.point[4])
            assert.is_false(icon:IsShown())
            assert.equals(32, icon.db.minimapPos)
            local reloaded = Reload(env)
            Login(reloaded)
            reloaded.addon.ShowIgnoredItems()
            assert.equals(480, reloaded.DCIFrame.width)
            assert.equals(240, reloaded.addon.IgnoredItemsFrame.point[4])
            assert.is_true(reloaded.DCI_Config_Checkbox_HideMinimapButton:GetChecked())
        end)

        it("invalidates pending deletion and loot work, updates events and rebuilds auction values", function()
            local env = Helpers.loadAddon({ client = client, saved = { ConfirmMinQuality = 0 } })
            env.putItem(0, 1, 10)
            local dci = env.addon
            local first = dci.Profiles:GetCurrentProfile()
            assert.is_true(dci.CreateProfile("Quiet"))
            dci.db.Auto_Loot = false
            dci.db.Auto_LowSlots = false
            dci.db.Auto_Vendor = false
            dci.db.SubtractAuctionCut = false
            dci.SelectProfile(first)
            dci.ConfirmAndDeleteBagItem(0, 1, env.bags[0].slots[1])
            local stale = env.StaticPopupDialogs.DCI_RELOADED_DELETE_ITEM.OnAccept
            local data = env.popup.data
            env.LootFrame:Show()
            env.fire("LOOT_OPENED")
            dci.ItemInfo[999] = { auctionPricePer = 123 }
            Choose(env.DCI_ProfileSelect, "Quiet")
            assert.is_nil(env.popup)
            stale({}, data)
            assert.same({}, env.deleted)
            assert.is_nil(env.DCIFrame.events.LOOT_OPENED)
            assert.is_nil(rawget(dci.ItemInfo, 999))
            assert.is_false(env.DCI_Config_Checkbox_Auto_Loot:GetChecked())
            env.runTimers()
            assert.same({}, env.deleted)
            assert.equals(10, env.bags[0].slots[1].itemID)
        end)

        it("rejects invalid names, preserves referenced profiles and cancels stale destructive requests", function()
            local env = Helpers.loadAddon({ client = client })
            local dci = env.addon
            local first = dci.Profiles:GetCurrentProfile()
            for _, name in ipairs({ "", "   ", "x|r", "a\nb", string.rep("a", 51) }) do
                assert.is_false(dci.CreateProfile(name))
            end
            assert.is_true(dci.CreateProfile("  Farming  "))
            assert.equals("Farming", dci.Profiles:GetCurrentProfile())
            assert.is_false(dci.CreateProfile("Farming"))
            dci.db.MaxQuality = 0
            dci.ConfirmProfileAction("reset")
            local stale = env.StaticPopupDialogs.DCI_PROFILE_ACTION.OnAccept
            dci.SelectProfile(first)
            dci.SelectProfile("Farming")
            stale()
            assert.equals(0, dci.Profiles.profiles.Farming.MaxQuality)
            dci.SelectProfile(first)
            dci.Profiles.sv.profileKeys.OtherCharacter = "Farming"
            assert.is_false(dci.DeleteProfile("Farming"))
            assert.equals(0, dci.Profiles.profiles.Farming.MaxQuality)
        end)

        it("avoids overwriting a named profile during migration and accepts bounded Unicode names", function()
            local env = Helpers.loadAddon({ client = client, name = "Alpha" })
            local reserved = client.scrollBoxLoot and "Beta Surname" or "Beta - Realm"
            assert.is_true(env.addon.CreateProfile(reserved))
            env.addon.db.MaxQuality = 0
            local beta = Reload(env, "Beta", {}, { MaxQuality = 1, IgnoredItems = { 77 } })
            assert.equals(reserved .. " (2)", beta.addon.Profiles:GetCurrentProfile())
            assert.equals(1, beta.addon.db.MaxQuality)
            assert.equals(0, beta.addon.Profiles.profiles[reserved].MaxQuality)
            assert.same({ 77 }, beta.addon.Character.IgnoredItems)
            local unicode = string.rep(string.char(195, 169), 50)
            assert.is_true(beta.addon.CreateProfile(unicode))
            assert.equals(unicode, beta.addon.Profiles:GetCurrentProfile())
            assert.is_false(beta.addon.CreateProfile(unicode .. "a"))
        end)
    end)
end
