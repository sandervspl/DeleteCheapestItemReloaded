local _, DCI = ...
local L = DCI.L

function DCI.CreateProfileControls(parent)
    local section = CreateFrame("Frame", "DCI_ProfileControls", parent)
    section:SetPoint("TOPLEFT", 16, -680)
    section:SetSize(600, 280)
    local heading = section:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 0, 0)
    heading:SetText(L["Profiles"])
    local help = section:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    help:SetPoint("TOPLEFT", 0, -28)
    help:SetSize(580, 45)
    help:SetJustifyH("LEFT")
    help:SetWordWrap(true)
    help:SetText(L["Selecting a profile shares future settings and layout changes. Copying makes independent settings. Ignored items stay per character."])

    local function Dropdown(name, x, y, label, include, select)
        local dropdown = CreateFrame("DropdownButton", name, section, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("TOPLEFT", x, y)
        dropdown:SetWidth(280)
        dropdown.DCI_FrameType = DCI.FRAME_DROPDOWN
        dropdown:SetupMenu(function(_, root)
            local names = DCI.Profiles:GetProfiles()
            table.sort(names)
            for _, name in ipairs(names) do
                if include(name) then
                    root:CreateButton(name, function() select(name) end)
                end
            end
        end)
        dropdown:SetDefaultText(label)
        return dropdown
    end

    local active = Dropdown("DCI_ProfileSelect", 0, -82, "", function() return true end, DCI.SelectProfile)
    Dropdown("DCI_ProfileCopy", 0, -128, L["Copy from"], function(name)
        return name ~= DCI.Profiles:GetCurrentProfile()
    end, function(name) DCI.ConfirmProfileAction("copy", name) end)
    Dropdown("DCI_ProfileDelete", 300, -128, L["Delete unused profile"], DCI.CanDeleteProfile,
        function(name) DCI.ConfirmProfileAction("delete", name) end)

    local input = CreateFrame("EditBox", "DCI_ProfileName", section, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", 6, -183)
    input:SetSize(270, 28)
    input.DCI_FrameType = DCI.FRAME_EDITBOX
    input:SetAutoFocus(false)
    input:SetMaxLetters(50)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local status = section:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    status:SetPoint("TOPLEFT", 0, -225)
    status:SetSize(580, 40)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(true)
    status:SetText(L["Enter a name to create a profile with default settings."])
    local function Create()
        local ok, message = DCI.CreateProfile(input:GetText())
        status:SetText(message or L["Profile created."])
        if ok then input:SetText(""); input:ClearFocus() end
    end
    input:SetScript("OnEnterPressed", Create)
    local button = CreateFrame("Button", "DCI_ProfileCreate", section, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", 300, -180)
    button:SetSize(150, 32)
    button:SetText(L["Create profile"])
    button:SetScript("OnClick", Create)

    function DCI.RefreshProfileControls()
        active:SetDefaultText(DCI.Profiles:GetCurrentProfile())
        status:SetText(L["Enter a name to create a profile with defaults. Only unused profiles can be deleted."])
    end
    section:SetScript("OnShow", DCI.RefreshProfileControls)
    DCI.RefreshProfileControls()
end
