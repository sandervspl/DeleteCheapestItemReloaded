-- DeleteCheapestItem Reloaded, maintained by Sander Vispoel (sandervspl).
-- Original addon by <Night Shift> Suey; previous maintainer CriitzLeFleur.
-- https://github.com/sandervspl/DeleteCheapestItemReloaded

--global namespace & localization table
local addonName, DCI = ...
local L = DCI.L
DCI_DB = DCI_DB or {}

-- Limit native bronze styling to Forever's interface range.
local _, _, _, interfaceVersion = GetBuildInfo()
local isForever = interfaceVersion >= 16000 and interfaceVersion < 17000

--constants & magic numbers
DCI.ADDON_TITLE = "DeleteCheapestItem Reloaded"
DCI.ADDON_VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version")
if not DCI.ADDON_VERSION or DCI.ADDON_VERSION:find("@", 1, true) then
    DCI.ADDON_VERSION = "7.0.0-dev"
end
DCI.MAX_ITEM_FRAMES = 100
DCI.PRICE_TYPE_VENDOR, DCI.PRICE_TYPE_AUCTION, DCI.PRICE_TYPE_BEST = 1,2,3
DCI.DEBUG_OUTPUT_FORCED, DCI.DEBUG_OUTPUT_INFO, DCI.DEBUG_OUTPUT_WARNING, DCI.DEBUG_OUTPUT_ERROR = 0,1,2,3
DCI.FRAME_PANEL, DCI.FRAME_CHECKBOX, DCI.FRAME_DROPDOWN, DCI.FRAME_FONTSTRING, DCI.FRAME_EDITBOX = 0,1,2,3,4
local WINDOW_CONTEXT_FREE, WINDOW_CONTEXT_LOOT, WINDOW_CONTEXT_QUESTACCEPT,
    WINDOW_CONTEXT_QUESTCOMPLETE, WINDOW_CONTEXT_VENDOR, WINDOW_CONTEXT_TRADE,
    WINDOW_CONTEXT_MAIL, WINDOW_CONTEXT_ROLL = 0,1,2,3,4,5,6,7
local windowContextNames = { [0] = "free", "loot", "quest accept", "quest reward", "vendor", "trade", "mail", "roll" }
local pendingLootUpdate
local pendingBagVisibilityUpdate
local bagWindowAutoOpened
local inventoryWindowDismissed
local lootWindowDismissed

local function IsLootFrameOpen()
    -- Forever's closing animation can leave the frame shown after LOOT_CLOSED.
    return LootFrame and LootFrame:IsShown() and DCI.LootOpen ~= false
end

local function IsInventoryOpen()
    if isForever and ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
        return true
    end
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS) do
        if IsBagOpen(bag) then return true end
    end
    return false
end

local function ShouldOpenForLowSlots()
    return DCI_DB.Auto_LowSlots and IsLootFrameOpen()
        and DCI.CountFreeBagSlots() <= DCI_DB.LowSlotsThreshold
end

function DCI.QueueInventoryVisibilityUpdate()
    if not DCI_DB.Auto_Inventory then return end
    local request = {}
    pendingBagVisibilityUpdate = request
    C_Timer.After(0, function()
        if pendingBagVisibilityUpdate ~= request or not DCI_DB.Auto_Inventory then return end
        pendingBagVisibilityUpdate = nil
        if IsInventoryOpen() then
            if not DCIFrame:IsShown() and not inventoryWindowDismissed then
                bagWindowAutoOpened = true
                DCI.UpdateDCIFrame()
                if not DCIFrame:IsShown() then bagWindowAutoOpened = false end
            end
        else
            inventoryWindowDismissed = false
            if bagWindowAutoOpened then
                bagWindowAutoOpened = false
                if DCIFrame:IsShown() and DCI.windowContext == WINDOW_CONTEXT_FREE then
                    DCI.HideWindow("inventory closed")
                end
            end
        end
    end)
end

--metatable for cached item info lookup
DCI.ItemInfo = setmetatable({}, {
    __index = function(t, itemID)
        local itemInfoTable = setmetatable({}, {
            __index = function(t, property)
                if itemID == nil then
                    DCI.DebugPrint("itemID is nil in metatable function", DCI.DEBUG_OUTPUT_WARNING)
                elseif property == "name" or property == "link" or property == "quality" or property == "icon" or property == "vendorPricePer" then
                    -- Item data can be unavailable until GET_ITEM_INFO_RECEIVED.
                    DCI.DebugPrint(string.format("Item Info Lookup: C_Item.GetItemInfo(%s)", itemID))
                    local info = {}
                    local itemLevel, minLevel, itemType, subType, stackSize, equipLoc
                    info.name, info.link, info.quality, itemLevel, minLevel, itemType, subType, stackSize, equipLoc, info.icon, info.vendorPricePer = C_Item.GetItemInfo(itemID)
                    rawset(t, "name", info['name'])
                    rawset(t, "link", info['link'])
                    rawset(t, "quality", info['quality'])
                    rawset(t, "icon", info['icon'])
                    rawset(t, "vendorPricePer", info['vendorPricePer'])
                    return info[property]
                elseif property == "auctionPricePer" or property == "bestPricePer" or property == "bestPriceType" then
                    --lookup auction prices
                    local info = {}
                    if DCI.UseAuctionPrices() and not (DCI_DB.AuctionPriceHidePoorQuality and DCI.ItemInfo[itemID].quality == 0) then
                        --auctions enabled and settings allow this quality 
                        DCI.DebugPrint(string.format("Item Info Lookup: DCI.GetAuctionPriceByItemID(%s)", itemID))
                        local vendorPricePer = DCI.ItemInfo[itemID].vendorPricePer
                        if vendorPricePer == nil then return nil end
                        local auctionPricePer = DCI.GetAuctionPriceByItemID(itemID)
                        if auctionPricePer then
                            --auctions enabled and price found
                            info['auctionPricePer'] = auctionPricePer
                            if (auctionPricePer > vendorPricePer) then
                                info['bestPricePer'] = auctionPricePer
                                info['bestPriceType'] = DCI.PRICE_TYPE_AUCTION
                            else
                                info['bestPricePer'] = vendorPricePer
                                info['bestPriceType'] = DCI.PRICE_TYPE_VENDOR
                            end
                        else
                            --auction enabled but nil for this item
                            info['auctionPricePer'] = auctionPricePer
                            info['bestPricePer'] = DCI.ItemInfo[itemID].vendorPricePer
                            info['bestPriceType'] = DCI.PRICE_TYPE_VENDOR
                        end
                    else
                        --auctions are not enabled for this item
                        info['auctionPricePer'] = nil
                        info['bestPricePer'] = DCI.ItemInfo[itemID].vendorPricePer
                        info['bestPriceType'] = DCI.PRICE_TYPE_VENDOR
                    end
                    rawset(t, "auctionPricePer", info['auctionPricePer'])
                    rawset(t, "bestPricePer", info['bestPricePer'])
                    rawset(t, "bestPriceType", info['bestPriceType'])
                    return info[property]
                end
            end
        })
        if itemID ~= nil then
            rawset(t, itemID, itemInfoTable)
        else
            DCI.DebugPrint("itemID is nil in metatable function", DCI.DEBUG_OUTPUT_WARNING)
        end
        return itemInfoTable
    end
})

--func to dump table to string, for debugging
function DCI.dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. DCI.dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

--function for debug output
function DCI.DebugPrint(message, outputType)
    --param: outputType, default to info
    if outputType == nil then outputType = DCI.DEBUG_OUTPUT_INFO end

    --quit if below threshold setting
    if outputType ~= DCI.DEBUG_OUTPUT_FORCED and (DCI_DB.DebugOutput == nil or outputType < DCI_DB.DebugOutput) then
        return false
    end

    message = DCI.dump(message)

    local colorCode
    if outputType == DCI.DEBUG_OUTPUT_ERROR then colorCode = "|cffff1111"
    elseif outputType == DCI.DEBUG_OUTPUT_WARNING then colorCode = "|cffffff00"
    elseif outputType == DCI.DEBUG_OUTPUT_INFO then colorCode = "|cffaaaaaa"
    else colorCode = "|cffffffff" --DCI.DEBUG_OUTPUT_FORCED
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff7f7fff" .. "[" .. DCI.ADDON_TITLE .. "] " .. colorCode .. message .. "|r")
end

-- Focused visibility diagnostics, separate from the verbose item/price debug output.
function DCI.TraceWindow(reason, force)
    if not force and not DCI.WindowDebug and not DCI_DB.DebugOutput then return end
    local function flag(value) return value and "yes" or "no" end
    DCI.DebugPrint(string.format(
        "[window %.2f] %s | shown=%s visible=%s context=%s lootShown=%s lootOpen=%s slots=%d free=%d combat=%s allowCombat=%s autoLoot=%s wait=%s interface=%d inventoryOpen=%s combinedShown=%s autoInventory=%s dismissed=%s bagCallbacks=%d",
        GetTime(), reason, flag(DCIFrame and DCIFrame:IsShown()), flag(DCIFrame and DCIFrame:IsVisible()),
        windowContextNames[DCI.windowContext] or "unset", flag(LootFrame and LootFrame:IsShown()),
        tostring(DCI.LootOpen), GetNumLootItems(), DCI.CountFreeBagSlots(), flag(UnitAffectingCombat("player")),
        flag(DCI_DB.AllowInCombat), flag(DCI_DB.Auto_Loot), flag(DCI.InvErrWaitForLootFrame), interfaceVersion,
        flag(IsInventoryOpen()), flag(ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown()),
        flag(DCI_DB.Auto_Inventory), flag(inventoryWindowDismissed), DCI.InventoryFrameCallbacks or 0),
        DCI.DEBUG_OUTPUT_FORCED)
end

function DCI.HideWindow(reason)
    DCI.HideReason = reason
    DCIFrame:Hide()
    DCI.HideReason = nil
end

function DCI.TryShowLootWindow(reason)
    if not DCI_DB.Auto_Loot and not DCI_DB.Auto_LowSlots then
        DCI.TraceWindow(reason .. ": automatic looting disabled")
        return
    end
    if not DCI.InvErrWaitForLootFrame and not DCIFrame:IsShown() and not ShouldOpenForLowSlots() then
        DCI.TraceWindow(reason .. ": no pending inventory error")
        return
    end
    if lootWindowDismissed and not DCIFrame:IsShown() then return end
    if not IsLootFrameOpen() then
        DCI.TraceWindow(reason .. ": waiting for loot frame")
        return
    end
    DCI.TraceWindow(reason .. ": updating loot window")
    DCI.UpdateDCIFrame()
end

function DCI.QueueLootUpdate(reason)
    if pendingLootUpdate then return end
    local request = {}
    pendingLootUpdate = request
    -- Let Blizzard finish handling the event and positioning its loot frame.
    C_Timer.After(0, function()
        if pendingLootUpdate ~= request then return end
        pendingLootUpdate = nil
        DCI.TryShowLootWindow(reason .. " (deferred)")
    end)
end

function DCI.HookLootFrame()
    if not LootFrame or LootFrame.DCIVisibilityHooked then return end
    LootFrame.DCIVisibilityHooked = true
    LootFrame:HookScript("OnShow", function()
        DCI.TraceWindow("LootFrame shown")
        if (DCI_DB.Auto_Loot and (DCI.InvErrWaitForLootFrame or DCIFrame:IsShown()))
            or DCI_DB.Auto_LowSlots then
            DCI.QueueLootUpdate("LootFrame shown")
        end
    end)
    LootFrame:HookScript("OnHide", function() DCI.TraceWindow("LootFrame hidden") end)
end

function DCI.HandleSlashCommand(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "" then
        DCI.TraceWindow("/dci toggle")
        DCI.ToggleDCIFrame()
    elseif command == "status" then
        DCI.TraceWindow("status; last change=" .. (DCI.LastWindowChange or "none"), true)
    elseif command == "debug" or command == "debug on" or command == "debug off" then
        if command == "debug" then DCI.WindowDebug = not DCI.WindowDebug
        else DCI.WindowDebug = command == "debug on" end
        DCI.RegisterFrameEvents()
        DCI.DebugPrint("Window debug " .. (DCI.WindowDebug and "ON. Reproduce the problem; /dci debug off stops tracing." or "OFF."), DCI.DEBUG_OUTPUT_FORCED)
        if DCI.WindowDebug then DCI.TraceWindow("debug enabled", true) end
    else
        DCI.DebugPrint("Commands: /dci, /dci debug [on|off], /dci status", DCI.DEBUG_OUTPUT_FORCED)
    end
end

--function to format and truncate money string
function DCI.GetMoneyStringTruncated(coppers, truncateCoppersAfter, truncateSilversAfter)
    --param: truncateCoppersAfter - after this amount, round down to 100s
    truncateCoppersAfter = truncateCoppersAfter or 10000
    --param: truncateSilverAfter - after this amount, round down to 10000s
    truncateSilversAfter = truncateSilversAfter or 10000000

    local truncatedCoppers    
    if coppers > truncateSilversAfter then
        truncatedCoppers = math.floor(coppers / 10000) * 10000
    elseif coppers > truncateCoppersAfter then
        truncatedCoppers = math.floor(coppers / 100) * 100
    else
        truncatedCoppers = coppers
    end

    return GetMoneyString(truncatedCoppers)
end

--function to check if auction prices are enabled and available
function DCI.UseAuctionPrices(forceEnabled)
    --param: forceEnabled (boolean) - if true, overrides user setting UseAuctionPrices
    if forceEnabled == nil then forceEnabled = false end

    --quit if error was found
    if DCI_AuctionSource == ERROR_CAPS then return false end

    --only check APIs if the setting is on (or forced) and we haven't already
    if (DCI_DB.UseAuctionPrices or forceEnabled) and (not DCI_AuctionSource) then
        --check for all supported APIs
        if (Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID) then
            DCI_AuctionSource = "Auctionator"
        elseif (AuctionLite and AuctionLite.GetAuctionValue) then
            DCI_AuctionSource = "AuctionLite"
        elseif (AucAdvanced and AucAdvanced.API and AucAdvanced.API.GetMarketValue and AucAdvanced.GetFaction) then
            DCI_AuctionSource = "Auctioneer"
        elseif (vendor and vendor.Statistic) then
            DCI_AuctionSource = "AuctionMaster"
        elseif (TSM_API and TSM_API.GetCustomPriceValue) then
            DCI_AuctionSource = "TSM"
        else
            --if no source API was found return false
            DCI.DebugPrint("No auction API was found during global check", DCI_DB.UseAuctionPrices and DCI.DEBUG_OUTPUT_WARNING or DCI.DEBUG_OUTPUT_INFO)
            DCI_AuctionSource = ERROR_CAPS 
            return false
        end
        DCI.DebugPrint("Auction API was found: " .. DCI_AuctionSource)
    end

    --if we made it this far (api exists), then go by the global user setting
    return (DCI_DB.UseAuctionPrices or forceEnabled) 
end

--function to save an item to the ignore list
function DCI.SaveIgnoredItem(itemID)
    if not DCI_DB.IgnoredItems then DCI_DB.IgnoredItems = {} end

    local IgnoredItems_copy = DCI_DB.IgnoredItems
    table.insert(IgnoredItems_copy, itemID)
    DCI_DB.IgnoredItems = IgnoredItems_copy

    DCI.DebugPrint(L["Ignoring item: "]..DCI.ItemInfo[itemID].name, DCI.DEBUG_OUTPUT_FORCED)
end

--function to clear the ignore list
function DCI.ResetIgnoredItem()
    DCI.DebugPrint(L["Resetting ignored items list."], DCI.DEBUG_OUTPUT_FORCED)

    DCI_DB.IgnoredItems = {}
    DCI.UpdateDCIFrame(false)
end

--function to check if an itemID is in the saved variable ignored list
function DCI.IsItemIgnored(itemID)
    --check if ignored list exists
    if not DCI_DB.IgnoredItems then
        return false
    end

    -- Check if the itemID is in the list
    for _, storedItemID in ipairs(DCI_DB.IgnoredItems) do
        if storedItemID == itemID then
            return true  -- ItemID found in the list
        end
    end

    return false  -- ItemID not found in the list
end

--function to get auction price by itemID
function DCI.GetAuctionPriceByItemID(itemID, itemLink)
    --quit if global auction prices disabled
    if DCI.UseAuctionPrices() == false then return nil end

    local finalAuctionPrice = nil

    --try to get price from different auction addons -- start with those that use itemID
    if (Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID) then
        --Auctionator
        finalAuctionPrice = Auctionator.API.v1.GetAuctionPriceByItemID(addonName, itemID)

    elseif (AuctionLite and AuctionLite.GetAuctionValue) then
        --AuctionLite
        finalAuctionPrice = AuctionLite:GetAuctionValue(itemID)

    --otherwise try APIs that use itemLink
    else
        itemLink = itemLink or DCI.ItemInfo[itemID].link

        if (AucAdvanced and AucAdvanced.API and AucAdvanced.API.GetMarketValue and AucAdvanced.GetFaction) then
            --Auctioneer
            finalAuctionPrice, _ = AucAdvanced.API.GetMarketValue(itemLink, AucAdvanced.GetFaction())

        elseif (vendor and vendor.Statistic) then
            --AuctionMaster
            _, finalAuctionPrice, _, _ = vendor.Statistic:GetCurrentAuctionInfo(itemLink, false)

        elseif (TSM_API and TSM_API.GetCustomPriceValue) then
            --TSM
            local itemString = TSM_API.ToItemString(itemLink);
            finalAuctionPrice = TSM_API.GetCustomPriceValue("Dbminbuyout", itemString);

        else
            --no auction API found
            DCI.DebugPrint("Auction setting is on but no auction API was found during lookup for " .. itemLink, DCI.DEBUG_OUTPUT_WARNING)
            return nil
        end
    end

    --subtract 5% auction cut
    if DCI_DB.SubtractAuctionCut and finalAuctionPrice then
        finalAuctionPrice = finalAuctionPrice * 0.95
    end

    return finalAuctionPrice
end

--function to get the items from the open quest reward window
function DCI.GetQuestRewardWindowItems()
    DCI.DebugPrint("Getting quest reward items")
    local questWindowItems = {}
    local numQuestChoices = GetNumQuestChoices()
    local numQuestRewards = GetNumQuestRewards()

    --loop optional reward choices
    for i = 1, numQuestChoices do
        questWindowItems[i] = {}
        local name, icon, quantity, quality, usable, itemID = GetQuestItemInfo("choice", i)
        questWindowItems[i].name, questWindowItems[i].quantity = name, quantity
        questWindowItems[i].itemID = itemID
        local itemLink = GetQuestItemLink("choice", i)
        questWindowItems[i].link = itemLink
        if itemLink then
            questWindowItems[i].itemID = tonumber(string.match(itemLink, "item:(%d+):"))
        end
        questWindowItems[i].isQuestChoice = true
    end

    --loop forced rewards
    for i = 1, numQuestRewards do
        questWindowItems[numQuestChoices+i] = {}
        local name, icon, quantity, quality, usable, itemID = GetQuestItemInfo("reward", i)
        questWindowItems[numQuestChoices+i].name, questWindowItems[numQuestChoices+i].quantity = name, quantity
        questWindowItems[numQuestChoices+i].itemID = itemID
        local itemLink = GetQuestItemLink("reward", i)
        questWindowItems[numQuestChoices+i].link = itemLink
        if itemLink then
            questWindowItems[numQuestChoices+i].itemID = tonumber(string.match(itemLink, "item:(%d+):"))
        end
        questWindowItems[numQuestChoices+i].isQuestChoice = false
    end

    --gather info for all items
    DCI.DebugPrint("Getting info for quest items:")
    DCI.DebugPrint(questWindowItems)
    for i = 1, #questWindowItems do
        local itemID = questWindowItems[i].itemID
    
        questWindowItems[i].isQuestItem = false
        questWindowItems[i].name = DCI.ItemInfo[itemID].name or questWindowItems[i].name or RETRIEVING_ITEM_INFO
        questWindowItems[i].link = DCI.ItemInfo[itemID].link or questWindowItems[i].link or questWindowItems[i].name
        questWindowItems[i].quality = DCI.ItemInfo[itemID].quality or 1
        questWindowItems[i].quantity = questWindowItems[i].quantity or 1

        questWindowItems[i].vendorPricePer = DCI.ItemInfo[itemID].vendorPricePer
        if questWindowItems[i].vendorPricePer then
            questWindowItems[i].vendorPriceTotal = questWindowItems[i].quantity * questWindowItems[i].vendorPricePer
        else
            questWindowItems[i].vendorPriceTotal = nil
        end
        questWindowItems[i].bestPricePer = questWindowItems[i].vendorPricePer
        questWindowItems[i].bestPriceType = DCI.PRICE_TYPE_VENDOR

        --get auction prices
        --if using auction prices
        --  and item is not nil
        --  and comparing by auction or highest price
        --  and not grey - based on setting
        if DCI.UseAuctionPrices()
            and itemID ~= nil
            and DCI_DB.CompareByPrice ~= DCI.PRICE_TYPE_VENDOR
            and (DCI_DB.AuctionPriceHidePoorQuality == false or questWindowItems[i].quality ~= 0) then

            -- auction enabled, get auction price info            
            questWindowItems[i].auctionPricePer = DCI.ItemInfo[itemID].auctionPricePer

            if questWindowItems[i].auctionPricePer then
                --auction enabled and price found
                questWindowItems[i].auctionPriceTotal = questWindowItems[i].quantity * questWindowItems[i].auctionPricePer
                questWindowItems[i].bestPricePer = DCI.ItemInfo[itemID].bestPricePer
                questWindowItems[i].bestPriceType = DCI.ItemInfo[itemID].bestPriceType
            else
                --auction enabled but no price found
                questWindowItems[i].auctionPriceTotal = nil
            end
        else
            --auction disabled
            questWindowItems[i].auctionPricePer = nil
            questWindowItems[i].auctionPriceTotal = nil            
        end
        if questWindowItems[i].bestPricePer then
            questWindowItems[i].bestPriceTotal = questWindowItems[i].quantity * questWindowItems[i].bestPricePer
        else
            questWindowItems[i].bestPriceTotal = nil
        end
    end

    return questWindowItems
end

--function to get the items from the open loot window, sorted by value
function DCI.GetSortedLootWindowItems()
    DCI.DebugPrint("Getting sorted loot items")
    local lootWindowItems = {}
    local itemNum = 0
    for i = 1, GetNumLootItems() do
        --check if item exists
        if LootSlotHasItem(i) then
            --check if its an actual item (not currency)
            if GetLootSlotType(i) == 1 then
                --check if its a quest item
                local lootIcon, lootName, lootSlotQuantity, currencyID, lootQuality, locked, lootSlotIsQuestItem = GetLootSlotInfo(i)
                if not lootSlotIsQuestItem then
                    --try to get item link
                    local lootSlotLink = GetLootSlotLink(i)
                    if lootSlotLink then
                        --now we can get the item info
                        local newLootWindowItem = {}
                        newLootWindowItem.lootIndex = i
                        newLootWindowItem.quantity = lootSlotQuantity or 1
                        newLootWindowItem.isQuestItem = lootSlotIsQuestItem or false

                        local itemID = tonumber(string.match(lootSlotLink, "item:(%d+):"))
                        newLootWindowItem.itemID = itemID
                        newLootWindowItem.link = lootSlotLink
                        newLootWindowItem.name = DCI.ItemInfo[itemID].name or lootName or RETRIEVING_ITEM_INFO
                        newLootWindowItem.quality = DCI.ItemInfo[itemID].quality
                        newLootWindowItem.vendorPricePer = DCI.ItemInfo[itemID].vendorPricePer or 0
                        newLootWindowItem.vendorPriceTotal = newLootWindowItem.quantity * newLootWindowItem.vendorPricePer
                        newLootWindowItem.bestPricePer = newLootWindowItem.vendorPricePer
                        newLootWindowItem.bestPriceType = DCI.PRICE_TYPE_VENDOR

                        --if using auction prices is enabled
                        --  and item exists
                        --  and comparing by auction or highest price (not vendor)
                        --  and not grey - based on setting 
                        if DCI.UseAuctionPrices()
                            and itemID ~= nil
                            and DCI_DB.CompareByPrice ~= DCI.PRICE_TYPE_VENDOR
                            and (DCI_DB.AuctionPriceHidePoorQuality == false or newLootWindowItem.quality ~= 0) then

                            -- auction enabled, get auction price info
                            newLootWindowItem.auctionPricePer = DCI.ItemInfo[itemID].auctionPricePer
                            
                            if newLootWindowItem.auctionPricePer then
                                --auction enabled and price found
                                newLootWindowItem.auctionPriceTotal = newLootWindowItem.quantity * newLootWindowItem.auctionPricePer
                                newLootWindowItem.bestPricePer = DCI.ItemInfo[itemID].bestPricePer
                                newLootWindowItem.bestPriceType = DCI.ItemInfo[itemID].bestPriceType
                            else
                                --auction enabled but no price found
                                newLootWindowItem.auctionPriceTotal = nil
                            end
                        else
                            --auction disabled
                            newLootWindowItem.auctionPricePer = nil
                            newLootWindowItem.auctionPriceTotal = nil
                        end
                        if newLootWindowItem.bestPricePer then
                            newLootWindowItem.bestPriceTotal = newLootWindowItem.quantity * newLootWindowItem.bestPricePer
                        else
                            newLootWindowItem.bestPriceTotal = nil
                        end

                        --set sort price
                        if DCI_DB.CompareByPrice == DCI.PRICE_TYPE_BEST and DCI.UseAuctionPrices() then
                            newLootWindowItem.sortPrice = newLootWindowItem.bestPriceTotal or newLootWindowItem.vendorPriceTotal or 0
                        elseif DCI_DB.CompareByPrice == DCI.PRICE_TYPE_AUCTION and DCI.UseAuctionPrices() then
                            newLootWindowItem.sortPrice = newLootWindowItem.auctionPriceTotal or newLootWindowItem.vendorPriceTotal or 0
                        else
                            newLootWindowItem.sortPrice = newLootWindowItem.vendorPriceTotal or 0
                        end        

                        --add it to array
                        itemNum = itemNum + 1
                        lootWindowItems[itemNum] = newLootWindowItem
                    end
                end
            end
        end
    end

    table.sort(lootWindowItems, function(item1, item2) 
        --if either item null, just quit
        if (item1 == nil or item2 == nil) then
            return item2 == nil
        end
        
        --sort quest items to the top
        if item1.isQuestItem then
            return true
        elseif item2.isQuestItem then
            return false
        end

        --finally use sortprice
        return item1.sortPrice > item2.sortPrice
    end)

    DCI.DebugPrint(lootWindowItems)

    return lootWindowItems
end

--function to get all items in bags and sort by price
function DCI.GetSortedBagItems()
    DCI.DebugPrint("Getting sorted bag items")
    --Create item array
	local bagItems = {}
    local bagItemCount = 0

    -- Iterate through all bags
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS) do
        -- Get the number of slots in the bag
        local numSlots = C_Container.GetContainerNumSlots(bag)

        -- Iterate through all slots in the bag
        for slot = 1, numSlots do
            -- Get information about the item in the slot
            -- iconFileID, stackCount, isLocked, quality, isReadable, hasLoot, hyperlink, isFiltered, hasNoValue, itemID, isBound
            local containerItemInfo = C_Container.GetContainerItemInfo(bag, slot)

            if containerItemInfo and containerItemInfo.itemID and containerItemInfo.itemID ~= 6948
                and not containerItemInfo.isLocked then -- exclude locked items and the hearthstone
                --store container info / rename params
                local newBagItem = {}
                local itemID = containerItemInfo.itemID
                newBagItem.itemID = itemID
                newBagItem.link = containerItemInfo.hyperlink or DCI.ItemInfo[itemID].link
                newBagItem.quantity = containerItemInfo.stackCount or 1
                newBagItem.quality = containerItemInfo.quality or DCI.ItemInfo[itemID].quality
                newBagItem.isSoulbound = containerItemInfo.isBound

                --get initial info for filtering
                local ItemQuestInfo = C_Container.GetContainerItemQuestInfo(bag, slot)
                newBagItem.isQuestItem = ItemQuestInfo and (ItemQuestInfo.isQuestItem or ItemQuestInfo.questID ~= nil)
                if newBagItem.isSoulbound == nil then newBagItem.isSoulbound = C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(bag, slot)) or false end
                newBagItem.quality = newBagItem.quality or DCI.ItemInfo[itemID].quality

                --skip: ignored items
                --  and quest items 
                --  and soulbound items (if HideSoulbound)
                --  and items with quality above threshold
                if (DCI.ItemInfo[itemID].name and DCI.ItemInfo[itemID].vendorPricePer ~= nil
                    and newBagItem.quality ~= nil
                    and not DCI.IsItemIgnored(itemID)
                    and not newBagItem.isQuestItem
                    and (not newBagItem.isSoulbound or not DCI_DB.HideSoulbound)
                    and newBagItem.quality <= DCI_DB.MaxQuality) then
    	            -- Append info
    	            newBagItem.bag = bag
    	            newBagItem.slot = slot
                    newBagItem.name = DCI.ItemInfo[itemID].name
    	            newBagItem.vendorPricePer = DCI.ItemInfo[itemID].vendorPricePer or 0
    	            newBagItem.vendorPriceTotal = newBagItem.quantity * newBagItem.vendorPricePer
                    newBagItem.bestPricePer = newBagItem.vendorPricePer
                    newBagItem.bestPriceType = DCI.PRICE_TYPE_VENDOR

                    --if flag to use auction is set
                    --  and the item is not soulbound
                    --  and not grey, based on setting
                    if DCI.UseAuctionPrices() and not newBagItem.isSoulbound 
                        and (DCI_DB.AuctionPriceHidePoorQuality == false or newBagItem.quality ~= 0) then

                        -- auction enabled, get auction price info
                        newBagItem.auctionPricePer = DCI.ItemInfo[itemID].auctionPricePer

                        if newBagItem.auctionPricePer then
                            --auction enabled and price found
                            newBagItem.auctionPriceTotal = newBagItem.quantity * newBagItem.auctionPricePer
                            newBagItem.bestPricePer = DCI.ItemInfo[itemID].bestPricePer
                            newBagItem.bestPriceType = DCI.ItemInfo[itemID].bestPriceType
                        else
                            --auction enabled but no price found
                            newBagItem.auctionPriceTotal = nil
                        end
                    else
                        --auction disabled
                        newBagItem.auctionPricePer = nil
                        newBagItem.auctionPriceTotal = nil
                    end
                    newBagItem.bestPriceTotal = newBagItem.quantity * newBagItem.bestPricePer

                    --set sort price
                    if DCI_DB.CompareByPrice == DCI.PRICE_TYPE_BEST and DCI.UseAuctionPrices() then
                        newBagItem.sortPrice = newBagItem.bestPriceTotal or newBagItem.vendorPriceTotal or 0
                    elseif DCI_DB.CompareByPrice == DCI.PRICE_TYPE_AUCTION and DCI.UseAuctionPrices() then
                        newBagItem.sortPrice = newBagItem.auctionPriceTotal or newBagItem.vendorPriceTotal or 0
                    else
                        newBagItem.sortPrice = newBagItem.vendorPriceTotal or 0
                    end       

    	            -- add it to array
    				bagItemCount = bagItemCount + 1
    	            bagItems[bagItemCount] = newBagItem
                end
		    end
        end
    end

    --sort by price
    table.sort(bagItems, function(item1, item2) 
        --if either item is null quit
        if (item1 == nil or item2 == nil) then
            return item1 == nil
        end

        --if the values are equal sort by itemID to keep same items together
        if item1.sortPrice == item2.sortPrice then return item1.itemID < item2.itemID end

        --finally use sortprice
        return item1.sortPrice < item2.sortPrice
    end)

    --pass to remove duplicates
    local lastItemID, lastItemQty = nil, nil
    local bagItemsDeduped = {}
    local bagItemsDedupedCount = 0
    for i = 1,#bagItems do
        if bagItems[i].itemID ~= lastItemID or bagItems[i].quantity ~= lastItemQty then
            bagItemsDedupedCount = bagItemsDedupedCount + 1
            bagItemsDeduped[bagItemsDedupedCount] = bagItems[i]
        end
        lastItemID = bagItems[i].itemID
        lastItemQty = bagItems[i].quantity
    end

    return bagItemsDeduped
end

--function to count free bag slots
function DCI.CountFreeBagSlots()
    local freeSlots = 0
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS) do
        local count, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        -- Specialty bags cannot receive arbitrary loot.
        if bagFamily == 0 then
            freeSlots = freeSlots + count
        end
    end

    DCI.DebugPrint("Free bag slots: " .. freeSlots)

    return freeSlots
end

--function to loot items in the open loot window, used after making space in bags
function DCI.TakeItemsFromLootWindow(forcedFirstLootIndex)
    DCI.DebugPrint("Looting next item in window")
    --get quest items & cash first
    local lootSlotType = {}
    for i = 1, GetNumLootItems() do
        if LootSlotHasItem(i) then
            local _,_,_,_,_,_,isQuestItem = GetLootSlotInfo(i)
            lootSlotType[i] = GetLootSlotType(i)
            if isQuestItem or lootSlotType[i] > 1 then
                LootSlot(i)
            end
        end
    end

    --forcedFirstLootIndex
    if forcedFirstLootIndex then
        DCI.DebugPrint("Using forced loot index")
        LootSlot(forcedFirstLootIndex)
    end

    --loot in order of value
    local lootItems = DCI.GetSortedLootWindowItems()
    for i,nextLootItem in ipairs(lootItems) do
        if forcedFirstLootIndex == nil or nextLootItem.lootIndex ~= forcedFirstLootIndex then --skip the forced one we aready did
            LootSlot(nextLootItem.lootIndex)
        end
    end
end

-- Recheck the displayed stack before a destructive action, including popup acceptance.
function DCI.GetActionableBagItem(bag, slot, expected)
    if GetCursorInfo() ~= nil then return nil end
    local item = C_Container.GetContainerItemInfo(bag, slot)
    if not item or not item.itemID or item.isLocked or not item.hyperlink then return nil end
    if expected and (item.itemID ~= expected.itemID
        or item.hyperlink ~= (expected.hyperlink or expected.link)
        or item.stackCount ~= (expected.stackCount or expected.quantity)) then return nil end
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
    local bound = item.isBound
    if bound == nil then bound = C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(bag, slot)) end
    local quality = item.quality or DCI.ItemInfo[item.itemID].quality
    if item.itemID == 6948 or DCI.IsItemIgnored(item.itemID)
        or (quest and (quest.isQuestItem or quest.questID ~= nil))
        or (DCI_DB.HideSoulbound and bound)
        or not quality or quality > DCI_DB.MaxQuality then return nil end
    return item, quality
end

function DCI.SellBagItem(bag, slot, expected)
    if not MerchantFrame or not MerchantFrame:IsShown() then return false end
    if not DCI.GetActionableBagItem(bag, slot, expected) then return false end
    C_Container.UseContainerItem(bag, slot)
    return true
end

function DCI.ConfirmAndDeleteBagItem(bag, slot, expected, onDeleted)
    local item, quality = DCI.GetActionableBagItem(bag, slot, expected)
    if not item then return false end
    local snapshot = { itemID = item.itemID, hyperlink = item.hyperlink, stackCount = item.stackCount }
    local itemText = item.hyperlink:match("|h%[(.-)%]|h") or item.hyperlink

    local function DeleteBagItemForReal()
        if not DCI.GetActionableBagItem(bag, slot, snapshot) then return false end
        C_Container.PickupContainerItem(bag, slot)
        local cursorType, cursorItemID = GetCursorInfo()
        if cursorType ~= "item" or cursorItemID ~= snapshot.itemID then
            ClearCursor()
            return false
        end
        DeleteCursorItem()
        if GetCursorInfo() ~= nil then
            ClearCursor()
            return false
        end
        DCI.DebugPrint(L["Deleting item: "] .. itemText, DCI.DEBUG_OUTPUT_FORCED)
        if onDeleted then onDeleted() end
        return true
    end

    if DCI_DB.ConfirmMinQuality and quality >= DCI_DB.ConfirmMinQuality then
        StaticPopupDialogs["DCI_RELOADED_DELETE_ITEM"] = {
            text = DELETE_ITEM .. "\n\n%s\n\n",
            button1 = YES,
            button2 = NO,
            OnAccept = function(_, data) data() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            showAlert = true,
        }
        StaticPopup_Show("DCI_RELOADED_DELETE_ITEM", itemText, item.hyperlink, DeleteBagItemForReal)
        return false
    end
    return DeleteBagItemForReal()
end

function DCI.OpenSettings()
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    elseif DCI.settingsCategory then
        Settings.OpenToCategory(DCI.settingsCategory:GetID())
    end
end

function DCI.UpdateWindowTheme()
    if not isForever or not DCIFrame then return end
    if DCI_DB.HideBronzeTheme then
        if not DCIFrame.RegularTheme then
            -- Use the same panel artwork as the addon's regular client theme.
            local regularTheme = CreateFrame("Frame", nil, DCIFrame, "BasicFrameTemplate")
            regularTheme:SetAllPoints(DCIFrame)
            regularTheme:SetFrameLevel(DCIFrame:GetFrameLevel())
            regularTheme.CloseButton:Hide()
            DCIFrame.RegularTheme = regularTheme
        end
        DCIFrame.NineSlice:Hide()
        DCIFrame.Bg:Hide()
        DCIFrame.RegularTheme:Show()
    else
        DCIFrame.NineSlice:Show()
        DCIFrame.Bg:Show()
        if DCIFrame.RegularTheme then DCIFrame.RegularTheme:Hide() end
    end
end

local function CreateMainFrame()
    -- This is the base used by Forever's native loot panel, including its bronze art.
    local template = isForever and "DefaultPanelFlatTemplate" or "BasicFrameTemplate"
    local frame = CreateFrame("Frame", "DCIFrame", UIParent, template)
    if isForever then
        -- Unlike BasicFrameTemplate, the flat panel does not include a close button.
        frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")
        DCI.UpdateWindowTheme()
    end
    frame:HookScript("OnShow", function()
        DCI.LastWindowChange = "shown"
        DCI.TraceWindow("shown")
    end)
    frame:HookScript("OnHide", function()
        local reason = DCI.HideReason or "close button or external hide"
        DCI.LastWindowChange = "hidden: " .. reason
        DCI.TraceWindow(DCI.LastWindowChange)
        if not DCI.HideReason then
            -- A user dismissal must cancel any queued automatic reopening.
            DCI.InvErrWaitForLootFrame = false
            pendingLootUpdate = nil
            pendingBagVisibilityUpdate = nil
            bagWindowAutoOpened = false
            if DCI_DB.Auto_Inventory and IsInventoryOpen() then inventoryWindowDismissed = true end
            if DCI.windowContext == WINDOW_CONTEXT_LOOT then lootWindowDismissed = true end
        end
    end)
    return frame
end

--function to create and show a frame with cheapest items
function DCI.CreateDCIFrame()
    -- Create a frame
    DCI.DebugPrint("Creating DCI Frame elements")
    if DCIFrame == nil then
        CreateMainFrame()
    end
    DCIFrame:SetSize(290, 240)
    DCIFrame:SetFrameStrata("HIGH")

    -- if loot frame is open, anchor to it
    DCIFrame:ClearAllPoints()
    if LootFrame and LootFrame:IsShown() then
        DCIFrame:SetPoint("LEFT", LootFrame, "RIGHT", 10, 0) 
    elseif LootFrame and LootFrame.numLootItems then
        --LootFrame is hidden, but has been used and we can anchor to it
        DCIFrame:SetPoint("LEFT", LootFrame, "LEFT", 0, 0)
    else
        DCIFrame:SetPoint("LEFT", 10, 0) 
    end

    --secondary tooltip for button hover
    local DCI_SecondTooltip = CreateFrame("GameTooltip", "DCI_SecondTooltip", DCIFrame, "GameTooltipTemplate")
    DCI_SecondTooltip:Hide()

    -- Keep the title and its controls above Forever's native NineSlice border.
    local titleParent = DCIFrame
    if isForever then
        titleParent = DCIFrame.TitleContainer
        titleParent.TitleText:Hide()
    end

    --title bar text
    local DCI_TitleText = titleParent:CreateFontString("DCI_TitleText", "OVERLAY", "GameFontNormal")
    DCI_TitleText:SetPoint("TOPLEFT", DCIFrame, "TOPLEFT", 0, 0)
    DCI_TitleText:SetPoint("BOTTOMRIGHT", DCIFrame, "TOPRIGHT", isForever and -50 or -25, -24)
    DCI_TitleText:SetText(DCI.ADDON_TITLE)

    --drag frame
    local DCI_DragFrame = CreateFrame("Frame", "DCI_DragFrame", titleParent)
    DCI_DragFrame:SetPoint("TOPLEFT", DCI_TitleText, "TOPLEFT", 0, 0)
    DCI_DragFrame:SetPoint("BOTTOMRIGHT", DCI_TitleText, "BOTTOMRIGHT", -20, 0)

    --title bar mouse drag handlers
    DCIFrame:SetMovable(true)
    DCI_DragFrame:HookScript("OnMouseDown", function(self, button)
        DCI.DebugPrint("Mousedown on drag frame")
        if button == "LeftButton" then
            DCIFrame:StartMoving()
            DCI.WindowMoved  = true
        end
    end)

    DCI_DragFrame:HookScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            DCIFrame:StopMovingOrSizing()
        end
    end)

    --title bar info button
    local DCI_TitleInfoButton = CreateFrame("Button", "DCI_TitleInfoButton", titleParent, "UIPanelInfoButton")
    if isForever then
        DCI_TitleInfoButton:SetPoint("TOPRIGHT", DCIFrame.CloseButton, "TOPLEFT", 0, -3)
    else
        DCI_TitleInfoButton:SetPoint("TOPRIGHT", DCIFrame, "TOPRIGHT", -21, -3)
    end
    DCI_TitleInfoButton:SetSize(23, 23)

    --title bar info button tooltip
    DCI_TitleInfoButton:HookScript("OnEnter", function()
        GameTooltip:SetOwner(DCIFrame, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", DCIFrame, "TOPLEFT", -2, -20) 

        GameTooltip:AddDoubleLine(L["Settings (Click Icon to Change)"], "v" .. DCI.ADDON_VERSION, 1, 1, 1, 0.1, 0.1, 0.1)

        GameTooltip:AddLine(" ")

        local qualityOptions = {ITEM_QUALITY1_DESC, ITEM_QUALITY2_DESC, ITEM_QUALITY3_DESC, ITEM_QUALITY4_DESC, ITEM_QUALITY5_DESC} qualityOptions[0] = ITEM_QUALITY0_DESC
        local confirmQuality = DCI_DB.ConfirmMinQuality and qualityOptions[DCI_DB.ConfirmMinQuality] or NEVER
        local r,g,b,hex = C_Item.GetItemQualityColor(DCI_DB.MaxQuality)
        GameTooltip:AddDoubleLine(L["Max item quality to display"], qualityOptions[DCI_DB.MaxQuality], 1.0, 0.82, 0.0, r, g, b)

        if DCI_DB.ConfirmMinQuality and DCI_DB.MaxQuality >= DCI_DB.ConfirmMinQuality then
            r,g,b,hex = C_Item.GetItemQualityColor(DCI_DB.ConfirmMinQuality)
            GameTooltip:AddDoubleLine(L["Confirm delete if quality is at least"], confirmQuality, 1.0, 0.82, 0.0, r, g, b)
        else
            GameTooltip:AddDoubleLine(L["Confirm delete"], NEVER, 1.0, 0.82, 0.0, 0.9, 0.9, 0.9)
        end

        local AuctionSourceText = ""
        if DCI.UseAuctionPrices() then
            AuctionSourceText = DCI_AuctionSource or NO
        else
            AuctionSourceText = NO
        end
        GameTooltip:AddDoubleLine(L["Use auction prices"] .. (DCI.UseAuctionPrices() and (" "..L["from"]) or ""), AuctionSourceText, 1.0, 0.82, 0.0, 0.9, 0.9, 0.9)
        if DCI.UseAuctionPrices() then
            local compareByOptions = {L["Vendor Price"], L["Auction Price"], L["Best Price"]}
            GameTooltip:AddDoubleLine(L["Compare item values by"], compareByOptions[DCI_DB.CompareByPrice], 1.0, 0.82, 0.0, 0.9, 0.9, 0.9)
        end

        GameTooltip:AddLine(" ")

        GameTooltip:AddLine(L["Tips"], 0.6, 0.6, 0.6)
        GameTooltip:AddLine("* " .. L["Click on an item's icon to add it to the ignore list"], 0.6, 0.6, 0.6)
        GameTooltip:AddLine("* " .. L["Type /dci to open the window at any time"], 0.6, 0.6, 0.6)
        GameTooltip:AddLine("* " .. L["Feedback and suggestions are welcome! :)"], 0.6, 0.6, 0.6)

        GameTooltip:Show()
    end)
    DCI_TitleInfoButton:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    --title bar info button click event
    DCI_TitleInfoButton:HookScript("OnMouseUp", DCI.OpenSettings)

    --top section text 1
    local DCI_TopSection_Text1 = DCIFrame:CreateFontString("DCI_TopSection_Text1", "OVERLAY", "GameFontHighlightSmall")
    DCI_TopSection_Text1:SetPoint("TOPLEFT", DCIFrame, "TOPLEFT", isForever and 12 or 8, -31)
    DCI_TopSection_Text1:SetTextColor(0.87, 0.87, 0.87)
    
    local DCI_TopSection_Text2 = DCIFrame:CreateFontString("DCI_TopSection_Text2", "OVERLAY", "GameFontDisableSmall")
    DCI_TopSection_Text2:SetPoint("TOPLEFT", DCI_TopSection_Text1, "BOTTOMLEFT", 0, -5)

    --bottom section inset
    local DCI_BottomSection_Inset = CreateFrame("ScrollFrame", "DCI_BottomSection_Inset", DCIFrame, "InsetFrameTemplate3")
    DCI_BottomSection_Inset:SetPoint("TOPLEFT", DCIFrame, "TOPLEFT", 3+1, -60)
    DCI_BottomSection_Inset:SetPoint("BOTTOMRIGHT", DCIFrame, "BOTTOMRIGHT", -5-1, 4)

    --scroll parent
    local DCI_ScrollParent = CreateFrame("ScrollFrame", "DCI_ScrollParent", DCI_BottomSection_Inset, "UIPanelScrollFrameTemplate")
    DCI_ScrollParent:SetPoint("TOPLEFT", DCI_BottomSection_Inset, "TOPLEFT", 0, -3)
    DCI_ScrollParent:SetSize(261, 171) --oversize 5 pixels horiz.
    --DCI_ScrollParent:SetPoint("BOTTOMRIGHT", DCI_BottomSection_Inset, "BOTTOMRIGHT", -19, 2)
    local s1,s2,s3,s4,s5=DCI_ScrollParentScrollBar:GetPoint(); DCI_ScrollParentScrollBar:SetPoint(s1,s2,s3,s4-5,s5) --nudge scrollbar back 5 pixels, helps content extend further to bar

    --scroll child
    local DCI_ScrollChild = CreateFrame("Frame", "DCI_ScrollChild", DCI_ScrollParent);
    DCI_ScrollChild:SetPoint("TOPLEFT", DCI_ScrollParent, "TOPLEFT", 0, 1) 
    DCI_ScrollChild:SetSize(261, 172) --DCI_ScrollChild:SetSize(265, 42*4)
    DCI_ScrollParent:SetScrollChild(DCI_ScrollChild)
    DCI_ScrollParent.ScrollBar.scrollStep = 41

    --pre-create bag item frames
    for itemNum = 1,DCI.MAX_ITEM_FRAMES do
        --item parent
        local ItemParent = CreateFrame("Frame", "DCI_Item" ..itemNum, DCI_ScrollChild)
        ItemParent:SetPoint("TOPLEFT", DCI_ScrollChild, "TOPLEFT", 3, -5 + (itemNum-1) * -41)
        ItemParent:SetSize(258, 44)
        --ItemParent:SetPoint("BOTTOMRIGHT", DCI_ScrollChild, "TOPRIGHT", 0, -5 + (itemNum-0) * -41 - 3) --height padded to fine tune scroll stop

        --item icon
        local ItemIcon = CreateFrame("Button", "DCI_ItemIcon" ..itemNum, ItemParent)
        ItemIcon:SetSize(38, 38)
        ItemIcon:SetPoint("TOPLEFT", ItemParent)
        ItemIcon:SetFrameLevel(4)
        local ItemIconTexture = ItemIcon:CreateTexture("DCI_ItemIconTexture" ..itemNum, "BACKGROUND")
        ItemIconTexture:SetAllPoints(ItemIcon)

        --show the quantity
        local ItemIconCountText = ItemIcon:CreateFontString("DCI_ItemIconCountText" ..itemNum, "OVERLAY", "NumberFontNormal")
        ItemIconCountText:SetPoint("BOTTOMRIGHT", ItemIcon, "BOTTOMRIGHT", -2, 2)

        --item info box background
        local ItemInfo_Bg = ItemParent:CreateTexture("ItemInfo_Bg", "BACKGROUND")
        ItemInfo_Bg:SetTexture(136796)
        ItemInfo_Bg:SetVertexColor(0.5, 0.5, 0.5, 1)
        ItemInfo_Bg:SetPoint("TOPLEFT", ItemIcon, "TOPRIGHT", 5, 0)
        ItemInfo_Bg:SetSize(150, 38)
        ItemInfo_Bg:SetTexCoord(0.08, 0.92, 0.18, 0.82)

        --glow texture for highlight (start out hidden)
        local GlowTexture = ItemParent:CreateTexture("DCI_ItemGlowTexture" ..itemNum, "OVERLAY")
        GlowTexture:SetTexture("Interface/Buttons/UI-ActionButton-Border")
        GlowTexture:SetBlendMode("ADD")  -- ADD blend mode for a glow effect
        GlowTexture:SetTexCoord(0.28, 0.72, 0.28, 0.72)
        GlowTexture:SetPoint("LEFT", DCI_ScrollChild, "LEFT", 3, 0)
        GlowTexture:SetPoint("RIGHT", DCI_ScrollChild, "RIGHT", -2, 0)
        GlowTexture:SetPoint("TOP", ItemIcon, "TOP", 0, 1)
        GlowTexture:SetPoint("BOTTOM", ItemIcon, "BOTTOM", 0, -1)
        GlowTexture:SetVertexColor(1, 0, 0, 0.65)  -- Adjust the alpha value to control the intensity of the glow
        GlowTexture:Hide()

        --display item name/values
        local ItemInfo_TextTopLeft = ItemParent:CreateFontString("DCI_ItemInfo_TextTopLeft"..itemNum, "OVERLAY", "GameFontNormal")
        ItemInfo_TextTopLeft:SetPoint("TOPLEFT", ItemInfo_Bg, "TOPLEFT", 7, -5)
        local ItemInfo_TextTopRight = ItemParent:CreateFontString("DCI_ItemInfo_TextTopRight"..itemNum, "OVERLAY", "GameFontNormal")
        ItemInfo_TextTopRight:SetPoint("TOPRIGHT", ItemInfo_Bg, "TOPRIGHT", -7, -5)
        ItemInfo_TextTopRight:SetText(" ") --to ensure relative positioning works
        local ItemInfo_TextBottomLeft = ItemParent:CreateFontString("DCI_ItemInfo_TextBottomLeft"..itemNum, "OVERLAY", "GameFontNormal")
        ItemInfo_TextBottomLeft:SetPoint("TOPLEFT", ItemInfo_TextTopLeft, "BOTTOMLEFT", 0, -5)
        local ItemInfo_TextBottomRight = ItemParent:CreateFontString("DCI_ItemInfo_TextBottomRight"..itemNum, "OVERLAY", "GameFontNormal")
        ItemInfo_TextBottomRight:SetPoint("TOPRIGHT", ItemInfo_TextTopRight, "BOTTOMRIGHT", 0, -5)

        --show delete button
        local DeleteButton = CreateFrame("Button", "DCI_DeleteButton" ..itemNum, ItemParent, "UIPanelButtonTemplate")
        DeleteButton:SetText(DELETE)
        DeleteButton:SetSize(60, 32)
        DeleteButton:SetPoint("LEFT", ItemInfo_Bg, "RIGHT", 3, 0)
    end

    --movable single ignore button
    local IgnoreButton = CreateFrame("Button", "DCI_IgnoreButton", DCI_ScrollChild, "UIPanelSquareButton")
    IgnoreButton:SetSize(44, 44)
    IgnoreButton:SetFrameLevel(5)
    IgnoreButton:GetHighlightTexture():SetAlpha(0)
    IgnoreButton:Hide()

    --reset clicked item index when window closes
    DCIFrame:HookScript("OnHide", function()
        if LootFrame and LootFrame.DCI_LootIndexUserClick then
            DCI.DebugPrint("Resetting click index")
            LootFrame.DCI_LootIndexUserClick = nil
        end
    end)
end

--function to update and display main window
function DCI.UpdateDCIFrame(showFrameAfterUpdate)
    --parameter: showFrameAfterUpdate - default true
    --this controls two things: Show()ing the frame at the end, and resetting the scrollbar position to top
    if showFrameAfterUpdate == nil then showFrameAfterUpdate = true end
    DCI.DebugPrint("UpdateDCIFrame " .. (showFrameAfterUpdate and "true" or "false"))

    -- initialize
    -----------------

    --prepare frame
    if DCIFrame == nil or DCI_TitleText == nil then
        --make frame if its missing
        DCI.CreateDCIFrame()
        if not showFrameAfterUpdate then DCI.HideWindow("initializing hidden window") end
    elseif showFrameAfterUpdate then
        --reset scroll
        DCI_ScrollParent:SetVerticalScroll(0);
    end

    --quit if player is in combat based on global AllowInCombat
    if DCI_DB.AllowInCombat == false and UnitAffectingCombat("player") then
        DCI.DebugPrint("Hiding since player is in combat")
        DCI.HideWindow("combat")

        -- Remember even the first opening attempt, before a loot context was assigned.
        if (DCI_DB.Auto_Loot or DCI_DB.Auto_LowSlots) and IsLootFrameOpen() then
            DCI.DebugPrint("Set wait flag to reappear when we leave combat")
            DCI.InvErrWaitForLootFrame = true
        end
        DCI.TraceWindow("show blocked by combat")
        return false
    end

    --determine window context
    if (DCI_DB.Auto_Loot or DCI_DB.Auto_LowSlots) and IsLootFrameOpen() then
        DCI.DebugPrint("Window context: Looting")
        DCI.windowContext = WINDOW_CONTEXT_LOOT
    elseif DCI_DB.Auto_QuestAccept and DCI.QuestGaveError and QuestFrameDetailPanel and QuestFrameDetailPanel:IsShown() then
        DCI.DebugPrint("Window context: Quest (accept)")
        DCI.windowContext = WINDOW_CONTEXT_QUESTACCEPT
    elseif DCI_DB.Auto_QuestComplete and QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then
        DCI.DebugPrint("Window context: Quest (complete)")
        DCI.windowContext = WINDOW_CONTEXT_QUESTCOMPLETE
    elseif DCI_DB.Auto_Trade and TradeFrame and TradeFrame:IsShown() then
        DCI.DebugPrint("Window context: Trade")
        DCI.windowContext = WINDOW_CONTEXT_TRADE
    elseif DCI_DB.Auto_Mail and ((OpenMailFrame and OpenMailFrame:IsShown()) or (MailFrame and MailFrame:IsShown())) then
        DCI.DebugPrint("Window context: Mail")
        DCI.windowContext = WINDOW_CONTEXT_MAIL
    elseif DCI_DB.Auto_Vendor and MerchantFrame and MerchantFrame:IsShown() then
        DCI.DebugPrint("Window context: Vendor")
        DCI.windowContext = WINDOW_CONTEXT_VENDOR
    elseif DCI_DB.Auto_Roll and GroupLootContainer and GroupLootContainer:IsShown() then
        DCI.DebugPrint("Window context: Need/Greed Roll")
        DCI.windowContext = WINDOW_CONTEXT_ROLL
    else
        DCI.DebugPrint("Window context: Free")
        DCI.windowContext = WINDOW_CONTEXT_FREE
    end

    -- anchor window & get loot items
    -----------------

    local lootItems = {}
    local itemIndexToLoot = nil
    if DCI.windowContext == WINDOW_CONTEXT_LOOT then
        --anchor to loot window
        DCI.DebugPrint("Anchoring to loot window")
        DCIFrame:ClearAllPoints()
        DCIFrame:SetPoint("LEFT", LootFrame, "RIGHT", 10, 0)
        DCI.WindowMoved = false
    
        --get items to be looted
        lootItems = DCI.GetSortedLootWindowItems()

        --choose item to loot
        if LootFrame and LootFrame.DCI_LootIndexUserClick and LootFrame.DCI_LootIndexUserClick <= GetNumLootItems() then
            --if the user clicked on an item in loot frame use it
            for i = 1,#lootItems do
                if lootItems[i].lootIndex == LootFrame.DCI_LootIndexUserClick then
                    itemIndexToLoot = i
                    DCI.DebugPrint("Overwriting item to loot with player choice " .. itemIndexToLoot)
                    break
                end
            end
        else
            --otherwise use the first item
            for i,nextLootItem in pairs(lootItems) do
                if nextLootItem and LootSlotHasItem(nextLootItem.lootIndex) then
                    itemIndexToLoot = i
                    break
                end
            end
        end

    elseif DCI.windowContext == WINDOW_CONTEXT_QUESTCOMPLETE or DCI.windowContext == WINDOW_CONTEXT_QUESTACCEPT then
        --anchor to quest window
        DCI.DebugPrint("Anchoring to quest window")
        DCIFrame:ClearAllPoints()
        DCIFrame:SetPoint("TOPLEFT", QuestFrame, "TOPRIGHT", -20, -20)
        DCI.WindowMoved = false

        --set hook to hide with quest frame
        if not QuestFrame.DCIHooked then
            QuestFrame:HookScript("OnHide", function(self)
                if DCI.windowContext == WINDOW_CONTEXT_QUESTACCEPT or DCI.windowContext == WINDOW_CONTEXT_QUESTCOMPLETE and DCIFrame:IsShown() then
                    DCI.DebugPrint("Hiding with quest frame")
                    DCI.HideWindow("quest frame hidden")
                end
            end)
            QuestFrame.DCIHooked = true
        end

        --get items to be looted
        if DCI.windowContext == WINDOW_CONTEXT_QUESTCOMPLETE then
            lootItems = DCI.GetQuestRewardWindowItems()
            DCI.DebugPrint("Done getting quest items")
            if QuestInfoFrame and QuestInfoFrame.itemChoice and QuestInfoFrame.itemChoice > 0
                and QuestInfoFrame.itemChoice <= GetNumQuestChoices() then
                itemIndexToLoot = QuestInfoFrame.itemChoice
            else
                itemIndexToLoot = 1
            end
        end
    elseif DCI.windowContext == WINDOW_CONTEXT_TRADE then
        --anchor to trade window
        DCI.DebugPrint("Anchoring to trade window")
        DCIFrame:ClearAllPoints()
        DCIFrame:SetPoint("TOPLEFT", TradeFrame, "TOPRIGHT", 10, 0)
        DCI.WindowMoved = false

        --set hook to hide with trade frame
        if not TradeFrame.DCIHooked then
            TradeFrame:HookScript("OnHide", function(self)
                if DCI.windowContext == WINDOW_CONTEXT_TRADE and DCIFrame:IsShown() then
                    DCI.DebugPrint("Hiding with trade frame")
                    DCI.HideWindow("trade frame hidden")
                end
            end)
            TradeFrame.DCIHooked = true
        end
    elseif DCI.windowContext == WINDOW_CONTEXT_MAIL then
        --chose between mailbox and openmail frames
        local selectedMailFrame
        if OpenMailFrame:IsShown() then
            selectedMailFrame = OpenMailFrame
        else
            selectedMailFrame = MailFrame
        end

        --anchor to mail window
        DCI.DebugPrint("Anchoring to mail window " .. selectedMailFrame:GetName())
        DCIFrame:ClearAllPoints()
        DCIFrame:SetPoint("TOPLEFT", selectedMailFrame, "TOPRIGHT", 10, 0)
        DCI.WindowMoved = false

        --set hook to hide with openmail frame
        if not selectedMailFrame.DCIHooked then
            selectedMailFrame:HookScript("OnHide", function(self)
                if DCI.windowContext == WINDOW_CONTEXT_MAIL and DCIFrame:IsShown() then
                    DCI.DebugPrint("Hiding with mail frame")
                    DCI.HideWindow("mail frame hidden")
                end
            end)
            selectedMailFrame.DCIHooked = true
        end
    elseif DCI.windowContext == WINDOW_CONTEXT_VENDOR then
        --anchor to vendor window
        DCI.DebugPrint("Anchoring to vendor window")
        DCIFrame:ClearAllPoints()
        DCIFrame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 10, 0)
        DCI.WindowMoved = false

        --set hook to hide with vendor frame
        if not MerchantFrame.DCIHooked then
            MerchantFrame:HookScript("OnHide", function(self)
                if DCI.windowContext == WINDOW_CONTEXT_VENDOR and DCIFrame:IsShown() then
                    DCI.DebugPrint("Hiding with vendor frame")
                    DCI.HideWindow("merchant frame hidden")
                end
            end)
            MerchantFrame.DCIHooked = true
        end
    elseif DCI.windowContext == WINDOW_CONTEXT_ROLL then
        --anchor to roll window
        DCI.DebugPrint("Anchoring to roll window")
        DCIFrame:ClearAllPoints()
        DCIFrame:SetPoint("BOTTOMLEFT", GroupLootFrame1, "BOTTOMRIGHT", 10, 4)
        DCI.WindowMoved = false

        --set hook to hide with roll frame
        if not GroupLootContainer.DCIHooked then
            GroupLootContainer:HookScript("OnHide", function(self)
                if DCI.windowContext == WINDOW_CONTEXT_ROLL and DCIFrame:IsShown() then
                    DCI.DebugPrint("Hiding with roll frame")
                    DCI.HideWindow("roll frame hidden")
                end
            end)
            GroupLootContainer.DCIHooked = true
        end
    else
        --anchor to screen
        DCI.DebugPrint("Anchor to screen")
        if not DCI.WindowMoved then
            DCIFrame:ClearAllPoints()
            DCIFrame:SetPoint("LEFT", 15, 188/2)
        end
    end

    --calculate number and value of rewards there will be
    local numItemsToReceive = 0
    local totalValueToReceieve = 0
    if DCI.windowContext == WINDOW_CONTEXT_LOOT then
        --player will loot 1 item with known value
        numItemsToReceive = 1

        if lootItems == nil or lootItems[itemIndexToLoot] == nil then
            DCI.DebugPrint("Something went wrong (Item to loot is nil during update in loot context)", DCI.DEBUG_OUTPUT_WARNING)
        elseif DCI_DB.CompareByPrice == 1 or not DCI.UseAuctionPrices() then
            totalValueToReceieve = lootItems[itemIndexToLoot].vendorPriceTotal or 0
        elseif DCI_DB.CompareByPrice == 2 then
            totalValueToReceieve = lootItems[itemIndexToLoot].auctionPriceTotal or lootItems[itemIndexToLoot].vendorPriceTotal or 0
        elseif DCI_DB.CompareByPrice == 3 then
            totalValueToReceieve = lootItems[itemIndexToLoot].bestPriceTotal or lootItems[itemIndexToLoot].vendorPriceTotal or 0
        end

    elseif DCI.windowContext == WINDOW_CONTEXT_QUESTCOMPLETE then
        --only non-choice rewards, or if they are THE player choice
        for j = 1,#lootItems do
            if (not lootItems[j].isQuestChoice) or j == itemIndexToLoot then
                numItemsToReceive = numItemsToReceive + 1
                totalValueToReceieve = totalValueToReceieve + (lootItems[j].bestPriceTotal or 0)
            end
        end
    end

    -- create bag items
    -----------------

    --get sorted bag items array
    DCI.DebugPrint("Updating displayed items")
    local bagItems = DCI.GetSortedBagItems()

    --loop through bag item frames
    local highlightCount = 0
    for itemNum = 1,DCI.MAX_ITEM_FRAMES do
        local ItemParent = _G['DCI_Item'..itemNum]
        local bagItem = bagItems[itemNum]

        --hide item frames beyond our item count
        if itemNum > #bagItems then
            ItemParent:Hide()
        else
            --local frame handles
            local ItemIcon = _G['DCI_ItemIcon'..itemNum]
            local ItemIconTexture = _G['DCI_ItemIconTexture'..itemNum]
            local ItemIconCountText = _G['DCI_ItemIconCountText' ..itemNum]
            local ItemGlowTexture = _G['DCI_ItemGlowTexture' ..itemNum]
            local ItemInfoTopLeft = _G['DCI_ItemInfo_TextTopLeft'..itemNum]
            local ItemInfoTopRight = _G['DCI_ItemInfo_TextTopRight'..itemNum]
            local ItemInfoBottomLeft = _G['DCI_ItemInfo_TextBottomLeft'..itemNum]
            local ItemInfoBottomRight = _G['DCI_ItemInfo_TextBottomRight'..itemNum]
            local DeleteButton = _G['DCI_DeleteButton'..itemNum]

            --show item
            ItemParent:Show()

            --item icon texture + quantity
            ItemIconTexture:SetTexture(C_Item.GetItemIconByID(bagItem.itemID))
            ItemIconCountText:SetText(bagItem.quantity)

            --grey out poor quality
            if bagItem.quality == 0 then
                ItemIconTexture:SetAlpha(0.5)
                ItemIconCountText:SetAlpha(0.5)
            else
                ItemIconTexture:SetAlpha(1)
                ItemIconCountText:SetAlpha(1)
            end

            -- Glow texture for items that are more valuable than the loot
            ItemGlowTexture:Hide()
            if numItemsToReceive == 1 and totalValueToReceieve > 0 and lootItems and itemIndexToLoot and not lootItems[itemIndexToLoot].isQuestItem then
                local bagItemComparePrice = 0
                if DCI_DB.CompareByPrice == 1 or not DCI.UseAuctionPrices() then
                    bagItemComparePrice = bagItem.vendorPriceTotal
                elseif DCI_DB.CompareByPrice == 2 then
                    if bagItem.auctionPriceTotal ~= nil then
                        bagItemComparePrice = bagItem.auctionPriceTotal
                    else
                        bagItemComparePrice = bagItem.vendorPriceTotal
                    end
                elseif DCI_DB.CompareByPrice == 3 then
                    bagItemComparePrice = bagItem.bestPriceTotal
                end

                if bagItemComparePrice >= totalValueToReceieve then
                    highlightCount = highlightCount + 1
                    ItemGlowTexture:Show()
                end
            end

            --display item values
            if DCI.UseAuctionPrices() and DCI_DB.ShowBothPrices then
                --top line vendor price
                ItemInfoTopLeft:SetText(L["Vendor"])
                ItemInfoTopRight:SetText(DCI.GetMoneyStringTruncated(bagItem.vendorPriceTotal))
                ItemInfoTopRight:Show()

                --bottom line vendor price
                ItemInfoBottomLeft:SetText(L["Auction"])
                if bagItem.auctionPriceTotal and bagItem.auctionPriceTotal > 0 then
                    ItemInfoBottomRight:SetText(DCI.GetMoneyStringTruncated(bagItem.auctionPriceTotal))
                    --grey auction price if cheaper than vendor based on global AuctionGreyUnderVendor
                    if DCI_DB.AuctionGreyUnderVendor and bagItem.auctionPriceTotal <= bagItem.vendorPriceTotal then
                        ItemInfoBottomLeft:SetTextColor(0.3,0.3,0.3)
                        ItemInfoBottomRight:SetTextColor(0.3,0.3,0.3)
                    else
                        ItemInfoBottomLeft:SetTextColor(1,0.82,0)
                        ItemInfoBottomRight:SetTextColor(1,0.82,0)
                    end
                else
                    ItemInfoBottomRight:SetText("- ")
                    ItemInfoBottomLeft:SetTextColor(0.3,0.3,0.3)
                    ItemInfoBottomRight:SetTextColor(0.3,0.3,0.3)
                end
            else
                --shorten long item names
                local shortName = bagItem.name or ""
                if string.len(shortName) > 19 then
                    shortName = string.sub(bagItem.name, 1, 17) .. "..."
                end

                --top line item name
                local r,g,b,hex = C_Item.GetItemQualityColor(bagItem.quality)
                ItemInfoTopLeft:SetText("|c" .. hex .. shortName .. "|r")
                ItemInfoTopRight:Hide()

                --bottom line price
                if DCI_DB.CompareByPrice == DCI.PRICE_TYPE_VENDOR then
                    --use vendor price
                    ItemInfoBottomLeft:SetText(L["Vendor"])
                    ItemInfoBottomRight:SetText(DCI.GetMoneyStringTruncated(bagItem.vendorPriceTotal))
                elseif DCI_DB.CompareByPrice == DCI.PRICE_TYPE_AUCTION then
                    --use auction price IF its available
                    if bagItem.auctionPriceTotal then
                        ItemInfoBottomLeft:SetText(L["Auction"])
                        ItemInfoBottomRight:SetText(DCI.GetMoneyStringTruncated(bagItem.auctionPriceTotal))
                    else
                        ItemInfoBottomLeft:SetText(L["Vendor"])
                        ItemInfoBottomRight:SetText(DCI.GetMoneyStringTruncated(bagItem.vendorPriceTotal))
                    end
                elseif DCI_DB.CompareByPrice == DCI.PRICE_TYPE_BEST then
                    --use best price
                    if bagItem.auctionPriceTotal and bagItem.auctionPriceTotal > bagItem.vendorPriceTotal then
                        ItemInfoBottomLeft:SetText(L["Auction"])
                        ItemInfoBottomRight:SetText(DCI.GetMoneyStringTruncated(bagItem.auctionPriceTotal))
                    else
                        ItemInfoBottomLeft:SetText(L["Vendor"])
                        ItemInfoBottomRight:SetText(DCI.GetMoneyStringTruncated(bagItem.vendorPriceTotal))
                    end
                end
                --reset bottom color
                ItemInfoBottomLeft:SetTextColor(1,0.82,0)
                ItemInfoBottomRight:SetTextColor(1,0.82,0)
            end

            --Set script to show tooltip + ignore button on item hover
            ItemIcon:SetScript("OnEnter", function(self)
                DCI.DebugPrint("Mouseover item icon, show ignore button")
                GameTooltip:SetOwner(self, "ANCHOR_NONE")
                GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPRIGHT", 0, -2)
                GameTooltip:SetItemByID(bagItem.itemID)  
                GameTooltip:Show()

                DCI_SecondTooltip:SetOwner(DCIFrame, 'ANCHOR_NONE')
                DCI_SecondTooltip:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, 0)
                DCI_SecondTooltip:SetText(L["Click to add this item to the Ignore List"], 1, 1, 1, 0.75)
                DCI_SecondTooltip:Show()
            
                DCI_IgnoreButton.itemNum = itemNum
                DCI_IgnoreButton:SetPoint("CENTER", ItemIconTexture)
                DCI_IgnoreButton:Show()
            end)
            DCI_IgnoreButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
                DCI_SecondTooltip:Hide()
                DCI_IgnoreButton:Hide()
            end)

            --change DeleteButton to SELL instead of DELETE at a vendor, if item is vendorable
            local deleteButton_TooltipText, deleteButton_ButtonText, deleteButton_Function
            if DCI_DB.Auto_Vendor and DCI.windowContext == WINDOW_CONTEXT_VENDOR and bagItem.vendorPriceTotal and bagItem.vendorPriceTotal > 0 then
                deleteButton_ButtonText = L['Sell']
                deleteButton_TooltipText = L["Click to SELL this item"]
                deleteButton_Function = function(bag, slot) DCI.SellBagItem(bag, slot, bagItem) end
            else
                deleteButton_ButtonText = DELETE
                deleteButton_TooltipText = L["Click to DELETE this item"]
                deleteButton_Function = function(bag, slot)
                    local selectedLootSlot = LootFrame and LootFrame.DCI_LootIndexUserClick
                    DCI.ConfirmAndDeleteBagItem(bag, slot, bagItem, function()
                        if DCI_DB.Auto_Loot and DCI.windowContext == WINDOW_CONTEXT_LOOT
                            and IsLootFrameOpen() then
                            DCI.TakeItemsFromLootWindow(selectedLootSlot)
                            LootFrame.DCI_LootIndexUserClick = nil
                            DCI.UpdateDCIFrame(false)
                        end
                    end)
                end
            end
            DeleteButton:SetText(deleteButton_ButtonText)


            --Set script to show tooltip on item hover for delete button
            DeleteButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_NONE")
                GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPRIGHT", 0, 1)
                GameTooltip:SetItemByID(bagItem.itemID)  
                GameTooltip:Show()

                DCI_SecondTooltip:SetOwner(DCIFrame, 'ANCHOR_NONE')
                DCI_SecondTooltip:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, 0)

                DCI_SecondTooltip:SetText(deleteButton_TooltipText, 1, 0, 0, 1)
                DCI_SecondTooltip:Show()
            end)
            DeleteButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
                DCI_SecondTooltip:Hide()
            end)

            --click event for delete
            DeleteButton:SetScript("OnClick", function()
                deleteButton_Function(bagItem.bag, bagItem.slot)
            end)

            --click event for ignore
            DCI_IgnoreButton:SetScript("OnClick", function()
                DCI.SaveIgnoredItem(bagItems[DCI_IgnoreButton.itemNum].itemID)
                DCI_IgnoreButton:Hide()

                DCI.UpdateDCIFrame(false)
            end)
        end
    end

    -- set text strings
    -----------------

    local topSection_Text1, topSection_Text2 = "",""
    if #bagItems == 0 then
        --show message if we have no items
        topSection_Text1 = "|cffdddddd" .. L["None of your items match the current filters."] .. "|r"
        topSection_Text2 = "|cff666666" .. L["Click the info circle to change your settings."] .. "|r"

    elseif #lootItems > 0 and itemIndexToLoot and lootItems[itemIndexToLoot] and (DCI.windowContext == WINDOW_CONTEXT_LOOT or DCI.windowContext == WINDOW_CONTEXT_QUESTCOMPLETE) then
        --if there are items to receive (loot or questcomplete context)
        local text1_verbString = ""
        local text1_valueString = ""

        --set first part of text1 and calculate item count/value
        if DCI.windowContext == WINDOW_CONTEXT_LOOT then
            text1_verbString = L["Looting %s"]

            --set highlight message in text2
            if (highlightCount > 0) then
                topSection_Text2 = string.format(L["Caution: Items in %s are worth MORE than the loot."], "|cffaa0000"..L["RED"].."|r")
            else
                topSection_Text2 = L["Cheapest items from your bags (sorted):"]
            end

        elseif DCI.windowContext == WINDOW_CONTEXT_QUESTCOMPLETE then
            text1_verbString = L["Quest rewards %s"]

            --set text2 to show available Free bag slots:
            DCI.DebugPrint("Saved QuestNumRequiredItems: " .. (DCI.QuestNumRequiredItems or 0))
            local freeBagSlotsAfterTurnIn = DCI.CountFreeBagSlots() + (DCI.QuestNumRequiredItems or 0)
            local numColor = (numItemsToReceive > freeBagSlotsAfterTurnIn) and "|cffff0000" or "|cff00ff00"
            if freeBagSlotsAfterTurnIn == 1 then
                topSection_Text2 = string.format(L["You will have %s empty bag slot after turning in items."], numColor..freeBagSlotsAfterTurnIn.."|r")
            else
                topSection_Text2 = string.format(L["You will have %s empty bag slots after turning in items."], numColor..freeBagSlotsAfterTurnIn.."|r")
            end
        end

        --based on item value, count, and quest status, determine remainder of text
        if numItemsToReceive > 1 then
            --if multiple items show the total value
            text1_verbString = string.format(text1_verbString, string.format(L["%s items"], "|cffffd200"..numItemsToReceive.."|r"))
            text1_valueString = string.format(L["Total Value: %s"], DCI.GetMoneyStringTruncated(totalValueToReceieve))
            topSection_Text1 = text1_verbString .. " (" .. text1_valueString .. ")"
        else
            --if its a single item
            if lootItems[itemIndexToLoot].isQuestItem then
                --quest item, no value
                text1_valueString = ITEM_BIND_QUEST
                topSection_Text2 = L["Choose an item to delete to make room:"]
            else
                --non-quest item, show value
                if lootItems[itemIndexToLoot].bestPriceType == 1 then
                    text1_valueString = L["Vendor"] .. ": " .. DCI.GetMoneyStringTruncated(totalValueToReceieve)
                else
                    text1_valueString = L["Auction"] .. ": " .. DCI.GetMoneyStringTruncated(totalValueToReceieve)
                end
            end

            --qty multiplier string
            local quantityString = ""
            if lootItems[itemIndexToLoot].quantity > 1 then
                quantityString = lootItems[itemIndexToLoot].quantity .. "x"
            end

            --loop item text until it fits in the window, shrinking as needed.
            local shortLink = lootItems[itemIndexToLoot].link or lootItems[itemIndexToLoot].name or ""
            local itemCharacterLimit = string.len(lootItems[itemIndexToLoot].name)
            local textShrinkCounter = 25 --give up if we try too many times
            local DCIFrame_Width,_ = DCIFrame:GetSize()
            local topTextPadding = isForever and 24 or 15
            local topText_Width = 0
            repeat
                DCI.DebugPrint("Item string attempt " .. 26-textShrinkCounter .. " - char limit " ..itemCharacterLimit .. " - new string ".. shortLink)
                local quantityString = ""
                if lootItems[itemIndexToLoot].quantity > 1 then
                    quantityString = lootItems[itemIndexToLoot].quantity .. "x"
                end

                topSection_Text1 = string.format(text1_verbString, quantityString .. shortLink) .. "  (" .. text1_valueString .. ")"
                DCI_TopSection_Text1:SetText(topSection_Text1)

                topText_Width,_ = DCI_TopSection_Text1:GetSize()
                textShrinkCounter = textShrinkCounter - 1
                itemCharacterLimit = itemCharacterLimit - 1
                if textShrinkCounter <= 0 then itemCharacterLimit = 5 end
                local escapedName = lootItems[itemIndexToLoot].name:gsub("(%W)", "%%%1")
                shortLink = string.gsub(lootItems[itemIndexToLoot].link, escapedName, function()
                    return string.sub(lootItems[itemIndexToLoot].name, 1, itemCharacterLimit) .. "..."
                end)
            until itemCharacterLimit < 5 or (topText_Width + topTextPadding) < DCIFrame_Width or textShrinkCounter <= 0
            --if we're still too long just use shortened name
            if (topText_Width + topTextPadding) > DCIFrame_Width then
                DCI.DebugPrint("Giving up on shortening, just use 15 chars of name")
                topSection_Text1 = string.format(text1_verbString, quantityString .. string.sub(lootItems[itemIndexToLoot].name, 1, 15)) .. "...  (" .. text1_valueString .. ")"
                DCI_TopSection_Text1:SetText(topSection_Text1)
            end
        end
    else
        --set defaults
        local freeBagSlots = DCI.CountFreeBagSlots()
        if freeBagSlots == 1 then
            topSection_Text1 = string.format(L["You currently have %s empty bag slot."], "|cffffd200"..freeBagSlots.."|r")
        elseif freeBagSlots == 0 then
            topSection_Text1 = string.format(L["You currently have %s empty bag slots."], "|cffff0000"..freeBagSlots.."|r")
        else
            topSection_Text1 = string.format(L["You currently have %s empty bag slots."], "|cffffd200"..freeBagSlots.."|r")
        end

        if DCI.windowContext == WINDOW_CONTEXT_QUESTACCEPT then
            topSection_Text2 = L["This quest may require some free bag space."]
        else
            topSection_Text2 = L["Cheapest items from your bags (sorted):"]
        end
     end

    --finally set text in frame
    DCI_TopSection_Text1:SetText(topSection_Text1)
    DCI_TopSection_Text2:SetText(topSection_Text2)

    -- finalize
    -----------------

    -- Show the frame
    if showFrameAfterUpdate then
        DCI.DebugPrint("Displaying frame and resetting wait flag")
        DCIFrame:Show()
        DCI.InvErrWaitForLootFrame = false
    end
end

--function to toggle main window
function DCI.ToggleDCIFrame()
    if DCIFrame and DCIFrame:IsShown() then
        DCI.InvErrWaitForLootFrame = false
        pendingLootUpdate = nil
        pendingBagVisibilityUpdate = nil
        bagWindowAutoOpened = false
        if DCI_DB.Auto_Inventory and IsInventoryOpen() then inventoryWindowDismissed = true end
        if DCI.windowContext == WINDOW_CONTEXT_LOOT then lootWindowDismissed = true end
        DCI.HideWindow("/dci toggle")
    else
        DCI.UpdateDCIFrame()
    end
end

--function to create settings panel
function DCI.CreateDCISettings()
    --local function to create panel section wrapper
    local function CreateConfigPanelSection(ParentFrame, OffsetX, OffsetY, SectionHeight, LabelText)
        local sectionFrame = CreateFrame("Frame", "DCI_Config_Section_" ..  string.sub(string.gsub(LabelText, " ", ""), 1, 10), ParentFrame, "TooltipBorderBackdropTemplate")
        sectionFrame:SetPoint("TOPLEFT", ParentFrame, "TOPLEFT", OffsetX+15, OffsetY)
        sectionFrame:SetSize(620, SectionHeight)
        sectionFrame:SetBackdropColor(0.3,0.3,0.3,0.75)
        sectionFrame.DCI_FrameType = DCI.FRAME_PANEL

        local label = sectionFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", sectionFrame, "TOPLEFT", 3, 13)
        label:SetText(LabelText)

        return sectionFrame
    end

    --local function to create settings checkbox
    local function CreateConfigPanelCheckbox(ParentFrame, OffsetX, OffsetY, CheckboxVariable, CheckboxText, CheckboxFunction)
        if not CheckboxFunction then CheckboxFunction = function(self) DCI_DB[CheckboxVariable] = self:GetChecked() DCI.UpdateDCIFrame(false) DCI.RegisterFrameEvents() end end

        local checkboxFrame = CreateFrame("CheckButton", "DCI_Config_Checkbox_"..CheckboxVariable, ParentFrame, "UICheckButtonTemplate")
        checkboxFrame:SetPoint("TOPLEFT", ParentFrame, "TOPLEFT", OffsetX+7, OffsetY-7)
        checkboxFrame:SetChecked(DCI_DB[CheckboxVariable] or false)
        checkboxFrame:HookScript("OnClick", CheckboxFunction)
        checkboxFrame.DCI_FrameType = DCI.FRAME_CHECKBOX
        checkboxFrame.DCI_UpdateVariable = CheckboxVariable

        local label = checkboxFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", checkboxFrame, "TOPRIGHT", 0, -10)
        label:SetText(CheckboxText)

        checkboxFrame:HookScript("OnEnable", function() label:SetTextColor(1, 1, 1) end)
        checkboxFrame:HookScript("OnDisable", function() label:SetTextColor(0.5, 0.5, 0.5) end)
        return checkboxFrame
    end

    --local function to create settings dropdown
    local function CreateConfigPanelDropdown(ParentFrame, OffsetX, OffsetY, DropdownVariable, DropdownText, DropdownValues, DropdownChoices, DropdownWidth)
        local dropdownFrame = CreateFrame("DropdownButton", "DCI_Config_Dropdown_"..DropdownVariable, ParentFrame, "WowStyle1DropdownTemplate")
        dropdownFrame:SetPoint("TOPLEFT", ParentFrame, "TOPLEFT", OffsetX+275+27, OffsetY-11)
        dropdownFrame:SetWidth(DropdownWidth or 250)
        dropdownFrame.DCI_FrameType = DCI.FRAME_DROPDOWN
        dropdownFrame.DCI_UpdateVariable = DropdownVariable

        local labelFrame = dropdownFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        labelFrame:SetPoint("TOPLEFT", ParentFrame, "TOPLEFT", OffsetX+12+27, OffsetY-18)
        labelFrame:SetText(DropdownText)
        labelFrame.DCI_FrameType = DCI.FRAME_FONTSTRING

        --setup dropdown
        dropdownFrame:SetupMenu(function(dropdown, rootDescription)
            for i = 1,#DropdownChoices do
                rootDescription:CreateButton(DropdownChoices[i], function()
                    DCI_DB[DropdownVariable] = DropdownValues[i]
                    dropdownFrame:SetDefaultText(DropdownChoices[i])
                    DCI.UpdateDCIFrame(false)

                    --hack to disable Grey Auction Price setting based on ShowBothPrices
                    if DCI_DB.ShowBothPrices then
                        DCI_Config_Checkbox_AuctionGreyUnderVendor:Enable()
                    else
                        DCI_Config_Checkbox_AuctionGreyUnderVendor:Disable()
                    end
                end)
            end
        end)

        --child function to update value
        function dropdownFrame:DCI_SetDefaultText()
            DCI.DebugPrint("DCI_SetDefaultText() ")
            local choiceIndex = 1
            for i = 1,#DropdownChoices do
                if DropdownValues[i] == DCI_DB[DropdownVariable] then
                    choiceIndex = i
                    break
                end
            end
            DCI.DebugPrint("choiceIndex "..choiceIndex)
            self:SetDefaultText(DropdownChoices[choiceIndex]) --set the proper default
            self.Text:SetText(DropdownChoices[choiceIndex]) --but also force the text to change now
            DCI.UpdateDCIFrame(false)
        end
        dropdownFrame:DCI_SetDefaultText()

        return dropdownFrame
    end

    --local function to create settings button
    local function CreateConfigPanelButton(ParentFrame, OffsetX, OffsetY, ButtonText, ButtonFunction)
        local buttonFrame = CreateFrame("Button", "DCI_Config_Button_" ..  string.sub(string.gsub(ButtonText, "[^A-Za-z]", ""), 1, 10), ParentFrame, "UIPanelButtonTemplate") 
        buttonFrame:SetText(ButtonText)
        buttonFrame:SetSize(150, 32)
        buttonFrame:SetPoint("TOPLEFT", ParentFrame, "TOPLEFT", OffsetX, OffsetY)
        buttonFrame:HookScript("OnClick", ButtonFunction)
        return buttonFrame
    end

    ---------------------------

    -- Create a configuration panel
    local ConfigFrame = CreateFrame("Frame", "DCI_ConfigPanel", UIParent)
    ConfigFrame.name = DCI.ADDON_TITLE
    local settingsCategory = Settings.RegisterCanvasLayoutCategory(ConfigFrame, DCI.ADDON_TITLE)
    DCI.settingsCategory = settingsCategory
    Settings.RegisterAddOnCategory(settingsCategory)

    -- Title text
    local title = ConfigFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(DCI.ADDON_TITLE)

    -- Version text
    local versionText = ConfigFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    versionText:SetPoint("TOPRIGHT", -16-20, -16)
    versionText:SetText(DCI.ADDON_VERSION)
    versionText:SetTextColor(0.3, 0.3, 0.3, 0.3)

    --buttons to reset ignore list, show test window, reset settings
    local Button_ResetIgnore = CreateConfigPanelButton(ConfigFrame, 16, -42, L["Reset Ignored Items"], DCI.ResetIgnoredItem)
    local Button_TestWindow = CreateConfigPanelButton(ConfigFrame, 16+170, -42, L["Open Test Window"], DCI.ToggleDCIFrame)
    local Button_DefaultSettings = CreateConfigPanelButton(ConfigFrame, 16+170*2, -42, L["Reset Default Settings"], function()
        DCI.InitializeSavedVariables(true)
        DCI.RegisterFrameEvents()
        DCI.UpdateDCISettings()
    end)

    ---------------------------

    --section for window behavior
    local Section_WindowSettings = CreateConfigPanelSection(ConfigFrame, 0, -100+5, 5*27+16, L["Window Behavior"])

    --checkbox for HideSoulbound
    local Checkbox_HideSoulbound = CreateConfigPanelCheckbox(Section_WindowSettings, 0, 0*-27, "HideSoulbound", L["Hide soulbound items"])
    
    --dropdown for MaxQuality
    local qualityChoices = {"|cff9d9d9d"..ITEM_QUALITY0_DESC, "|cffffffff"..ITEM_QUALITY1_DESC, "|cff1eff00"..ITEM_QUALITY2_DESC, "|cff0070dd"..ITEM_QUALITY3_DESC, "|cffa335ee"..ITEM_QUALITY4_DESC, "|cffff8000"..ITEM_QUALITY5_DESC}
    local qualityValues = {0, 1, 2, 3, 4, 5}
    local Dropdown_MaxQuality = CreateConfigPanelDropdown(Section_WindowSettings, 0, 1*-27, "MaxQuality", L["Max item quality to display in window"], qualityValues, qualityChoices, 120)

    --dropdown for ConfirmMinQuality
    local confirmChoices = {"|cff9d9d9d"..ITEM_QUALITY0_DESC, "|cffffffff"..ITEM_QUALITY1_DESC, "|cff1eff00"..ITEM_QUALITY2_DESC, "|cff0070dd"..ITEM_QUALITY3_DESC, "|cffa335ee"..ITEM_QUALITY4_DESC, "|cffff8000"..ITEM_QUALITY5_DESC, "|cffff0000"..NEVER}
    local confirmValues = {0, 1, 2, 3, 4, 5, nil}
    local Dropdown_ConfirmMinQuality = CreateConfigPanelDropdown(Section_WindowSettings, 0, 2*-27, "ConfirmMinQuality", L["Confirm delete if quality is at least"], confirmValues, confirmChoices, 120)

    --checkbox for AllowInCombat & debug
    local Checkbox_AllowInCombat = CreateConfigPanelCheckbox(Section_WindowSettings, 0, 3*-27, "AllowInCombat", L["Allow window in combat"])
    local Checkbox_DebugOutput = CreateConfigPanelCheckbox(Section_WindowSettings, 0, 4*-27, "DebugOutput", L["Show Debug Output"], function(self) DCI_DB.DebugOutput = self:GetChecked() and 1 or nil end)
    if isForever then
        CreateConfigPanelCheckbox(Section_WindowSettings, 250, 4*-27, "HideBronzeTheme", L["Hide bronze theme and borders"], function(self)
            DCI_DB.HideBronzeTheme = self:GetChecked()
            DCI.UpdateWindowTheme()
        end)
    end

    ---------------------------

    --section for auctomatic display settings
    local Section_AutomaticDisplay = CreateConfigPanelSection(ConfigFrame, 0, -275+10, 5*27+16, L["Automatic Display"])

    --checkboxes for auto settings
    local Checkbox_Auto_Loot = CreateConfigPanelCheckbox(Section_AutomaticDisplay, 0, 0*-27, "Auto_Loot", L["Looting items"])
    local Checkbox_Auto_Vendor = CreateConfigPanelCheckbox(Section_AutomaticDisplay, 0, 1*-27, "Auto_Vendor", L["At vendors"])
    local Checkbox_Auto_Trade = CreateConfigPanelCheckbox(Section_AutomaticDisplay, 0, 2*-27, "Auto_Trade", L["Trading with players"])
    local Checkbox_Auto_Mail = CreateConfigPanelCheckbox(Section_AutomaticDisplay, 0, 3*-27, "Auto_Mail", L["Opening mail with items"])
    local Checkbox_Auto_QuestAccept = CreateConfigPanelCheckbox(Section_AutomaticDisplay, 310-75, 0*-27, "Auto_QuestAccept", L["Accepting quests that provide items"])
    local Checkbox_Auto_QuestComplete = CreateConfigPanelCheckbox(Section_AutomaticDisplay, 310-75, 1*-27, "Auto_QuestComplete", L["Completing quests with rewards"])
    local Checkbox_Auto_Roll = CreateConfigPanelCheckbox(Section_AutomaticDisplay, 310-75, 2*-27, "Auto_Roll", L["When Need/Greed rolling"])
    local Checkbox_Auto_Inventory = CreateConfigPanelCheckbox(Section_AutomaticDisplay, 310-75, 3*-27, "Auto_Inventory", L["When inventory is open"])
    local Checkbox_Auto_LowSlots = CreateConfigPanelCheckbox(Section_AutomaticDisplay, 0, 4*-27, "Auto_LowSlots", L["When looting with at most this many free slots"])
    local LowSlotsThreshold = CreateFrame("EditBox", "DCI_Config_LowSlotsThreshold", Section_AutomaticDisplay, "InputBoxTemplate")
    LowSlotsThreshold:SetPoint("TOPLEFT", Section_AutomaticDisplay, "TOPLEFT", 545, 4*-27-7)
    LowSlotsThreshold:SetSize(40, 24)
    LowSlotsThreshold:SetNumeric(true)
    LowSlotsThreshold:SetMaxLetters(3)
    LowSlotsThreshold:SetAutoFocus(false)
    LowSlotsThreshold:SetText(tostring(DCI_DB.LowSlotsThreshold))
    LowSlotsThreshold.DCI_FrameType = DCI.FRAME_EDITBOX
    LowSlotsThreshold.DCI_UpdateVariable = "LowSlotsThreshold"
    LowSlotsThreshold:HookScript("OnMouseDown", function(self) self:SetFocus() end)
    LowSlotsThreshold:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    LowSlotsThreshold:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(DCI_DB.LowSlotsThreshold))
        self:ClearFocus()
    end)
    LowSlotsThreshold:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local value = tonumber(self:GetText())
        if value then DCI_DB.LowSlotsThreshold = math.max(0, math.min(999, value)) end
    end)
    LowSlotsThreshold:SetScript("OnEditFocusLost", function(self)
        local enteredValue = tonumber(self:GetText())
        local value = math.max(0, math.min(999, enteredValue or 0))
        DCI_DB.LowSlotsThreshold = value
        if enteredValue ~= value then self:SetText(tostring(value)) end
    end)

    ---------------------------

    --section for auction settings
    local Section_AuctionSettings = CreateConfigPanelSection(ConfigFrame, 0, -395-30+16-27, 6*27+15, L["Auction Prices"])

    --checkbox for UseAuctionPrices
    local Checkbox_UseAuctionPrices = CreateConfigPanelCheckbox(Section_AuctionSettings, 0, 0*-27, "UseAuctionPrices", L["Use auction prices"])
    --hack to get text2 object to anchor text1
    local Checkbox_UseAuctionPrices_Text = Checkbox_UseAuctionPrices
    for _, region in ipairs({Checkbox_UseAuctionPrices:GetRegions()}) do
        if region:GetWidth() and Checkbox_UseAuctionPrices_Text and region:GetWidth() > Checkbox_UseAuctionPrices_Text:GetWidth() then
            Checkbox_UseAuctionPrices_Text = region
        end
    end
    local auctionCheckboxText2 = Checkbox_UseAuctionPrices:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    auctionCheckboxText2:SetPoint("LEFT", Checkbox_UseAuctionPrices_Text, "RIGHT", 5, 0)

    --parent frame for disable-able auction settings
    local auctionSettingsDisableFrame = CreateFrame("Frame", "DCI_Config_AuctionFrame", ConfigFrame)
    auctionSettingsDisableFrame:SetAllPoints(Section_AuctionSettings)
    auctionSettingsDisableFrame.DCI_FrameType = DCI.FRAME_PANEL --set this as a panel type so it gets caught by default reset button

    -- dropdown for CompareByPrice
    local compareByChoices = {L["Vendor Price Only"], L["Auction Price (if known, otherwise Vendor)"], L["Best Price (Vendor or Auction)"]}
    local compareByValues = {DCI.PRICE_TYPE_VENDOR, DCI.PRICE_TYPE_AUCTION, DCI.PRICE_TYPE_BEST}
    local Dropdown_CompareByPrice = CreateConfigPanelDropdown(auctionSettingsDisableFrame, 0, 1*-27, "CompareByPrice", L["Sort and Compare item values based on"], compareByValues, compareByChoices)

    -- dropdown for ShowBothPrices
    local showBothChoices = {L["Item Name + Selected Price"], L["Both Prices (Vendor + Auction)"]}
    local showBothValues = {false, true}
    local Dropdown_ShowBothPrices = CreateConfigPanelDropdown(auctionSettingsDisableFrame, 0, 2*-27, "ShowBothPrices", L["Lines to show"], showBothValues, showBothChoices)

    --checkbox for AuctionGreyUnderVendor
    local Checkbox_AuctionGrey = CreateConfigPanelCheckbox(auctionSettingsDisableFrame, 0, 3*-27, "AuctionGreyUnderVendor", L["Grey out auction price if it's less than the vendor price (when both are shown)"])
    if DCI_DB.ShowBothPrices then
        Checkbox_AuctionGrey:Enable()
    else
        Checkbox_AuctionGrey:Disable()
    end

    --checkbox for SubtractAuctionCut
    local Checkbox_AuctionCut = CreateConfigPanelCheckbox(auctionSettingsDisableFrame, 0, 4*-27, "SubtractAuctionCut", L["Subtract 5% cut from auction price"],
        function(self)
            -- clear the item cache so auction prices will recalculate
            for k in pairs(DCI.ItemInfo) do
                DCI.ItemInfo[k] = nil
            end
            DCI_DB.SubtractAuctionCut = self:GetChecked()
            DCI.UpdateDCIFrame(false)
        end
    )

    --checkbox for AuctionPriceHidePoorQuality
    local Checkbox_AuctionHidePoor = CreateConfigPanelCheckbox(auctionSettingsDisableFrame, 0, 5*-27, "AuctionPriceHidePoorQuality", L["Ignore auction price for grey quality items"])

    --hook function to update auction frame enable/disable state
    local function UpdateAuctionFrameState()
        local disableAuctionSettings = false
        if not DCI.UseAuctionPrices(true) then
            --if no API available at all, disable the global auction setting and flag the rest for disable
            disableAuctionSettings = true
            DCI_Config_Checkbox_UseAuctionPrices:Disable()
            auctionCheckboxText2:SetText("|cffbb0000(" ..L["No auction price addon found"] .. ")")
        else
            --if there is an api, go by global auction checkbox
            disableAuctionSettings = not Checkbox_UseAuctionPrices:GetChecked()
            DCI_Config_Checkbox_UseAuctionPrices:Enable()
            if DCI_AuctionSource then
                auctionCheckboxText2:SetText("(".. L["sourced from"] .. " " .. DCI_AuctionSource .. ")")
            else
                auctionCheckboxText2:SetText("")
            end
        end

        if disableAuctionSettings then
            --disable auction settings & labels
            for _, childFrame in ipairs({auctionSettingsDisableFrame:GetChildren()}) do
                childFrame:Disable()
                --check dropdown children for text to color
                if childFrame.DCI_FrameType == DCI.FRAME_DROPDOWN then
                    for _, grandchildFrame in ipairs({childFrame:GetRegions()}) do
                        if grandchildFrame.DCI_FrameType == DCI.FRAME_FONTSTRING then
                            grandchildFrame:SetTextColor(0.5, 0.5, 0.5)
                        end
                    end
                end
            end
        else
            --enable auction settings & labels
            for _, childFrame in ipairs({auctionSettingsDisableFrame:GetChildren()}) do
                childFrame:Enable()
                --check dropdown children for text to color
                if childFrame.DCI_FrameType == DCI.FRAME_DROPDOWN then
                    for _, grandchildFrame in ipairs({childFrame:GetRegions()}) do
                        if grandchildFrame.DCI_FrameType == DCI.FRAME_FONTSTRING then
                            grandchildFrame:SetTextColor(1, 1, 1)
                        end
                    end
                end
            end
        end

        --override auction grey checkbox based on bothprices setting
        if disableAuctionSettings == false and DCI_DB.ShowBothPrices then
            DCI_Config_Checkbox_AuctionGreyUnderVendor:Enable()
        else
            DCI_Config_Checkbox_AuctionGreyUnderVendor:Disable()
        end
    end
    ConfigFrame:HookScript("OnShow", function(self) UpdateAuctionFrameState() end)
    Checkbox_UseAuctionPrices:HookScript("OnClick", function(self) UpdateAuctionFrameState() end)
end

--function to update settings panel
function DCI.UpdateDCISettings()
    --loop through and update frames based on their DCI_UpdateVariable property
    for _, childFrame in ipairs({DCI_ConfigPanel:GetChildren()}) do
        if childFrame.DCI_FrameType == DCI.FRAME_PANEL then
            for _, grandchildFrame in ipairs({childFrame:GetChildren()}) do
                if grandchildFrame.DCI_UpdateVariable then
                    if grandchildFrame.DCI_FrameType == DCI.FRAME_CHECKBOX then
                        grandchildFrame:SetChecked(DCI_DB[grandchildFrame.DCI_UpdateVariable])
                    elseif grandchildFrame.DCI_FrameType == DCI.FRAME_DROPDOWN then
                        local frameName = grandchildFrame:GetName()
                        local updateValue = DCI_DB[grandchildFrame.DCI_UpdateVariable]
                        grandchildFrame:DCI_SetDefaultText()
                    elseif grandchildFrame.DCI_FrameType == DCI.FRAME_EDITBOX then
                        grandchildFrame:SetText(tostring(DCI_DB[grandchildFrame.DCI_UpdateVariable]))
                    end
                end
            end
        end
    end
    --retrigger config show to cause full update
    local f=DCI_ConfigPanel:GetScript("OnShow"); f();
end

--function to load/initialize saved vars
function DCI.InitializeSavedVariables(resetDefaults)
    resetDefaults = resetDefaults or false --default false

    DCI.DebugPrint("Initializing saved variables")
    if resetDefaults then
        --reset to default if flag is set
        DCI.DebugPrint(L["Restoring settings to default"], DCI.DEBUG_OUTPUT_FORCED)
        DCI_DB = {}
    elseif not DCI_DB or next(DCI_DB) == nil then
        --if settings are empty, try to load old version of settings for backwards compaibility
        DCI.DebugPrint("No current settings found, trying backwards compatibility")
        DCI_DB = {}
        if DCI_IgnoredItems ~= nil then DCI_DB.IgnoredItems = DCI_IgnoredItems end
        if DCI_UseAuctionPrices ~= nil then DCI_DB.UseAuctionPrices = DCI_UseAuctionPrices end
        if DCI_SubtractAuctionCut ~= nil then DCI_DB.SubtractAuctionCut = DCI_SubtractAuctionCut end
        if DCI_AuctionPriceHidePoorQuality ~= nil then DCI_DB.AuctionPriceHidePoorQuality = DCI_AuctionPriceHidePoorQuality end
        if DCI_AuctionGreyUnderVendor ~= nil then DCI_DB.AuctionGreyUnderVendor = DCI_AuctionGreyUnderVendor end
        if DCI_HideSoulbound ~= nil then DCI_DB.HideSoulbound = DCI_HideSoulbound end
        if DCI_AllowInCombat ~= nil then DCI_DB.AllowInCombat = DCI_AllowInCombat end
        if DCI_MaxQuality ~= nil then DCI_DB.MaxQuality = DCI_MaxQuality end
        if DCI_CompareByPrice ~= nil then DCI_DB.CompareByPrice = DCI_CompareByPrice end
        if DCI_ShowBothPrices ~= nil then DCI_DB.ShowBothPrices = DCI_ShowBothPrices end
        if DCI_ConfirmMinQuality ~= nil then DCI_DB.ConfirmMinQuality = DCI_ConfirmMinQuality end
    end

    --set default values
    if DCI_DB.IgnoredItems == nil then DCI_DB.IgnoredItems = {} end
    if DCI_DB.UseAuctionPrices == nil then DCI_DB.UseAuctionPrices = true end
    if DCI_DB.SubtractAuctionCut == nil then DCI_DB.SubtractAuctionCut = true end
    if DCI_DB.AuctionPriceHidePoorQuality == nil then DCI_DB.AuctionPriceHidePoorQuality = true end
    if DCI_DB.AuctionGreyUnderVendor == nil then DCI_DB.AuctionGreyUnderVendor = true end
    if DCI_DB.HideSoulbound == nil then DCI_DB.HideSoulbound = true end
    if DCI_DB.AllowInCombat == nil then DCI_DB.AllowInCombat = true end
    if isForever and DCI_DB.HideBronzeTheme == nil then DCI_DB.HideBronzeTheme = false end
    if DCI_DB.MaxQuality == nil then DCI_DB.MaxQuality = 2 end --default to uncommon
    if DCI_DB.CompareByPrice == nil then DCI_DB.CompareByPrice = DCI.PRICE_TYPE_BEST end
    if DCI_DB.ShowBothPrices == nil then DCI_DB.ShowBothPrices = false end
    if DCI_DB.ConfirmMinQuality == nil then DCI_DB.ConfirmMinQuality = nil end --default to nil which represents never
    if DCI_DB.Auto_Loot == nil then DCI_DB.Auto_Loot = true end
    if DCI_DB.Auto_Inventory == nil then DCI_DB.Auto_Inventory = false end
    if DCI_DB.Auto_LowSlots == nil then DCI_DB.Auto_LowSlots = false end
    DCI_DB.LowSlotsThreshold = math.max(0, math.min(999, math.floor(tonumber(DCI_DB.LowSlotsThreshold) or 0)))
    if DCI_DB.Auto_Vendor == nil then DCI_DB.Auto_Vendor = true end
    if DCI_DB.Auto_Trade == nil then DCI_DB.Auto_Trade = true end
    if DCI_DB.Auto_Mail == nil then DCI_DB.Auto_Mail = true end
    if DCI_DB.Auto_QuestAccept == nil then DCI_DB.Auto_QuestAccept = true end
    if DCI_DB.Auto_QuestComplete == nil then DCI_DB.Auto_QuestComplete = true end
    if DCI_DB.Auto_Roll == nil then DCI_DB.Auto_Roll = true end

    --on every load reset to no debug
    if DCI_DB.DebugOutput then
        DCI.DebugPrint("Automatically disabling this debug output.")
        DCI_DB.DebugOutput = nil
    end
    DCI.UpdateWindowTheme()
end

--function to register events based on user settings
function DCI.RegisterFrameEvents()
    DCI.DebugPrint("Registering events")

    DCIFrame:RegisterEvent("BAG_UPDATE")
    DCIFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    if DCI_DB.Auto_Inventory then
        DCIFrame:RegisterEvent("BAG_OPEN")
        DCIFrame:RegisterEvent("BAG_CLOSED")
        DCI.QueueInventoryVisibilityUpdate()
    else
        DCIFrame:UnregisterEvent("BAG_OPEN")
        DCIFrame:UnregisterEvent("BAG_CLOSED")
        pendingBagVisibilityUpdate = nil
        if bagWindowAutoOpened and DCIFrame:IsShown() and DCI.windowContext == WINDOW_CONTEXT_FREE then
            DCI.HideWindow("inventory option disabled")
        end
        bagWindowAutoOpened = false
        inventoryWindowDismissed = false
    end

    if DCI_DB.Auto_Loot or DCI_DB.Auto_Vendor or DCI_DB.Auto_QuestAccept or DCI_DB.Auto_Mail or DCI.WindowDebug then
        DCIFrame:RegisterEvent("UI_ERROR_MESSAGE")
    else
        DCIFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    end

    if not DCI_DB.AllowInCombat or DCI.WindowDebug then
        DCIFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        DCIFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        DCIFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
        DCIFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end

    if DCI_DB.Auto_Loot or DCI_DB.Auto_LowSlots or DCI.WindowDebug then
        DCIFrame:RegisterEvent("LOOT_CLOSED")
        DCIFrame:RegisterEvent("LOOT_OPENED")
    else
        DCIFrame:UnregisterEvent("LOOT_CLOSED")
        DCIFrame:UnregisterEvent("LOOT_OPENED")
    end
    if not DCI_DB.Auto_Loot and not DCI_DB.Auto_LowSlots then
        DCI.InvErrWaitForLootFrame = false
        pendingLootUpdate = nil
    end

    if DCI_DB.Auto_Trade then
        DCIFrame:RegisterEvent("TRADE_SHOW")
        DCIFrame:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
    else
        DCIFrame:UnregisterEvent("TRADE_SHOW")
        DCIFrame:UnregisterEvent("TRADE_TARGET_ITEM_CHANGED")
    end

    if DCI_DB.Auto_Mail then
        DCIFrame:RegisterEvent("MAIL_FAILED")
        DCIFrame:RegisterEvent("MAIL_SHOW")
    else
        DCIFrame:UnregisterEvent("MAIL_FAILED")
        DCIFrame:UnregisterEvent("MAIL_SHOW")
    end

    if DCI_DB.Auto_QuestAccept then
        DCIFrame:RegisterEvent("QUEST_DETAIL")
    else
        DCIFrame:UnregisterEvent("QUEST_DETAIL")
    end

    if DCI_DB.Auto_QuestComplete then
        DCIFrame:RegisterEvent("QUEST_COMPLETE")
        DCIFrame:RegisterEvent("QUEST_PROGRESS")
        DCIFrame:RegisterEvent("GOSSIP_SHOW")
    else
        DCIFrame:UnregisterEvent("QUEST_COMPLETE")
        DCIFrame:UnregisterEvent("QUEST_PROGRESS")
        DCIFrame:UnregisterEvent("GOSSIP_SHOW")
    end

    if DCI_DB.Auto_Roll then
        DCIFrame:RegisterEvent("START_LOOT_ROLL")
    else
        DCIFrame:UnregisterEvent("START_LOOT_ROLL")
    end
end

--function to handle global events
function DCI.HandleEvent(self, event, ...)
    local arg1,arg2 = ...

    if event == "LOOT_OPENED" then
        DCI.LootOpen = true
        lootWindowDismissed = false
        DCI.HookLootFrame()
        DCI.TraceWindow("LOOT_OPENED autoLoot=" .. tostring(arg1))
    elseif event == "LOOT_CLOSED" then
        DCI.LootOpen = false
        DCI.InvErrWaitForLootFrame = false
        pendingLootUpdate = nil
        if LootFrame then LootFrame.DCI_LootIndexUserClick = nil end
        DCI.TraceWindow("LOOT_CLOSED")
    elseif event == "UI_ERROR_MESSAGE" then
        DCI.TraceWindow("UI_ERROR_MESSAGE type=" .. tostring(arg1) .. " message=" .. tostring(arg2)
            .. (arg2 == ERR_INV_FULL and " (ERR_INV_FULL)" or " (ignored)"))
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        DCI.TraceWindow(event)
    end

    --debug
    if event ~= "UI_ERROR_MESSAGE" and event ~= "BAG_UPDATE" then
        DCI.DebugPrint("***** " .. event .. " - " .. DCI.dump(...))
    end

    --initial addon load
    if event == "ADDON_LOADED" and arg1 == addonName then
        DCIFrame:UnregisterEvent("ADDON_LOADED")
        DCI.DebugPrint("DCI Addon loaded")
        --initialize
        DCI.InitializeSavedVariables()
        DCI.RegisterFrameEvents()
        DCI.HookLootFrame()

        --globals
        DCI.InvErrWaitForLootFrame = false
        DCI.WindowMoved = false
        DCI.QuestNumRequiredItems = nil

        -- Register slash command
        SLASH_DCI1 = "/dci"
        SlashCmdList["DCI"] = DCI.HandleSlashCommand

        --create settings screen
        DCI.CreateDCISettings()

        hooksecurefunc("QuestInfoItem_OnClick", function(button)
            if button.type == "choice" and DCIFrame:IsShown() then
                DCI.UpdateDCIFrame(false)
            end
        end)
        -- Forever's Mainline loot UI uses recycled ScrollBox rows, not LootButtonN.
        if EventRegistry then
            EventRegistry:RegisterCallback("LootFrame.ItemLooted", function()
                if LootFrame then LootFrame.DCI_LootIndexUserClick = LootFrame.selectedSlot end
            end, DCI)
            if isForever then
                EventRegistry:RegisterCallback("ContainerFrame.OpenBag", function()
                    DCI.InventoryFrameCallbacks = (DCI.InventoryFrameCallbacks or 0) + 1
                    DCI.TraceWindow("ContainerFrame.OpenBag")
                    DCI.QueueInventoryVisibilityUpdate()
                end, DCI)
                EventRegistry:RegisterCallback("ContainerFrame.CloseBag", function()
                    DCI.InventoryFrameCallbacks = (DCI.InventoryFrameCallbacks or 0) + 1
                    DCI.TraceWindow("ContainerFrame.CloseBag")
                    DCI.QueueInventoryVisibilityUpdate()
                end, DCI)
            end
        end
    end

    if event == "GET_ITEM_INFO_RECEIVED" and arg2 then
        rawset(DCI.ItemInfo, arg1, nil)
        if DCIFrame:IsShown() then DCI.UpdateDCIFrame(false) end
    end

    --update frame if bag updates while it is open
    if event == "BAG_UPDATE" and DCIFrame and DCIFrame:IsShown() then
        DCI.DebugPrint("Updating window due to bag update")
        DCI.UpdateDCIFrame(false)
    elseif event == "BAG_UPDATE" and DCI_DB.Auto_LowSlots and DCI.LootOpen then
        DCI.QueueLootUpdate("BAG_UPDATE")
    end

    if (event == "BAG_OPEN" or event == "BAG_CLOSED") and DCI_DB.Auto_Inventory then
        DCI.QueueInventoryVisibilityUpdate()
    end

    --hide if we enter combat, based on global AllowInCombat
    if DCI_DB.AllowInCombat == false and event == "PLAYER_REGEN_DISABLED" then
        if DCIFrame and DCIFrame:IsShown() then
            DCI.DebugPrint("Hiding due to combat, setting wait flag*")
            if DCI.windowContext == WINDOW_CONTEXT_LOOT and IsLootFrameOpen() then
                DCI.InvErrWaitForLootFrame = true
            end
            DCI.HideWindow("combat")
        end
    end
    if DCI_DB.AllowInCombat == false and event == "PLAYER_REGEN_ENABLED"
        and DCI_DB.Auto_Inventory and IsInventoryOpen()
        and not DCIFrame:IsShown() and not inventoryWindowDismissed then
        bagWindowAutoOpened = true
        DCI.UpdateDCIFrame()
    end

    --react to full inv error
    if event == "UI_ERROR_MESSAGE" and arg2 == ERR_INV_FULL then
        DCI.DebugPrint("Inventory error")
        --if dci frame is open
        if DCIFrame and DCIFrame:IsShown() then
            DCI.DebugPrint("Updating window since its already shown")
            DCI.UpdateDCIFrame(false)

        --if loot window is open
        elseif IsLootFrameOpen() then
            DCI.DebugPrint("Assuming inv error was from LootFrame")
            if DCI_DB.Auto_Loot then
                DCI.InvErrWaitForLootFrame = true
                DCI.TryShowLootWindow("inventory full")
            else
                DCI.TraceWindow("inventory full: automatic looting disabled")
            end

        --if vendor window is open
        elseif MerchantFrame and MerchantFrame:IsShown() then
            DCI.DebugPrint("Assuming inv error was from MerchantFrame")
            if DCI_DB.Auto_Vendor then
                DCI.UpdateDCIFrame()
            end

        --if mail window is open
        elseif MailFrame and MailFrame:IsShown() then
            DCI.DebugPrint("Assuming inv error was from MailFrame")
            if DCI_DB.Auto_Mail then
                --dont update dci, since MAIL_FAILED will handle it
            end

        --if we saved current target as quest giver, assume it was from accepting quest
        elseif DCI_DB.Auto_QuestAccept and DCI.QuestGiverGUID and DCI.QuestGiverGUID == UnitGUID("target") then
            DCI.DebugPrint("Assuming inv error was from accepting quest, setting flag to wait for quest window")
            DCI.QuestGaveError = true

        --no frames available, set flag to wait for window
        elseif DCI_DB.Auto_Loot then
            DCI.DebugPrint("Assuming inv error was from looting, setting flag to wait for loot window")
            DCI.InvErrWaitForLootFrame = true
            DCI.TraceWindow("inventory full: waiting for loot frame")
            DCI.QueueLootUpdate("inventory full")
        end
    end

    --events for automation on loot frame
    if DCI_DB.Auto_Loot then
        --when loot window shown, hook onto loot item to save clicked index
        if event == "LOOT_OPENED" then
            for i = 1,GetNumLootItems() do
                if _G['LootButton'..i] and not _G['LootButton'..i].DCIFunctionAltered then
                    DCI.DebugPrint("Setting hook on loot item click")
                    _G['LootButton'..i]:HookScript("OnClick", function(button)
                        LootFrame.DCI_LootIndexUserClick = button.slot
                        DCI.DebugPrint("LootButton click, force index but dont update window " .. LootFrame.DCI_LootIndexUserClick)
                    end)
                    _G['LootButton'..i].DCIFunctionAltered = true
                end
            end
        end

        --show with loot window, if we already saw the inv error, or if the window is open already
        if event == "LOOT_OPENED" and (DCI.InvErrWaitForLootFrame or (DCIFrame and DCIFrame:IsShown())) then
            DCI.TryShowLootWindow("LOOT_OPENED")
            DCI.QueueLootUpdate("LOOT_OPENED")
        end

        --hide with loot window closing
        if event == "LOOT_CLOSED" then
            if DCIFrame and DCIFrame:IsShown() and DCI.windowContext == WINDOW_CONTEXT_LOOT then
                if DCI_DB.Auto_Inventory and IsInventoryOpen() then
                    bagWindowAutoOpened = true
                    DCI.UpdateDCIFrame(false)
                else
                    DCI.DebugPrint("Closing with loot window. reset wait flag")
                    DCI.HideWindow("LOOT_CLOSED")
                end
            end
        end

        --if we leave combat and DCI.InvErrWaitForLootFrame is true
        if event == "PLAYER_REGEN_ENABLED" and DCI_DB.AllowInCombat == false and DCI.InvErrWaitForLootFrame then
            DCI.TryShowLootWindow("combat ended")
        end
    end

    if DCI_DB.Auto_LowSlots and event == "LOOT_OPENED" then
        DCI.QueueLootUpdate("low free slots")
    end
    if DCI_DB.Auto_LowSlots and not DCI_DB.Auto_Loot and event == "LOOT_CLOSED"
        and DCIFrame:IsShown() and DCI.windowContext == WINDOW_CONTEXT_LOOT then
        if DCI_DB.Auto_Inventory and IsInventoryOpen() then
            bagWindowAutoOpened = true
            DCI.UpdateDCIFrame(false)
        else
            DCI.HideWindow("LOOT_CLOSED")
        end
    end
    if DCI_DB.Auto_LowSlots and not DCI_DB.Auto_Loot and event == "PLAYER_REGEN_ENABLED"
        and DCI_DB.AllowInCombat == false and DCI.InvErrWaitForLootFrame then
        DCI.TryShowLootWindow("combat ended")
    end
    
    --events for automation on quest accept
    if DCI_DB.Auto_QuestAccept then
        --npc showing quest to accept
        if event == "QUEST_DETAIL" then
            --if wait flag was set & this was our saved questID & we dont have more space than last time
            if DCI.QuestGaveError
                and DCI.QuestID and DCI.QuestID == GetQuestID()
                and DCI.QuestNumBagSlots and DCI.CountFreeBagSlots() <= DCI.QuestNumBagSlots then

                --show the frame
                DCI.DebugPrint("Accepting same quest that gave inv error - show window")
                DCI.UpdateDCIFrame()
            else
                --otherwise set this as our quest & reset the flag
                DCI.QuestGiverGUID = UnitGUID("target")
                DCI.QuestID = GetQuestID()
                DCI.QuestNumBagSlots = DCI.CountFreeBagSlots()
                DCI.QuestGaveError = false
            end
        end
    end

    --events for automation on quest complete
    if DCI_DB.Auto_QuestComplete then
        --store the number of turn-in items on QUEST_PROGRESS
        if (event == "QUEST_PROGRESS" or event == "GOSSIP_SHOW") then
            DCI.QuestNumRequiredItems = GetNumQuestItems()
            DCI.DebugPrint("Saving num quest items at " .. event .. " : " .. DCI.QuestNumRequiredItems)
        end

        --show with quest complete, if there are more quest rewards than bag slots
        --(this isn't smart enough to know if any quest rewards could add to a stack in your bags, we just assume not)
        --also set a flag, and repeat this check on BAG_UPDATE if the flag is set
        if (event == "QUEST_COMPLETE" or (DCI.QuestRewardFlag and event == "BAG_UPDATE")) and QuestFrame and QuestFrame:IsShown() then
            --if we saved DCI.QuestNumRequiredItems at QUEST_PROGRESS, use it, otherwise it should be set here
            if not DCI.QuestNumRequiredItems then DCI.DebugPrint("QuestNumRequiredItems was not set earlier, getting value now") end
            DCI.QuestNumRequiredItems = DCI.QuestNumRequiredItems or GetNumQuestItems() or 0

            local QuestRewardRequiredSlots = ((GetNumQuestChoices() > 0) and 1 or 0) + GetNumQuestRewards() - (DCI.QuestNumRequiredItems or 0)
            DCI.QuestRewardFlag = false
            if QuestRewardRequiredSlots > 0 and QuestRewardRequiredSlots > DCI.CountFreeBagSlots() then
                DCI.DebugPrint("Quest complete, and there are more rewards than bag slots - show window and set quest flag")
                DCI.QuestRewardFlag = true
                DCI.UpdateDCIFrame()

            end
        end
    end

    --events for automation on trade
    if DCI_DB.Auto_Trade then
        if event == "TRADE_SHOW" or event == "TRADE_TARGET_ITEM_CHANGED" then
            --show/update the window if its open, or if bags are full
            local freeBagSlots = DCI.CountFreeBagSlots()
            if DCIFrame:IsShown() then
                DCI.DebugPrint("Trade window - Updating window since it's already visible")
                DCI.UpdateDCIFrame()
            else
                DCI.DebugPrint("Trade window - Comparing trade items VS bag slots")
                --or if there are more trade items than bag slots
                local numTradeItems = 0
                for i = 1, 7 do
                    local tradeItem,_,_,_,_ = GetTradeTargetItemInfo(i)
                    if tradeItem then
                        numTradeItems = numTradeItems + 1
                    end
                end

                if freeBagSlots < numTradeItems  then
                    DCI.DebugPrint(string.format("Trade window - %s trade items > %s bag slots, showing window", numTradeItems, freeBagSlots))
                    DCI.UpdateDCIFrame()
                end
            end
        end
    end

    --events for automation on mail
    if DCI_DB.Auto_Mail then
        --MAIL_FAILED might happen for other reasons, so check if bags are empty too
        if event == "MAIL_FAILED" and DCI.CountFreeBagSlots() == 0 then
            --show/update the window
            DCI.DebugPrint("Full inventory opening mail - showing window")
            DCI.UpdateDCIFrame()
        end

        --hook onto "Open All" button to force loot some items and cause inv error when bags are full, since it normally does nothing in that case
        if event == "MAIL_SHOW" and OpenAllMail and not OpenAllMail.DCIHooked then
            DCI.DebugPrint("Hooking onto Open All Mail button")
            OpenAllMail:HookScript("OnClick", function(self)
                if DCI.CountFreeBagSlots() == 0 then
                    DCI.DebugPrint("Force looting some items from Open All Mail click")
                    for i=1,12 do TakeInboxItem(1,i) end
                    for i=1,12 do TakeInboxItem(2,i) end
                    for i=1,12 do TakeInboxItem(3,i) end
                end
            end)
            OpenAllMail.DCIHooked = true
        end
    end

    --events for automation on roll
    if DCI_DB.Auto_Roll then
        --when need/greed roll window is shown
        if event == "START_LOOT_ROLL" then
            --if bags are full, show/update the window
            if DCI.CountFreeBagSlots() == 0 then
                DCI.DebugPrint("Full inventory on need/greed roll - showing window")
                DCI.UpdateDCIFrame()
            end
        end
    end
end

--create frame & load events
local DCIFrame = CreateMainFrame()
DCI.HideWindow("startup")
DCIFrame:RegisterEvent("ADDON_LOADED")
DCIFrame:SetScript("OnEvent", DCI.HandleEvent)

-- Forever's bag UI can change visibility without a BAG_OPEN/BAG_CLOSED event.
-- Watch the visible frames as a fallback for the frame callbacks above.
if isForever then
    local inventoryWatcher = CreateFrame("Frame", "DCIInventoryWatcher", UIParent)
    local elapsedSinceCheck = 0
    local lastInventoryOpen
    inventoryWatcher:SetScript("OnUpdate", function(_, elapsed)
        if not DCI_DB.Auto_Inventory then
            lastInventoryOpen = nil
            elapsedSinceCheck = 0
            return
        end
        elapsedSinceCheck = elapsedSinceCheck + elapsed
        if elapsedSinceCheck < 0.2 then return end
        elapsedSinceCheck = 0
        local inventoryOpen = IsInventoryOpen()
        if inventoryOpen ~= lastInventoryOpen then
            lastInventoryOpen = inventoryOpen
            DCI.TraceWindow("inventory visibility changed")
            DCI.QueueInventoryVisibilityUpdate()
        end
    end)
end
