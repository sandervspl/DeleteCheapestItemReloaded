local addonName, DCI = ...
local L = DCI.L
local broker = LibStub("LibDataBroker-1.1")
local minimap = LibStub("LibDBIcon-1.0")

function DCI.InitializeBroker()
    if type(DCI.db.Minimap) ~= "table" then DCI.db.Minimap = {} end
    if DCI.db.Minimap.hide == nil then DCI.db.Minimap.hide = false end

    if not DCI.Broker then
        DCI.Broker = broker:NewDataObject(addonName, {
            type = "launcher",
            label = DCI.ADDON_TITLE,
            tocname = addonName,
            icon = "Interface\\AddOns\\" .. addonName .. "\\Media\\icon",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    if IsControlKeyDown() then
                        DCI.ShowIgnoredItems()
                    else
                        DCI.ToggleDCIFrame()
                    end
                elseif button == "RightButton" then
                    DCI.OpenSettings()
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine(DCI.ADDON_TITLE)
                tooltip:AddLine(L["Left-click to toggle the window."], 1, 1, 1)
                tooltip:AddLine(L["Right-click to open settings."], 1, 1, 1)
                tooltip:AddLine(L["Ctrl+left-click to open ignored items."], 1, 1, 1)
            end,
        })
        minimap:Register(addonName, DCI.Broker, DCI.db.Minimap)
    else
        -- Resetting defaults replaces DCI.db; rebind the library to the new table.
        minimap:Refresh(addonName, DCI.db.Minimap)
    end
end

function DCI.SetMinimapHidden(hidden)
    DCI.db.Minimap.hide = hidden and true or false
    if DCI.db.Minimap.hide then
        minimap:Hide(addonName)
    else
        minimap:Show(addonName)
    end
end
