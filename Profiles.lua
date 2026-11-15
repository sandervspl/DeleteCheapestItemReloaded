local _, DCI = ...
local L = DCI.L

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = Copy(entry) end
    return result
end

-- Only these legacy settings become profile data. Ignored items never enter a profile.
local profileFields = {
    "UseAuctionPrices", "SubtractAuctionCut", "AuctionPriceHidePoorQuality",
    "AuctionGreyUnderVendor", "HideSoulbound", "AllowInCombat", "HideBronzeTheme",
    "MaxQuality", "CompareByPrice", "FollowLootWindow", "HideWindowTitle",
    "ShowFullStackValues", "ShowBothPrices", "ConfirmMinQuality", "LowSlotsThreshold",
    "Auto_Loot", "Auto_Inventory", "Auto_LowSlots", "Auto_Vendor", "Auto_Trade",
    "Auto_Mail", "Auto_QuestAccept", "Auto_QuestComplete", "Auto_Roll",
    "WindowPosition", "IgnoredWindowPosition", "WindowSize", "IgnoredWindowSize", "Minimap",
}

function DCI.InitializeProfiles()
    if DCI.Profiles then return end
    DCI_CharDB = DCI_CharDB or {}
    DCI.Character = DCI_CharDB
    DCI.Profiles = LibStub("AceDB-3.0"):New("DCI_ProfilesDB")
    local db = DCI.Profiles
    if not DCI.Character.schemaVersion then
        local legacy = DCI_DB or {}
        DCI.Character.IgnoredItems = Copy(legacy.IgnoredItems or DCI_IgnoredItems or {})
        -- A separate name for every migrating character; never overwrite a shared profile.
        local base = db.keys.char
        -- Leave room for collision suffixes without splitting UTF-8 characters.
        while strlenutf8(base) > 38 do base = base:gsub("[^\128-\191][\128-\191]*$", "") end
        local name, suffix = base, 1
        while db.profiles[name] do
            suffix = suffix + 1
            name = base .. " (" .. suffix .. ")"
        end
        db:SetProfile(name)
        for _, key in ipairs(profileFields) do
            local value = legacy[key]
            if value == nil and next(legacy) == nil then value = _G["DCI_" .. key] end
            if value ~= nil then db.profile[key] = Copy(value) end
        end
        DCI.Character.schemaVersion = 1
    end
    DCI.Character.IgnoredItems = DCI.Character.IgnoredItems or {}
    DCI_ProfilesDB.schemaVersion = 1
    DCI.db = db.profile
    local function Apply()
        DCI.db = db.profile
        DCI.ApplyProfile()
    end
    db.RegisterCallback(DCI, "OnProfileChanged", Apply)
    db.RegisterCallback(DCI, "OnProfileCopied", Apply)
    db.RegisterCallback(DCI, "OnProfileReset", Apply)
end

local function ValidName(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or strlenutf8(name) > 50 or name:find("[%c|]") then return nil end
    return name
end

function DCI.SelectProfile(name)
    if not DCI.Profiles.profiles[name] then return false, L["Profile not found."] end
    DCI.PrepareProfileChange()
    DCI.Profiles:SetProfile(name)
    return true
end

function DCI.CreateProfile(name)
    name = ValidName(name)
    if not name then return false, L["Use a profile name of 1 to 50 characters without control characters or pipe characters."] end
    if DCI.Profiles.profiles[name] then return false, L["A profile with that name already exists."] end
    DCI.PrepareProfileChange()
    DCI.Profiles:SetProfile(name)
    return true
end

function DCI.CopyProfile(name)
    if not DCI.Profiles.profiles[name] or name == DCI.Profiles:GetCurrentProfile() then
        return false, L["Choose a different existing profile."]
    end
    DCI.PrepareProfileChange()
    DCI.Profiles:CopyProfile(name)
    return true
end

function DCI.ResetProfile()
    DCI.PrepareProfileChange()
    DCI.Profiles:ResetProfile()
    return true
end

function DCI.CanDeleteProfile(name)
    if not DCI.Profiles.profiles[name] or name == DCI.Profiles:GetCurrentProfile() then return false end
    for _, selected in pairs(DCI.Profiles.sv.profileKeys) do
        if selected == name then return false end
    end
    return true
end

function DCI.DeleteProfile(name)
    if not DCI.CanDeleteProfile(name) then return false, L["Only unused profiles can be deleted."] end
    DCI.Profiles:DeleteProfile(name)
    if DCI.RefreshProfileControls then DCI.RefreshProfileControls() end
    return true
end

-- Destructive requests capture both the source and destination before confirmation.
function DCI.ConfirmProfileAction(action, source)
    local destination = DCI.Profiles:GetCurrentProfile()
    local generation = DCI.profileGeneration
    local text
    if action == "copy" then
        text = string.format(L["Replace profile '%s' with a copy of '%s'?"], destination, source)
    elseif action == "reset" then
        text = string.format(L["Reset profile '%s' to defaults?"], destination)
    else
        text = string.format(L["Delete unused profile '%s'?"], source)
    end
    text = text .. "\n\n" .. L["Shared profile changes affect every character using it. Ignored items stay unchanged."]
    StaticPopupDialogs.DCI_PROFILE_ACTION = {
        text = "%s", button1 = YES, button2 = NO, timeout = 0,
        whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnAccept = function()
            if DCI.Profiles:GetCurrentProfile() ~= destination or DCI.profileGeneration ~= generation then return end
            if action == "copy" then DCI.CopyProfile(source)
            elseif action == "reset" then DCI.ResetProfile()
            else DCI.DeleteProfile(source) end
        end,
    }
    StaticPopup_Show("DCI_PROFILE_ACTION", text)
end
