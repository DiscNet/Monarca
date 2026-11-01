-- Monarca / Live Marketplace emote discovery v0.8.9
-- Finds Roblox AND UGC EmoteAnimation catalog assets, with on-demand pages.
-- Discovery never bypasses asset ownership, permissions or publishing rules.
local AvatarEditorService = game:GetService("AvatarEditorService")

local Marketplace = {}
local activePages = nil
local activeQuery = nil

function Marketplace:enable()
    return true
end

function Marketplace:disable()
    activePages = nil
    activeQuery = nil
end

local function normalizedName(value, maximum)
    return tostring(value or ""):sub(1, maximum or 90)
end

local function normalize(page)
    local results = {}
    for _, item in ipairs(page) do
        -- Do not filter on creator: users and groups may publish UGC.
        if item.ItemType == "Asset" and item.AssetType == "EmoteAnimation" then
            local assetId = tonumber(item.Id)
            if assetId and assetId > 0 then
                local id = string.format("%.0f", assetId)
                local creator = normalizedName(item.CreatorName, 45)
                local isRoblox = creator:lower() == "roblox"
                table.insert(results, {
                    id = id,
                    catalogId = id,
                    name = normalizedName(item.Name, 90),
                    creator = creator,
                    group = isRoblox and "Marketplace · Roblox" or "UGC · " .. creator,
                    aliases = "marketplace emote ugc " .. creator,
                    marketplace = true,
                    owned = item.Owned == true,
                })
            end
        end
    end
    return results
end

function Marketplace:search(query, nextPage)
    query = normalizedName(query, 70)
    nextPage = nextPage == true

    if not nextPage or query ~= activeQuery or not activePages then
        local params = CatalogSearchParams.new()
        params.AssetTypes = {Enum.AvatarAssetType.EmoteAnimation}
        params.SearchKeyword = query
        params.IncludeOffSale = true
        params.Limit = 30
        local pages = AvatarEditorService:SearchCatalogAsync(params)
        activePages, activeQuery = pages, query
    elseif activePages.IsFinished then
        return {}, false
    end

    if nextPage and activePages and not activePages.IsFinished then
        activePages:AdvanceToNextPageAsync()
    end

    local page = activePages:GetCurrentPage()
    local matches = normalize(page)
    return matches, not activePages.IsFinished
end

return Marketplace
