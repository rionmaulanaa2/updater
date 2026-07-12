-- achievment script
print("(Loaded) achievment script for GTPS Cloud")

local levelMilestones = {
    {130, 901, 1, 10000, "Determined", "Your intention is determined to become the strongest."},
    {140, 902, 2, 12000, "Fast Learner", "You learn very fast!"},
    {155, 903, 3, 15000, "Rising Star", "Your light begins to be seen by other players."},
    {170, 904, 4, 20000, "Ambitious", "Great ambitions begin to grow within you."},
    {190, 905, 5, 25000, "Hard Worker", "Hard work will never betray the results."},
    {210, 906, 6, 30000, "Adept", "Your basic technique is very mature now."},
    {235, 907, 7, 40000, "Skilled Hero", "A talented hero who is starting to be respected."},
    {260, 908, 8, 55000, "Silver Fighter", "Silver power flows in your veins."},
    {290, 909, 9, 75000, "Vanguard", "You are the vanguard in battle."},
    {330, 910, 10, 100000, "Golden Soul", "Your soul shines like pure gold."},
    {380, 911, 12, 150000, "Platinum Knight", "A guardian knight with impenetrable armor."},
    {440, 912, 15, 200000, "Diamond Heart", "Your determination is as hard as diamond, it cannot be broken."},
    {510, 913, 18, 300000, "Master Builder", "Your creativity and level go hand in hand."},
    {600, 914, 21, 450000, "Warlord", "One command from you can shake the world."},
    {700, 915, 24, 600000, "High Ancestor", "The ancient legacy is now in your hands."},
    {850, 916, 27, 850000, "Mythical Hunter", "Chasing legends to the ends of the earth."},
    {1000, 917, 30, 1200000, "The Immortal", "Time is no longer an opponent to your existence."},
    {1250, 918, 33, 1800000, "Sage of Growfax", "Your wisdom goes beyond the bounds of knowledge."},
    {1600, 919, 36, 2500000, "Abyssal King", "Lord of the deepest darkness."},
    {2000, 920, 40, 3500000, "Solar Deity", "The light of the sun is subject to your will."},
    {2600, 921, 44, 5000000, "Galaxy Wanderer", "Explore the galaxy in just a blink of an eye."},
    {3300, 922, 48, 7500000, "Constellation Master", "The stars form your name in the sky."},
    {4200, 923, 52, 10000000, "Dimension Breaker", "The walls of reality are shattered by your power."},
    {5200, 924, 56, 15000000, "Soul Reaper", "The soul taker feared by the whole world."},
    {6300, 925, 60, 20000000, "Ancient Dragon", "An ancient dragon awakened from a long sleep."},
    {7500, 926, 64, 30000000, "God of War", "Battle is a playground for you."},
    {8800, 927, 68, 45000000, "Reality Weaver", "You can change destiny with just a thought."},
    {9500, 928, 72, 65000000, "The Eternal One", "True immortality has been fully achieved by you."},
    {9900, 929, 76, 85000000, "Almost Divine", "Just a little bit closer to the highest throne of the universe."},
    {10000, 930, 80, 150000000, "ZENITH OF GROWFAXS", "The highest peak. You are God in this world!"}
}

for _, m in ipairs(levelMilestones) do
    registerLuaAchievement({
        id = m[2],
        icon_id = m[3],
        name = m[5],
        description = m[6]
    })
end

onPlayerXPCallback(function(world, player, amount)
    local currentLevel = player:getLevel()

    for _, m in ipairs(levelMilestones) do
        if currentLevel >= m[1] then
            player:earnAchievement(m[2])
        end
    end
end)

onPlayerEarnAchievementCallback(function(world, player, id)
    for _, m in ipairs(levelMilestones) do
        if id == m[2] then

            player:addGems(m[4], 1, 0)

            player:onTalkBubble(player:getNetID(), "Trophy [ " .. m[5] .. " ] UNLOCKED! + " .. m[4] .. " Gems", 0)
            player:onConsoleMessage("Achievement Unlocked: " .. m[5] .. " - " .. m[6])

            if m[1] >= 1000 then
                world:onConsoleMessage("Throphy " .. player:getName() .. " achieve legendary [" .. m[5] .. "]!")
            end
            break
        end
    end
end)