local Helpers = dofile("Tests/helpers.lua")

local function login(env)
    for _, frame in ipairs(env.frames) do
        if frame.events.PLAYER_LOGIN then frame:Fire("OnEvent", "PLAYER_LOGIN") end
    end
end

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " broker launcher", function()
        it("opens each existing window from panel and minimap clicks without changing inventory", function()
            local env = Helpers.loadAddon({ client = client, saved = { IgnoredItems = { [20] = true } } })
            env.putItem(0, 1, 10)
            login(env)
            local object = env.LibStub("LibDataBroker-1.1"):GetDataObjectByName(env.addonName)
            local button = env.LibStub("LibDBIcon-1.0"):GetMinimapButton(env.addonName)
            assert.equals("launcher", object.type)
            assert.equals(object, button.dataObject)
            assert.is_true(button:IsShown())

            object.OnClick({}, "LeftButton")
            assert.is_true(env.DCIFrame:IsShown())
            button:Fire("OnClick", "LeftButton")
            assert.is_false(env.DCIFrame:IsShown())
            object.OnClick({}, "RightButton")
            assert.equals(42, env.openedCategory)
            env.openedCategory = nil
            button:Fire("OnClick", "RightButton")
            assert.equals(42, env.openedCategory)

            env.controlDown = true
            object.OnClick({}, "LeftButton")
            assert.is_true(env.addon.IgnoredItemsFrame:IsShown())
            assert.is_false(env.DCIFrame:IsShown())
            env.addon.IgnoredItemsFrame:Hide()
            button:Fire("OnClick", "LeftButton")
            assert.is_true(env.addon.IgnoredItemsFrame:IsShown())
            object.OnClick({}, "MiddleButton")
            assert.is_false(env.DCIFrame:IsShown())
            assert.same({}, env.deleted)
            assert.same({}, env.sold)
            assert.equals(10, env.bags[0].slots[1].itemID)
            assert.is_true(env.DCI_DB.IgnoredItems[20])

            local lines = {}
            object.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = text end })
            assert.same({ env.addon.ADDON_TITLE, "Left-click to toggle the window.",
                "Right-click to open settings.", "Ctrl+left-click to open ignored items." }, lines)
            local tooltip = env.LibStub("LibDBIcon-1.0").tooltip
            lines = {}
            tooltip.AddLine = function(_, text) lines[#lines + 1] = text end
            button:Fire("OnEnter")
            assert.equals(4, #lines)
            assert.equals(env.addon.ADDON_TITLE, lines[1])
            assert.is_true(tooltip:IsShown())
            button:Fire("OnLeave")
            assert.is_false(tooltip:IsShown())
        end)

        it("persists a dragged position and hidden state through login, then resets to a live settings table", function()
            local env = Helpers.loadAddon({ client = client })
            login(env)
            local icon = env.LibStub("LibDBIcon-1.0"):GetMinimapButton(env.addonName)
            icon:Fire("OnDragStart")
            icon:Fire("OnUpdate")
            icon:Fire("OnDragStop")
            local position = env.DCI_DB.Minimap.minimapPos
            assert.is_true(position > 0 and position < 90)
            local checkbox = env.DCI_Config_Checkbox_HideMinimapButton
            checkbox:SetChecked(true)
            checkbox:Fire("OnClick")
            assert.is_false(icon:IsShown())
            assert.is_true(env.DCI_DB.Minimap.hide)

            local reloaded = Helpers.loadAddon({ client = client, saved = env.DCI_DB })
            login(reloaded)
            local library = reloaded.LibStub("LibDBIcon-1.0")
            icon = library:GetMinimapButton(reloaded.addonName)
            assert.is_false(icon:IsShown())
            assert.equals(position, reloaded.DCI_DB.Minimap.minimapPos)
            assert.is_true(reloaded.DCI_Config_Checkbox_HideMinimapButton:GetChecked())
            -- Panel remains available even with the minimap button hidden.
            reloaded.addon.Broker.OnClick({}, "RightButton")
            assert.equals(42, reloaded.openedCategory)

            local oldSettings = reloaded.DCI_DB.Minimap
            local object = reloaded.addon.Broker
            reloaded.addon.InitializeSavedVariables(true)
            reloaded.addon.UpdateDCISettings()
            assert.equals(object, reloaded.addon.Broker)
            assert.is_true(oldSettings ~= icon.db)
            assert.equals(reloaded.DCI_DB.Minimap, icon.db)
            assert.is_true(icon:IsShown())
            assert.is_false(reloaded.DCI_Config_Checkbox_HideMinimapButton:GetChecked())
            icon:Fire("OnDragStart")
            icon:Fire("OnUpdate")
            icon:Fire("OnDragStop")
            assert.equals(position, reloaded.DCI_DB.Minimap.minimapPos)
            reloaded.addon.SetMinimapHidden(true)
            reloaded.addon.SetMinimapHidden(false)
            assert.is_true(icon:IsShown())
            assert.is_false(reloaded.DCI_DB.Minimap.hide)
        end)

        it("keeps a saved hidden button hidden when settings change before PLAYER_LOGIN", function()
            local env = Helpers.loadAddon({ client = client, saved = { Minimap = { hide = true, minimapPos = 42 } } })
            env.addon.SetMinimapHidden(false)
            env.addon.SetMinimapHidden(true)
            login(env)
            local icon = env.LibStub("LibDBIcon-1.0"):GetMinimapButton(env.addonName)
            assert.is_false(icon:IsShown())
            assert.equals(42, icon.db.minimapPos)
        end)
    end)
end
