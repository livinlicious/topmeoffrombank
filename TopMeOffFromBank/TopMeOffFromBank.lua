local verbose = nil
local debugLog = {}
local startingBagCounts = {}  -- Track bag counts when bank opened

local function info(msg)
    local colored = "|cffffff00<TopMeOffFromBank> " .. msg .. "|r"
    DEFAULT_CHAT_FRAME:AddMessage(colored);
    table.insert(debugLog, msg)
end

local function printWithdrawnSummary()
    -- Compare current bag counts with starting counts
    local currentCounts = CountBagItems(bankItemsWanted)

    for itemLink, startCount in pairs(startingBagCounts) do
        local currentCount = currentCounts[itemLink]
        local difference = currentCount - startCount

        if difference > 0 then
            info(itemLink .. ' withdrew ' .. difference)
        end
    end
end

local function showDebugWindow()
    if not TopMeOffDebugFrame then
        -- Create frame
        local frame = CreateFrame("Frame", "TopMeOffDebugFrame", UIParent)
        frame:SetWidth(600)
        frame:SetHeight(400)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 }
        })
        frame:SetBackdropColor(0, 0, 0, 0.9)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function() this:StartMoving() end)
        frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", frame, "TOP", 0, -10)
        title:SetText("Debug Log (Ctrl+A to select, Ctrl+C to copy)")

        -- Close button
        local closeBtn = CreateFrame("Button", nil, frame)
        closeBtn:SetWidth(20)
        closeBtn:SetHeight(20)
        closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
        closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
        closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        closeBtn:SetScript("OnClick", function() frame:Hide() end)

        -- EditBox
        local editbox = CreateFrame("EditBox", "TopMeOffDebugEditBox", frame)
        editbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -40)
        editbox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)
        editbox:SetMultiLine(true)
        editbox:SetAutoFocus(false)
        editbox:SetFontObject(GameFontNormalSmall)
        editbox:SetScript("OnEscapePressed", function() frame:Hide() end)

        frame.editbox = editbox
    end

    -- Populate with debug log
    local logText = table.concat(debugLog, "\n")
    TopMeOffDebugFrame.editbox:SetText(logText)
    TopMeOffDebugFrame.editbox:HighlightText(0, string.len(logText))
    TopMeOffDebugFrame:Show()
    info("Debug window opened - use Ctrl+A then Ctrl+C to copy")
end

local function print_usage()
    info('usage: ')
    info('tmob add <itemlink> <amount> - shift-click an item for an item link')
    info('tmob ls - see all configured items')
    info('tmob ls need - see the items needed from the bank')
    info('tmob ls have - see the items you have from the list')
    info('tmob del <itemlink> - remove 1 item from the list. shift-click an item for an item link.')
    info('tmob reset - delete all items from the list')
    info('tmob debug - show debug log window (copyable)')
end

local function compare_item_names(linka, linkb)
    local _, _, namea = string.find(linka, "|c%x+|Hitem:%d+:%d+:%d+:%d+|h%[(.-)%]|h|r")
    local _, _, nameb = string.find(linkb, "|c%x+|Hitem:%d+:%d+:%d+:%d+|h%[(.-)%]|h|r")
    return namea < nameb
end

local function is_table_empty(table)
    local next = next
    return next(table) == nil
end

bankItemsWanted = bankItemsWanted or {}

local gfind = string.gmatch or string.gfind

do
    SLASH_TOPMEOFFBANK1 = '/tmob'
    SlashCmdList["TOPMEOFFBANK"] = function(message)
        local commandlist = { }
        local command

        for command in gfind(message, "[^ ]+") do
            table.insert(commandlist, command)
        end

        if commandlist[1] == nil then
            print_usage()
            return
        end

        commandlist[1] = string.lower(commandlist[1])

        if commandlist[1] == 'add' then

            local cmdstring = table.concat(commandlist, " ", 2, table.getn(commandlist))

            local _, _, itemLink = string.find(cmdstring, "(|c%x+|Hitem:%d+:%d+:%d+:%d+|h%[.-%]|h|r)")
            if not itemLink then
                info('an item link is required. use shift-click')
                return
            end

            local amount = tonumber(commandlist[table.getn(commandlist)])
            if amount == nil then
                info('the amount should be a number')
                return
            end
            bankItemsWanted[itemLink] = amount
            info('added ' .. itemLink .. ' ' .. amount)
        elseif commandlist[1] == 'del' then
            local cmdstring = table.concat(commandlist, " ", 2, table.getn(commandlist))

            local _, _, itemLink = string.find(cmdstring, "(|c%x+|Hitem:%d+:%d+:%d+:%d+|h%[.-%]|h|r)")
            if not itemLink then
                info('an item link is required. use shift-click')
                return
            end

            bankItemsWanted[itemLink] = nil
        elseif commandlist[1] == 'reset' then
            bankItemsWanted = {}
            info('removed all items')
        elseif commandlist[1] == 'ls' then
            if is_table_empty(bankItemsWanted) then
                info('nothing added yet')
                return
            end
            local showNeed = not (string.lower(commandlist[2] or '') == 'have')
            local showHave = not (string.lower(commandlist[2] or '') == 'need')
            local itemsOwned = CountBagItems(bankItemsWanted)

            local sortedKeys = {}
            for k in pairs(bankItemsWanted) do
                table.insert(sortedKeys, k)
            end
            table.sort(sortedKeys, compare_item_names)

            local count = 0
            local red = '|cffff5179'
            local green = '|cff1eff00'
            for _, k in ipairs(sortedKeys) do
                local v = bankItemsWanted[k]
                local need = itemsOwned[k] < v
                if need and showNeed then
                    info(k .. ' ' .. v .. ' have ' .. red .. itemsOwned[k])
                    count = count + 1
                elseif not need and showHave then
                    info(k .. ' ' .. v .. ' have ' .. green .. itemsOwned[k])
                    count = count + 1
                end
            end
            if count == 0 then
                info('You do not ' .. (showNeed and 'need anything from' or 'have anything on') .. ' your list!')
            end
        elseif commandlist[1] == 'debug' then
            showDebugWindow()
        else
            print_usage()
        end
    end
end

local withdrawQueue = {}
local currentQueueIndex = 1
local lastWithdrawTime = 0
local WITHDRAW_DELAY = 0.2  -- 200ms between each withdrawal (give Bagshui more time)
local recheckScheduled = false
local recheckTime = 0
local recheckCount = 0
local MAX_RECHECKS = 10  -- Keep trying up to 10 times

function TopMeOffFromBank_OnLoad()
    this:RegisterEvent("BANKFRAME_OPENED");
    this:RegisterEvent("BANKFRAME_CLOSED");
end

function TopMeOffFromBank_OnEvent()
    if verbose then info('saw event ' .. event) end
    if event == "BANKFRAME_OPENED" then
        -- Wait a bit for bags to settle, then build queue
        withdrawQueue = {}
        currentQueueIndex = 1
        recheckCount = 0

        -- Capture starting bag counts
        startingBagCounts = CountBagItems(bankItemsWanted)

        lastWithdrawTime = GetTime() + 0.5  -- Wait 500ms before starting
        BuildWithdrawQueue();
    elseif event == "BANKFRAME_CLOSED" then
        withdrawQueue = {}
        currentQueueIndex = 1
        recheckScheduled = false
        recheckCount = 0
    end
end

function TopMeOffFromBank_OnUpdate()
    local now = GetTime()

    -- Process withdrawals
    if table.getn(withdrawQueue) > 0 and currentQueueIndex <= table.getn(withdrawQueue) then
        if now >= lastWithdrawTime then
            if verbose then info('Processing withdrawal ' .. currentQueueIndex .. ' of ' .. table.getn(withdrawQueue)) end
            ProcessNextWithdrawal()
            lastWithdrawTime = now + WITHDRAW_DELAY

            -- If we just finished the queue, schedule a recheck
            if currentQueueIndex > table.getn(withdrawQueue) and table.getn(withdrawQueue) > 0 then
                recheckScheduled = true
                recheckTime = now + 1.5  -- Wait 1.5 seconds for bags to update (Bagshui reorganization)
                if verbose then info('Queue finished, scheduling recheck in 1.5 seconds') end
            end
        end
    end

    -- Recheck if scheduled
    if recheckScheduled and now >= recheckTime then
        recheckScheduled = false
        recheckCount = recheckCount + 1

        if recheckCount > MAX_RECHECKS then
            -- Print summary before giving up
            printWithdrawnSummary()
            info('Max rechecks reached. Some items may need another bank visit.')
            return
        end

        if verbose then info('Rechecking if more items needed... (attempt ' .. recheckCount .. '/' .. MAX_RECHECKS .. ')') end
        BuildWithdrawQueue()

        -- If the new queue is empty, we're done
        if table.getn(withdrawQueue) == 0 then
            -- Print summary of what we withdrew (only once at the end)
            printWithdrawnSummary()

            -- Trigger Bagshui restack if available
            if Bagshui and Bagshui.components then
                if Bagshui.components["Bank"] and Bagshui.components["Bank"].Restack then
                    if verbose then info('Restacking bank...') end
                    Bagshui.components["Bank"]:Restack()
                end
                if Bagshui.components["Bags"] and Bagshui.components["Bags"].Restack then
                    if verbose then info('Restacking bags...') end
                    Bagshui.components["Bags"]:Restack()
                end
            end
        else
            -- Reset queue index to start processing the new queue
            currentQueueIndex = 1
            lastWithdrawTime = now + WITHDRAW_DELAY
        end
    end
end

function CountBagItems(itemsWanted)
    local itemsOwned = {};
    for name, value in pairs(itemsWanted) do
        itemsOwned[name] = 0
    end

    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) do
            local itemLink, itemCount = GetBagItemAndCount(bagID, slot);

            if itemLink then
                if itemsOwned[itemLink] ~= nil then
                    itemsOwned[itemLink] = itemsOwned[itemLink] + itemCount
                end
            end
        end
    end
    return itemsOwned
end

function CountBankItems(itemsWanted)
    local itemsInBank = {};
    for name, value in pairs(itemsWanted) do
        itemsInBank[name] = 0
    end

    -- Count items in bank slots (NUM_BANKGENERIC_SLOTS = 24 in vanilla)
    for slot = 1, 24 do
        local itemLink = GetContainerItemLink(-1, slot)
        if itemLink then
            local _, itemCount = GetContainerItemInfo(-1, slot)
            if not itemCount then
                itemCount = 1
            end
            if itemsInBank[itemLink] ~= nil then
                itemsInBank[itemLink] = itemsInBank[itemLink] + itemCount
            end
        end
    end

    -- Count items in bank bags (bags 5-10)
    for bagID = 5, 10 do
        for slot = 1, GetContainerNumSlots(bagID) do
            local itemLink = GetContainerItemLink(bagID, slot)
            if itemLink then
                local _, itemCount = GetContainerItemInfo(bagID, slot)
                if not itemCount then
                    itemCount = 1
                end
                if itemsInBank[itemLink] ~= nil then
                    itemsInBank[itemLink] = itemsInBank[itemLink] + itemCount
                end
            end
        end
    end

    return itemsInBank
end

function FindFreeBagSlot()
    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) do
            local itemLink = GetContainerItemLink(bagID, slot)
            if not itemLink then
                return bagID, slot
            end
        end
    end
    return nil, nil
end

function BuildWithdrawQueue()
    withdrawQueue = {}
    local itemsOwned = CountBagItems(bankItemsWanted)
    local itemsInBank = CountBankItems(bankItemsWanted)

    if verbose then info('=== Bank Scan ===') end

    local totalNeeded = 0
    for itemLink, wantedAmount in pairs(bankItemsWanted) do
        local have = itemsOwned[itemLink]
        local inBank = itemsInBank[itemLink]
        if verbose then info(itemLink .. ': want=' .. wantedAmount .. ' have=' .. have .. ' bank=' .. inBank) end

        if itemsOwned[itemLink] < wantedAmount then
            local neededCount = wantedAmount - itemsOwned[itemLink]
            local availableInBank = itemsInBank[itemLink]

            if availableInBank > 0 then
                local toWithdraw = math.min(neededCount, availableInBank)
                totalNeeded = totalNeeded + 1

                -- Find all stacks of this item in bank
                for slot = 1, 24 do
                    if toWithdraw <= 0 then break end
                    local link = GetContainerItemLink(-1, slot)
                    if link == itemLink then
                        local _, itemCount = GetContainerItemInfo(-1, slot)
                        if not itemCount then itemCount = 1 end
                        local withdrawAmount = math.min(itemCount, toWithdraw)
                        table.insert(withdrawQueue, {
                            itemLink = itemLink,
                            bankBag = -1,
                            bankSlot = slot,
                            amount = withdrawAmount,
                            needsSplit = withdrawAmount < itemCount
                        })
                        toWithdraw = toWithdraw - withdrawAmount
                    end
                end

                -- Check bank bags
                for bagID = 5, 10 do
                    if toWithdraw <= 0 then break end
                    for slot = 1, GetContainerNumSlots(bagID) do
                        if toWithdraw <= 0 then break end
                        local link = GetContainerItemLink(bagID, slot)
                        if link == itemLink then
                            local _, itemCount = GetContainerItemInfo(bagID, slot)
                            if not itemCount then itemCount = 1 end
                            local withdrawAmount = math.min(itemCount, toWithdraw)
                            table.insert(withdrawQueue, {
                                itemLink = itemLink,
                                bankBag = bagID,
                                bankSlot = slot,
                                amount = withdrawAmount,
                                needsSplit = withdrawAmount < itemCount
                            })
                            toWithdraw = toWithdraw - withdrawAmount
                        end
                    end
                end
            end
        end
    end

    if verbose then info('Queue: ' .. table.getn(withdrawQueue) .. ' withdrawals queued for ' .. totalNeeded .. ' items') end
end

function ProcessNextWithdrawal()
    if currentQueueIndex > table.getn(withdrawQueue) then
        if verbose then info('Queue completed') end
        return
    end

    -- Clear cursor if something is stuck on it
    if CursorHasItem() then
        if verbose then info('Clearing stuck cursor') end
        ClearCursor()
    end

    local withdrawal = withdrawQueue[currentQueueIndex]
    currentQueueIndex = currentQueueIndex + 1

    if verbose then info('Withdrawing from bag=' .. withdrawal.bankBag .. ' slot=' .. withdrawal.bankSlot .. ' amount=' .. withdrawal.amount) end

    -- Pick up from bank
    if withdrawal.needsSplit then
        if verbose then info('Splitting stack') end
        SplitContainerItem(withdrawal.bankBag, withdrawal.bankSlot, withdrawal.amount)
    else
        if verbose then info('Picking up full stack') end
        PickupContainerItem(withdrawal.bankBag, withdrawal.bankSlot)
    end

    if verbose then info('Cursor has item: ' .. tostring(CursorHasItem())) end

    -- Place in bag - find empty slot ONLY (don't try to stack full stacks)
    if CursorHasItem() then
        local placed = false

        -- Find empty slot (check fresh each attempt)
        for bagID = 0, 4 do
            if placed then break end
            for slot = 1, GetContainerNumSlots(bagID) do
                if placed then break end
                -- Check RIGHT NOW if this slot is empty
                local currentLink = GetContainerItemLink(bagID, slot)
                if not currentLink then
                    PickupContainerItem(bagID, slot)
                    if not CursorHasItem() then
                        placed = true
                        if verbose then info('Placed at bag=' .. bagID .. ' slot=' .. slot) end
                    end
                end
            end
        end

        -- Check if placement worked
        if placed then
            if verbose then info(withdrawal.itemLink .. ' withdrew ' .. withdrawal.amount) end
        else
            ClearCursor()
            if verbose then info('Failed to place ' .. withdrawal.itemLink) end
        end
    else
        if verbose then info('Failed to pick up ' .. withdrawal.itemLink) end
    end
end

function GetBagItemAndCount(bag, slot)
    local texture, itemCount = GetContainerItemInfo(bag, slot);

    if not itemCount then
        itemCount = 0
    end

    local itemLink = GetContainerItemLink(bag, slot)

    return itemLink, itemCount
end
