---@class PvpAssistant
local PvpAssistant = select(2, ...)

local GGUI = PvpAssistant.GGUI
local GUTIL = PvpAssistant.GUTIL
local f = GUTIL:GetFormatter()

---@class PvpAssistant.Util
PvpAssistant.UTIL = {}

--- also for healing
function PvpAssistant.UTIL:FormatDamageNumber(number)
    if number >= 1000000000 then
        return GUTIL:Round(number / 1000000000, 2) .. "B"
    end
    if number >= 1000000 then
        return GUTIL:Round(number / 1000000, 2) .. "M"
    end
    if number >= 1000 then
        return GUTIL:Round(number / 1000) .. "K"
    end

    return tostring(number)
end

---@param text string
---@param rating number
function PvpAssistant.UTIL:ColorByRating(text, rating)
    if rating >= 2200 then
        return f.l(text)
    elseif rating >= 1800 then
        return f.e(text)
    else
        return f.white(text)
    end
end

---@param unit UnitId
---@return PlayerUID playerUID
function PvpAssistant.UTIL:GetPlayerUIDByUnit(unit)
    local playerName, playerRealm = UnitNameUnmodified(unit)
    playerRealm = playerRealm or GetNormalizedRealmName()

    return playerName .. "-" .. playerRealm
end

---@param unit UnitId
---@return number? specializationID
function PvpAssistant.UTIL:GetSpecializationIDByUnit(unit)
    local info = C_TooltipInfo.GetUnit(unit)

    for _, line in ipairs(info.lines) do
        local specText = line.leftText
        local specID = PvpAssistant.SPEC_LOOKUP:LookUp(specText)
        if specID then
            return specID
        end
    end

    return nil
end

function PvpAssistant.UTIL:GetMapAbbreviation(mapName)
    local custom = PvpAssistant.CONST.MAP_ABBREVIATIONS[mapName]

    if custom then return custom end

    local words = strsplittable(" ", mapName)

    local firstLetters = GUTIL:Map(words, function(word)
        return word:sub(1, 1):upper()
    end)

    return table.concat(firstLetters, "")
end

---@param rating number
---@return string?
function PvpAssistant.UTIL:GetIconByRating(rating)
    local rankingIcon
    for _, ratingData in ipairs(PvpAssistant.CONST.RATING_ICON_MAP) do
        if rating >= ratingData.rating then
            rankingIcon = ratingData.icon
        end
    end
    return rankingIcon
end

---@param pvpMode PvpAssistant.Const.PVPModes
---@param data table
---@return InspectArenaData inspectArenaData
function PvpAssistant.UTIL:ConvertInspectArenaData(pvpMode, data)
    ---@type InspectArenaData
    local inspectArenaData = {
        pvpMode = pvpMode,
        rating = data[1],
        seasonPlayed = data[2],
        seasonWon = data[3],
        weeklyPlayed = data[4],
        weeklyWon = data[5],
    }
    return inspectArenaData
end

---@param parent Frame
---@param anchorPoints GGUI.AnchorPoint[]
---@param scale number?
---@return GGUI.Text, GGUI.Text
function PvpAssistant.UTIL:CreateLogo(parent, anchorPoints, scale)
    scale = scale or 1
    parent.titleLogo = GGUI.Text {
        parent = parent,
        anchorPoints = anchorPoints,
        text = GUTIL:ColorizeText(" PvpAssistant", GUTIL.COLORS.LEGENDARY),
        scale = 1.7 * scale,
    }

    parent.logoIcon = GGUI.Text {
        parent = parent,
        anchorPoints = { { anchorParent = parent.titleLogo.frame, anchorA = "RIGHT", anchorB = "LEFT" }, offsetY = 2 },
        text = PvpAssistant.MEDIA:GetAsTextIcon(PvpAssistant.MEDIA.IMAGES.LOGO_1024, 0.028 * scale)
    }

    return parent.titleLogo, parent.logoIcon
end

---@class PvpAssistant.ClassFilterFrameOptions
---@field parent Frame
---@field anchorPoint GGUI.AnchorPoint?
---@field clickCallback? fun(ClassFile, boolean)

---@param options PvpAssistant.ClassFilterFrameOptions
---@return GGUI.Frame classFilterFrame
---@return table<ClassFile, boolean> activeClassFiltersTable
function PvpAssistant.UTIL:CreateClassFilterFrame(options)
    local activeClassFiltersTable = {}
    local anchorPoint = options.anchorPoint or {}
    local parent = options.parent

    ---@class PvpAssistant.History.ClassFilterFrame : GGUI.Frame
    local classFilterFrame = GGUI.Frame {
        parent = parent, anchorParent = anchorPoint.anchorParent or parent,
        anchorA = anchorPoint.anchorA or "TOP", anchorB = anchorPoint.anchorB or "TOP", backdropOptions = PvpAssistant.CONST.CLASS_FILTER_FRAME_BACKDROP,
        sizeX = 715, sizeY = 100, offsetY = anchorPoint.offsetY or 0, offsetX = anchorPoint.offsetX or 0
    }

    classFilterFrame.title = GGUI.Text {
        parent = classFilterFrame.frame, anchorParent = classFilterFrame.content,
        anchorA = "TOP", anchorB = "TOP", text = "Class Filtering", offsetY = -15,
        fontOptions = {
            fontFile = PvpAssistant.CONST.FONT_FILES.ROBOTO,
            height = 15,
        },
        tooltipOptions = {
            owner = classFilterFrame.frame,
            anchor = "ANCHOR_CURSOR",
            text = f.white("Toggle Class Filters off and on."
                .. "\n\nSHIFT+" .. CreateAtlasMarkup(PvpAssistant.CONST.ATLAS.LEFT_MOUSE_BUTTON, 15, 20) .. ": Filter out everything else"
                .. "\n\nALT+" .. CreateAtlasMarkup(PvpAssistant.CONST.ATLAS.LEFT_MOUSE_BUTTON, 15, 20) .. ": Filter in everything else"),
        },
    }

    classFilterFrame.frame:SetFrameLevel(parent:GetFrameLevel() + 10)

    ---@type GGUI.ClassIcon[]
    classFilterFrame.classFilterButtons = {}

    local classFilterIconSize = 35
    local classFilterIconOffsetX = 45
    local classFilterIconOffsetY = -10
    local classFilterIconSpacingX = 14
    local function CreateClassFilterIcon(classFile, anchorParent, offX, offY, anchorA, anchorB)
        local classFilterIcon = GGUI.ClassIcon {
            sizeX = classFilterIconSize, sizeY = classFilterIconSize,
            parent = classFilterFrame.content, anchorParent = anchorParent,
            initialClass = classFile, offsetX = offX, offsetY = offY, anchorA = anchorA, anchorB = anchorB,
            showTooltip = true,
        }

        classFilterIcon.frame:SetScript("OnClick", function()
            if IsShiftKeyDown() then
                -- if shift clicked -> toggle all off except current class
                for _, classIcon in ipairs(classFilterFrame.classFilterButtons) do
                    if classIcon.class == classFile then
                        classIcon:Saturate()
                        activeClassFiltersTable[classIcon.class] = false
                    else
                        classIcon:Desaturate()
                        activeClassFiltersTable[classIcon.class] = true
                    end
                end
                if options.clickCallback then
                    options.clickCallback(classFile, false)
                end
            elseif IsAltKeyDown() then
                -- if alt clicked -> toggle all on except current class
                for _, classIcon in ipairs(classFilterFrame.classFilterButtons) do
                    if classIcon.class == classFile then
                        classIcon:Desaturate()
                        activeClassFiltersTable[classIcon.class] = true
                    else
                        classIcon:Saturate()
                        activeClassFiltersTable[classIcon.class] = false
                    end
                end
                if options.clickCallback then
                    options.clickCallback(classFile, false)
                end
            else
                if not activeClassFiltersTable[classFile] then
                    activeClassFiltersTable[classFile] = true
                    classFilterIcon:Desaturate()
                    -- reload list with new filters
                    if options.clickCallback then
                        options.clickCallback(classFile, true)
                    end
                else
                    activeClassFiltersTable[classFile] = nil
                    classFilterIcon:Saturate()
                    -- reload list with new filters
                    if options.clickCallback then
                        options.clickCallback(classFile, false)
                    end
                end
            end
        end)

        return classFilterIcon
    end
    local t = {}
    FillLocalizedClassList(t)
    local classFiles = GUTIL:Map(t, function(_, classFile)
        -- ignore hidden test class or whatever this is
        if classFile == "Adventurer" then
            return nil
        end
        return classFile
    end)
    local currentAnchor = classFilterFrame.frame
    for i, classFile in pairs(classFiles) do
        local anchorB = "RIGHT"
        local offX = classFilterIconSpacingX
        local offY = 0
        if i == 1 then
            anchorB = "LEFT"
            offX = classFilterIconOffsetX
            offY = classFilterIconOffsetY
        end
        local classFilterIcon = CreateClassFilterIcon(classFile, currentAnchor, offX, offY, "LEFT", anchorB)
        tinsert(classFilterFrame.classFilterButtons, classFilterIcon)
        currentAnchor = classFilterIcon.frame
    end

    return classFilterFrame, activeClassFiltersTable
end
