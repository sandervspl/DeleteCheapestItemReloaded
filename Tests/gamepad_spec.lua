local Helpers = dofile("Tests/helpers.lua")

-- Mirrors Forever's insecure-call rules: the focus manager and SmartNavigation refuse addon
-- calls while the combat restriction is active.
local function LoadWithGamepad(client, gamepadUI, startRestricted)
    return Helpers.loadAddon({ client = client, beforeLoad = function(env)
        env.gamepadUI = gamepadUI ~= false
        env.restricted = startRestricted == true
        env.focused, env.navIgnored, env.focusCalls = {}, {}, 0
        local function Allowed() assert(not env.restricted, "Interface action blocked") end
        env.InputUtil = { IsGamepadUIEnabled = function() return env.gamepadUI end }
        env.GamepadMode = { FrameControlsManager = {
            FrameShown = function(_, frame)
                Allowed()
                env.focusCalls = env.focusCalls + 1
                if env.gamepadUI then env.focused[frame] = true end
            end,
            FrameHidden = function(_, frame)
                Allowed()
                env.focusCalls = env.focusCalls + 1
                env.focused[frame] = nil
            end,
        } }
        env.SmartNavigation = {
            GetCurrentButton = function(self) return self.current end,
            SetTargetButtonForFrame = function(self, frame, button)
                Allowed()
                self.target = { frame = frame, button = button }
                self.current = button
            end,
        }
        env.SmartNavigation_MarkFrameIgnored = function(frame)
            Allowed()
            env.navIgnored[frame] = true
        end
        env.Enum = env.Enum or {}
        env.Enum.AddOnRestrictionType = { Combat = 0, Encounter = 1 }
        env.Enum.AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 }
        env.C_RestrictedActions = { IsAddOnRestrictionActive = function(kind)
            return kind == env.Enum.AddOnRestrictionType.Combat and env.restricted
        end }
    end })
end

local function FireWatcher(env, event, ...)
    for _, frame in ipairs(env.frames) do
        if frame.events[event] and frame ~= env.DCIFrame then frame:Fire("OnEvent", event, ...) end
    end
end

local function SetCombat(env, active)
    local state = env.Enum.AddOnRestrictionState
    if active then
        FireWatcher(env, "ADDON_RESTRICTION_STATE_CHANGED", 0, state.Activating)
        env.restricted = true
    else
        env.restricted = false
        FireWatcher(env, "ADDON_RESTRICTION_STATE_CHANGED", 0, state.Inactive)
    end
end

local forever = Helpers.clients[4]
assert(forever.game == "camelot")

describe("Forever controller support", function()
    it("gives the window controller focus only while it is shown", function()
        local env = LoadWithGamepad(forever)
        assert.is_nil(env.focused[env.DCIFrame])
        env.addon.ToggleDCIFrame()
        assert.is_true(env.focused[env.DCIFrame])
        env.DCIFrame.CloseButton:Fire("OnClick")
        assert.is_nil(env.focused[env.DCIFrame])
    end)

    it("leaves keyboard and mouse mode alone until the input style switches", function()
        local env = LoadWithGamepad(forever, false)
        env.addon.ToggleDCIFrame()
        assert.is_nil(env.focused[env.DCIFrame])
        env.gamepadUI = true
        FireWatcher(env, "INPUT_DEVICE_INTERFACE_TRANSITION", 1, 0)
        assert.is_nil(env.focused[env.DCIFrame])
        env.runTimers()
        assert.is_true(env.focused[env.DCIFrame])
    end)

    it("releases focus before combat and restores it afterwards without blocked calls", function()
        local env = LoadWithGamepad(forever)
        env.addon.ToggleDCIFrame()
        SetCombat(env, true)
        assert.is_nil(env.focused[env.DCIFrame])
        -- Hiding and showing during combat must not call the restricted APIs.
        env.addon.ToggleDCIFrame()
        env.addon.ToggleDCIFrame()
        SetCombat(env, false)
        assert.is_true(env.focused[env.DCIFrame])

        SetCombat(env, true)
        env.addon.ToggleDCIFrame()
        SetCombat(env, false)
        assert.is_nil(env.focused[env.DCIFrame])

        local calls = env.focusCalls
        FireWatcher(env, "ADDON_RESTRICTION_STATE_CHANGED", 1, env.Enum.AddOnRestrictionState.Activating)
        assert.equals(calls, env.focusCalls)
    end)

    it("keeps drag handles and resize grips out of navigation, including when created in combat", function()
        local env = LoadWithGamepad(forever, true, true)
        env.addon.UpdateDCIFrame(false)
        assert.is_nil(env.navIgnored[env.DCI_DragFrame])
        SetCombat(env, false)
        assert.is_true(env.navIgnored[env.DCI_DragFrame])
        assert.is_true(env.navIgnored[env.DCIFrame.ResizeGrip])

        env.SlashCmdList.DCI("ignored")
        local frame = env.addon.IgnoredItemsFrame
        assert.is_true(env.navIgnored[frame.ResizeGrip])
        local ignoredDrag = 0
        for _, child in ipairs(frame.TitleContainer.children) do
            if env.navIgnored[child] then ignoredDrag = ignoredDrag + 1 end
        end
        assert.equals(1, ignoredDrag)
        assert.is_true(env.focused[frame])
        frame.CloseButton:Fire("OnClick")
        assert.is_nil(env.focused[frame])
    end)

    it("ignores the focused item from its icon and moves the cursor off a removed row", function()
        local env = LoadWithGamepad(forever)
        env.putItem(0, 1, 10)
        env.putItem(0, 2, 20)
        env.addon.ToggleDCIFrame()
        local icon = env.DCI_ItemIcon2
        icon:Fire("OnEnter")
        assert.is_false(env.DCI_IgnoreButton:IsShown())
        assert.is_true(env.DCI_SecondTooltip:IsShown())
        icon:Fire("OnLeave")
        assert.is_false(env.DCI_SecondTooltip:IsShown())

        env.SmartNavigation.current = icon
        local ignoredID = env.addon.GetSortedBagItems()[2].itemID
        icon:Fire("OnClick")
        assert.is_true(env.addon.IsItemIgnored(ignoredID))
        assert.is_false(env.DCI_Item2:IsShown())
        assert.equals(env.DCIFrame, env.SmartNavigation.target.frame)
        assert.equals(env.DCI_DeleteButton1, env.SmartNavigation.target.button)

        -- A reused row refreshes the tooltip for its new item.
        env.DCI_SecondTooltip:Hide()
        env.addon.UpdateDCIFrame(false)
        assert.is_true(env.DCI_SecondTooltip:IsShown())
    end)

    it("keeps the mouse overlay for ignoring outside controller mode", function()
        local env = LoadWithGamepad(forever, false)
        env.putItem(0, 1, 10)
        env.addon.ToggleDCIFrame()
        env.DCI_ItemIcon1:Fire("OnEnter")
        assert.is_true(env.DCI_IgnoreButton:IsShown())
        env.DCI_ItemIcon1:Fire("OnLeave")
        assert.is_true(env.DCI_SecondTooltip:IsShown())
        env.DCI_ItemIcon1:Fire("OnClick")
        assert.is_false(env.addon.IsItemIgnored(10))
        env.DCI_IgnoreButton:Fire("OnClick")
        assert.is_true(env.addon.IsItemIgnored(10))
    end)
end)

for _, client in ipairs(Helpers.clients) do
    if client.game ~= "camelot" then
        describe(client.name .. " without controller integration", function()
            it("never calls the Forever gamepad APIs", function()
                local env = LoadWithGamepad(client)
                env.putItem(0, 1, 10)
                env.addon.ToggleDCIFrame()
                env.SlashCmdList.DCI("ignored")
                env.DCI_ItemIcon1:Fire("OnEnter")
                assert.is_true(env.DCI_IgnoreButton:IsShown())
                env.DCI_ItemIcon1:Fire("OnClick")
                assert.is_false(env.addon.IsItemIgnored(10))
                assert.equals(0, env.focusCalls)
                assert.is_nil(next(env.navIgnored))
            end)
        end)
    end
end
