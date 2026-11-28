local _, DCI = ...
local L = DCI.L

DCI.SOUL_SHARD_ITEM_ID = 6265
-- Bag family of soul bags; emptying one never makes room for ordinary loot.
DCI.SOUL_BAG_FAMILY = 4

-- Mists replaced Soul Shard items with a power resource.
local _, _, _, interfaceVersion = GetBuildInfo()
local shardsAreItems = interfaceVersion < 40000

local pendingCleanup
local awaitingConfirmation
-- A deleted shard can stay in its slot until the next BAG_UPDATE for that bag;
-- counting it again would delete one shard too many.
local pendingDeletions = {}

function DCI.SoulShardsSupported()
    return shardsAreItems
end

function DCI.IsSoulShardLimitActive()
    return shardsAreItems and DCI.db.SoulShardLimitEnabled == true
        and not DCI.IsItemIgnored(DCI.SOUL_SHARD_ITEM_ID)
end

function DCI.IsSoulShardAutoDeleteActive()
    return DCI.IsSoulShardLimitActive() and DCI.db.SoulShardAutoDelete == true
end

function DCI.IsSoulShardPendingDeletion(bag, slot)
    return pendingDeletions[bag] ~= nil and pendingDeletions[bag][slot] == true
end

-- Shards outside soul bags, the only ones the limit counts.
local function GetCountedSoulShards()
    local shards = {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS) do
        local _, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if bagFamily ~= DCI.SOUL_BAG_FAMILY then
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == DCI.SOUL_SHARD_ITEM_ID and not DCI.IsSoulShardPendingDeletion(bag, slot) then
                    table.insert(shards, { bag = bag, slot = slot, isLocked = info.isLocked,
                        hyperlink = info.hyperlink, stackCount = info.stackCount or 1 })
                end
            end
        end
    end
    return shards
end

function DCI.CountExtraSoulShards()
    if not DCI.IsSoulShardLimitActive() then return 0 end
    local total = 0
    for _, shard in ipairs(GetCountedSoulShards()) do total = total + shard.stackCount end
    return math.max(0, total - DCI.db.SoulShardLimit)
end

local function DeleteExtraSoulShards()
    local remaining = DCI.CountExtraSoulShards()
    local deleted, blocked = 0, false
    for _, shard in ipairs(GetCountedSoulShards()) do
        if remaining <= 0 then break end
        -- Never delete a stack that would take the count below the limit.
        if shard.stackCount <= remaining then
            local current = C_Container.GetContainerItemInfo(shard.bag, shard.slot)
            if shard.isLocked or not current or current.isLocked or current.itemID ~= DCI.SOUL_SHARD_ITEM_ID
                or GetCursorInfo() ~= nil
                or not DCI.DeleteBagSlotItem(shard.bag, shard.slot, DCI.SOUL_SHARD_ITEM_ID) then
                blocked = true
            else
                pendingDeletions[shard.bag] = pendingDeletions[shard.bag] or {}
                pendingDeletions[shard.bag][shard.slot] = true
                deleted = deleted + shard.stackCount
                remaining = remaining - shard.stackCount
            end
        end
    end
    return deleted, blocked
end

-- Blocked passes retry on ITEM_LOCK_CHANGED, PLAYER_REGEN_ENABLED, or the next BAG_UPDATE.
function DCI.RunSoulShardCleanup()
    if awaitingConfirmation or not DCI.IsSoulShardAutoDeleteActive() then return 0 end
    if UnitAffectingCombat("player") or GetCursorInfo() ~= nil then return 0 end
    local deleted = DeleteExtraSoulShards()
    if deleted > 0 and DCI.db.SoulShardAnnounce then
        DCI.DebugPrint(string.format(L["Deleted extra Soul Shards: %d. Keeping %d."], deleted, DCI.db.SoulShardLimit),
            DCI.DEBUG_OUTPUT_FORCED)
    end
    return deleted
end

function DCI.QueueSoulShardCleanup()
    if not DCI.IsSoulShardAutoDeleteActive() then return end
    local request = {}
    pendingCleanup = request
    C_Timer.After(0, function()
        if pendingCleanup ~= request then return end
        pendingCleanup = nil
        DCI.RunSoulShardCleanup()
    end)
end

function DCI.HandleSoulShardBagUpdate(bag)
    if bag ~= nil then pendingDeletions[bag] = nil end
    DCI.QueueSoulShardCleanup()
end

-- Settings and profile changes can delete many shards at once, so they ask first.
-- Declining turns automatic deletion off; otherwise the next bag change would delete them anyway.
function DCI.RequestSoulShardCleanup()
    if awaitingConfirmation or not DCI.IsSoulShardAutoDeleteActive() then return end
    local extra = DCI.CountExtraSoulShards()
    if extra == 0 then return end
    awaitingConfirmation = true
    pendingCleanup = nil
    StaticPopupDialogs["DCI_SOUL_SHARD_CLEANUP"] = {
        text = L["Delete extra Soul Shards now: %d?\n\nFuture extra shards will be deleted automatically. Choose No to turn automatic deletion off."],
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            awaitingConfirmation = false
            DCI.RunSoulShardCleanup()
        end,
        OnCancel = function()
            awaitingConfirmation = false
            DCI.db.SoulShardAutoDelete = false
            if DCI.UpdateSoulShardSettings then DCI.UpdateSoulShardSettings() end
            DCI.RegisterFrameEvents()
        end,
        OnHide = function() awaitingConfirmation = false end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        showAlert = true,
    }
    StaticPopup_Show("DCI_SOUL_SHARD_CLEANUP", extra)
end

function DCI.CancelSoulShardCleanupRequest()
    pendingCleanup = nil
    if awaitingConfirmation then StaticPopup_Hide("DCI_SOUL_SHARD_CLEANUP") end
    awaitingConfirmation = false
end
