local _, DCI = ...
local L = DCI.L

function DCI.CreateProfileControls(parent)
    local section = CreateFrame("Frame", "DCI_ProfileControls", parent)
    section:SetPoint("TOPLEFT", 16, -680)
    section:SetSize(600, 310)
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
    local function CanCopy(name)
        return name ~= DCI.Profiles:GetCurrentProfile()
    end
    local copy = Dropdown("DCI_ProfileCopy", 0, -128, L["Copy from"], CanCopy,
        function(name) DCI.ConfirmProfileAction("copy", name) end)
    local delete = Dropdown("DCI_ProfileDelete", 300, -128, L["Delete unused profile"], DCI.CanDeleteProfile,
        function(name) DCI.ConfirmProfileAction("delete", name) end)

    local function EmptyHelp(dropdown, name, text)
        local helpText = section:CreateFontString(name, "ARTWORK", "GameFontDisableSmall")
        helpText:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -5)
        helpText:SetSize(280, 32)
        helpText:SetJustifyH("LEFT")
        helpText:SetWordWrap(true)
        helpText:SetText(text)
        return helpText
    end
    local copyHelp = EmptyHelp(copy, "DCI_ProfileCopyHelp", L["No other profiles are available to copy from."])
    local deleteHelp = EmptyHelp(delete, "DCI_ProfileDeleteHelp", L["No unused profiles are available. Profiles in use cannot be deleted."])

    local function RefreshAvailability(dropdown, helpText, names, include)
        for _, name in ipairs(names) do
            if include(name) then
                dropdown:Enable()
                helpText:Hide()
                return
            end
        end
        dropdown:Disable()
        helpText:Show()
    end

    local input = CreateFrame("EditBox", "DCI_ProfileName", section, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", 6, -207)
    input:SetSize(270, 28)
    input.DCI_FrameType = DCI.FRAME_EDITBOX
    input:SetAutoFocus(false)
    input:SetMaxLetters(50)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local status = section:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    status:SetPoint("TOPLEFT", 0, -249)
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
    button:SetPoint("TOPLEFT", 300, -204)
    button:SetSize(150, 32)
    button:SetText(L["Create profile"])
    button:SetScript("OnClick", Create)

    function DCI.RefreshProfileControls()
        active:SetDefaultText(DCI.Profiles:GetCurrentProfile())
        local names = DCI.Profiles:GetProfiles()
        RefreshAvailability(copy, copyHelp, names, CanCopy)
        RefreshAvailability(delete, deleteHelp, names, DCI.CanDeleteProfile)
        status:SetText(L["Enter a name to create a profile with defaults. Only unused profiles can be deleted."])
    end
    section:SetScript("OnShow", DCI.RefreshProfileControls)
    DCI.RefreshProfileControls()
end
