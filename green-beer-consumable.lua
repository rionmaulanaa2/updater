-- Green Beer Consumable script
print("(Loaded) Green Beer Consumable script for GrowSoft")

PlayerStats = {
    PlacedBlocks = 0,
    HarvestedTrees = 1,
    SmashedBlocks = 2,
    GemsSpent = 3,
    ItemsDisposed = 4,
    ConsumablesUsed = 5,
    ProviderCollected = 6,
    MixedItems = 7,
    FishRevived = 8,
    StarshipFall = 9,
    GhostsCaptured = 10,
    MindGhostsCaptured = 11,
    AnomalizersBroken = 12,
    AnomHammerBroken = 13,
    AnomScytheBroken = 14,
    AnomBonesawBroken = 15,
    AnomAnomarodBroken = 16,
    AnomTrowelBroken = 17,
    AnomCultivatorBroken = 18,
    AnomScannerBroken = 19,
    AnomRollingPinsBroken = 20,
    SurgeriesDone = 21,
    GeigerFinds = 22,
    VillainsDefeated = 23,
    StartopianItemsFound = 24,
    FuelUsed = 25,
    FishTrained = 26,
    RoleUPItemsCrafted = 27,
    CookedItems = 28,
    FiresPutout = 29,
    AncestralUpgraded = 30,
    ChemsynthCreated = 31,
    MaladyCured = 32,
    GhostBossDefeated = 33,
    StarshipsLanded = 34,
    MagicEggsCollected = 35,
    EasterEggsFound = 36,
    UltraPinatasSmashed = 37,
    GrowganothFeed = 38,
    GrowchGifted = 39,
    RarityDonated = 40
}

StateFlags = {
    STATE_NO_CLIP = 0,
    STATE_DOUBLE_JUMP = 1,
    STATE_INVISIBLE = 2,
    STATE_NO_HAND = 3,
    STATE_NO_EYE = 4,
    STATE_NO_BODY = 5,
    STATE_DEVIL_HORNS = 6,
    STATE_GOLDEN_HALO = 7,
    STATE_FROZEN = 11,
    STATE_CURSED = 12,
    STATE_DUCT_TAPED = 13,
    STATE_CIGAR = 14,
    STATE_SHINING = 15,
    STATE_ZOMBIE = 16,
    STATE_RED_BODY = 17,
    STATE_HAUNTED_SHADOWS = 18,
    STATE_GEIGER_RADIATION = 19,
    STATE_SPOTLIGHT = 20,
    STATE_YELLOW_BODY = 21,
    STATE_PINEAPPLE_FLAG = 22,
    STATE_FLYING_PINEAPPLE = 23,
    STATE_SUPER_SUPPORTER_NAME = 24,
    STATE_SUPER_PINEAPPLE = 25,
    STATE_BUBBLE = 26,
    STATE_SOAKED = 27
};

local greenBeerModData = {
    modID = -1100, -- Make sure it never duplicates and it has to be negative
    modName = "Envious",
    onAddMessage = "It ain't easy being you.",
    onRemoveMessage = "Healthy color restored.",
    iconID = 540,

    -- New things
    changeSkin = {52, 235, 107, 255}, -- RGBA
    modState = {StateFlags.STATE_DOUBLE_JUMP, StateFlags.STATE_SHINING}, -- (You can remove it if u want, its just example)
    changeMovementSpeed = 500, -- Add's 50 points to movement speed, you can use negative numbers too or leave it 0
    changeAcceleration = 0,
    changeGravity = 0,
    changePunchStrength = 0,
    changeBuildRange = 0,
    changePunchRange = 0,
    changeWaterMovementSpeed = 0
}

local greenBeerModID = registerLuaPlaymod(greenBeerModData)

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID == 540 then
        if clickedPlayer == nil then
            player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
            return true
        end
        if player:changeItem(itemID, -1, 0) then
            clickedPlayer:addMod(greenBeerModID, 10)
            world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
            player:updateStats(world, PlayerStats.ConsumablesUsed, 1)
            world:updateClothing(clickedPlayer)
            return true
        end
        return true
    end
    return false
end)
