-- Forever controller support through Blizzard's gamepad focus manager and SmartNavigation.
-- Other clients, and Forever in keyboard and mouse mode, leave every function here inert.
local _, DCI = ...

local _, _, _, interfaceVersion = GetBuildInfo()
local isForever = interfaceVersion >= 16000 and interfaceVersion < 17000

local Gamepad = {}
DCI.Gamepad = Gamepad

local windows = {}
local pendingIgnored = {}

local function FrameControls()
    return isForever and GamepadMode and GamepadMode.FrameControlsManager or nil
end

function Gamepad.IsActive()
    return FrameControls() ~= nil and InputUtil ~= nil and InputUtil.IsGamepadUIEnabled() == true
end

-- Forever refuses insecure focus-manager and SmartNavigation calls during the combat restriction.
local function IsRestricted()
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
        and Enum and Enum.AddOnRestrictionType then
        return C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat)
    end
    return InCombatLockdown ~= nil and InCombatLockdown()
end

local function IsDescendant(frame, ancestor)
    while frame do
        if frame == ancestor then return true end
        frame = frame:GetParent()
    end
    return false
end

local function FlushIgnoredFrames()
    if type(SmartNavigation_MarkFrameIgnored) ~= "function" or IsRestricted() then return end
    for frame in pairs(pendingIgnored) do
        SmartNavigation_MarkFrameIgnored(frame)
        pendingIgnored[frame] = nil
    end
end

-- Keep pointer-only controls such as drag handles and resize grips out of controller navigation.
function Gamepad.IgnoreFrame(frame)
    if not isForever or not frame then return end
    pendingIgnored[frame] = true
    FlushIgnoredFrames()
end

-- Add a visible window to controller focus, or remove a hidden one.
function Gamepad.Sync(frame)
    local manager = FrameControls()
    if not manager or IsRestricted() then return end
    if frame:IsShown() then
        if Gamepad.IsActive() then manager:FrameShown(frame) end
    else
        manager:FrameHidden(frame)
    end
end

local function ReleaseAll()
    local manager = FrameControls()
    if not manager then return end
    for frame in pairs(windows) do manager:FrameHidden(frame) end
end

local function SyncAll()
    FlushIgnoredFrames()
    for frame in pairs(windows) do Gamepad.Sync(frame) end
end

function Gamepad.RegisterWindow(frame)
    if not isForever or windows[frame] then return end
    windows[frame] = true
    frame:HookScript("OnShow", Gamepad.Sync)
    frame:HookScript("OnHide", Gamepad.Sync)
    Gamepad.Sync(frame)
end

-- Rows are reused when the list changes. Refresh the focused tooltip, or move the cursor
-- when its button disappeared.
function Gamepad.RefreshSelection(frame, fallback)
    if not Gamepad.IsActive() or not SmartNavigation or IsRestricted() then return end
    local current = SmartNavigation:GetCurrentButton()
    if not current or not IsDescendant(current, frame) then return end
    if current:IsVisible() then
        local onEnter = current:GetScript("OnEnter")
        if onEnter then onEnter(current) end
    elseif fallback and fallback:IsVisible() then
        SmartNavigation:SetTargetButtonForFrame(frame, fallback)
    end
end

if isForever then
    local watcher = CreateFrame("Frame")
    local function TryRegisterEvent(event)
        pcall(watcher.RegisterEvent, watcher, event)
    end
    local useRestrictionEvent = C_RestrictedActions and Enum and Enum.AddOnRestrictionType
        and Enum.AddOnRestrictionState
    if useRestrictionEvent then
        TryRegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    else
        TryRegisterEvent("PLAYER_REGEN_DISABLED")
        TryRegisterEvent("PLAYER_REGEN_ENABLED")
    end
    TryRegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
    watcher:SetScript("OnEvent", function(_, event, restrictionType, state)
        if event == "ADDON_RESTRICTION_STATE_CHANGED" then
            if restrictionType ~= Enum.AddOnRestrictionType.Combat then return end
            -- Calls are still allowed during this dispatch. Release focus before combat so a
            -- window hidden mid-combat can never keep the D-pad and face buttons captured.
            if state == Enum.AddOnRestrictionState.Activating then
                ReleaseAll()
            elseif state == Enum.AddOnRestrictionState.Inactive then
                SyncAll()
            end
        elseif event == "PLAYER_REGEN_DISABLED" then
            ReleaseAll()
        elseif event == "PLAYER_REGEN_ENABLED" then
            SyncAll()
        elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
            -- Let Blizzard's focus manager initialize for the new input style first.
            C_Timer.After(0, SyncAll)
        end
    end)
end
