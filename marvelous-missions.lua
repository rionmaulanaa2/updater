-- Marvelous Missions script
print("(Loaded) Marvelous Missions script for GrowSoft")

local storageUniqueName = "marvelous-missions"
local marvelousData = {}

function loadData()
    print("Loading marvelous missions data")
    marvelousData = loadDataFromServer(storageUniqueName) or {}
end

loadData() -- Load the data once script is loaded

function saveData()
    print("Saving marvelous missions data")
    saveDataToServer(storageUniqueName, marvelousData)
end

onAutoSaveRequest(function() -- Happens each X minutes and on server shutdown
    saveData()
end)

function startsWith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

function formatNum(num)
    local formattedNum = tostring(num)
    formattedNum = formattedNum:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    formattedNum = formattedNum:gsub("^,", "")
    return formattedNum
end

MissionsCat = {
    SEASON_1_MENU = 0,
    SEASON_2_MENU = 1
}

local missionsNavigation = {
    {name = "Season I", target = "tab_" .. MissionsCat.SEASON_1_MENU + 1, cat = MissionsCat.SEASON_1_MENU, texture = "interface/large/btn_mmtabs.rttex", texture_y = "1"},
    {name = "Season II", target = "tab_" .. MissionsCat.SEASON_2_MENU + 1, cat = MissionsCat.SEASON_2_MENU, texture = "interface/large/btn_mmtabs.rttex", texture_y = "2"}
}

MissionsTypes = {
    S1_FINDING_THE_SWAMP_MONSTER = 0,
    S1_HERE_COME_THE_SHADY_AGENTS = 1,
    S1_THE_SEARCH_FOR_NESSIE = 2,
    S1_MOTHMAN_RISING = 3,
    S1_THE_MENACE_OF_THE_MINI_MINOKAWA = 4,
    S1_THE_EYE_OF_THE_HEAVENS = 5,

    S2_A_TALE_OF_TENTACLES = 6,
    S2_THE_RAY_OF_THE_MANTA = 7,
    S2_THE_CRUST_OF_THE_CRAB = 8,
    S2_THE_CURSE_OF_THE_GHOST_PIRATE = 9,
    S2_THE_WINGS_OF_ATLANTIS = 10,
    S2_THE_HEART_OF_THE_OCEAN = 11
}

local missionsNames = {
    { type = MissionsTypes.S1_FINDING_THE_SWAMP_MONSTER, name = "Myths and Legends : Finding the Swamp monster!"},
    { type = MissionsTypes.S1_HERE_COME_THE_SHADY_AGENTS, name = "Myths and Legends : Here come the Shady Agents"},
    { type = MissionsTypes.S1_THE_SEARCH_FOR_NESSIE, name = "Myths and Legends : The Search for Nessie"},
    { type = MissionsTypes.S1_MOTHMAN_RISING, name = "Myths and Legends : Mothman Rising"},
    { type = MissionsTypes.S1_THE_MENACE_OF_THE_MINI_MINOKAWA, name = "Myths and Legends : The Menace of the Mini Minokawa"},
    { type = MissionsTypes.S1_THE_EYE_OF_THE_HEAVENS, name = "Myths and Legends : The Eye of the Heavens"},

    { type = MissionsTypes.S2_A_TALE_OF_TENTACLES, name = "The Seven Seas : A Tale of Tentacles!"},
    { type = MissionsTypes.S2_THE_RAY_OF_THE_MANTA, name = "The Seven Seas : The Ray of the Manta!"},
    { type = MissionsTypes.S2_THE_CRUST_OF_THE_CRAB, name = "The Seven Seas : The Crust of the Crab!"},
    { type = MissionsTypes.S2_THE_CURSE_OF_THE_GHOST_PIRATE, name = "The Seven Seas : The Curse of the Ghost Pirate!"},
    { type = MissionsTypes.S2_THE_WINGS_OF_ATLANTIS, name = "The Seven Seas : The Wings of Atlantis!"},
    { type = MissionsTypes.S2_THE_HEART_OF_THE_OCEAN, name = "The Seven Seas : The Heart of the Ocean!"}
}

function getMissionName(type)
    for i, mission in ipairs(missionsNames) do
        if mission.type == type then
            return mission.name
        end
    end
    return nil
end

local missionsData = {
    {
        season = MissionsCat.SEASON_1_MENU,
        type = MissionsTypes.S1_FINDING_THE_SWAMP_MONSTER,
        requiredItems = {
            {
                itemID = 3166,
                itemCount = 1
            },
            {
                itemID = 7428,
                itemCount = 1
            },
            {
                itemID = 10028,
                itemCount = 2
            },
            {
                itemID = 10030,
                itemCount = 2
            },
            {
                itemID = 8390,
                itemCount = 200
            },
            {
                itemID = 6984,
                itemCount = 100
            }
        },
        requiredMissions = {},
        rewardStr = "Reward: Swamp Monster Set + unlocks Here come the Shady Agents and The Search for Nessie",
        rewardItems = {
            {
                itemID = 10692,
                itemCount = 1
            },
            {
                itemID = 10690,
                itemCount = 1
            }
        }
    },
    {
        season = MissionsCat.SEASON_1_MENU,
        type = MissionsTypes.S1_HERE_COME_THE_SHADY_AGENTS,
        requiredItems = {
            {
                itemID = 9734,
                itemCount = 1
            },
            {
                itemID = 1150,
                itemCount = 1
            },
            {
                itemID = 7948,
                itemCount = 1
            },
            {
                itemID = 8394,
                itemCount = 200
            },
            {
                itemID = 1954,
                itemCount = 100
            },
            {
                itemID = 2035,
                itemCount = 10
            }
        },
        requiredMissions = { MissionsTypes.S1_FINDING_THE_SWAMP_MONSTER },
        rewardStr = "Reward: Shady Agent Shades  + unlocks Mothman Rising Mission",
        rewardItems = {
            {
                itemID = 10686,
                itemCount = 1
            }
        }
    },
    {
        season = MissionsCat.SEASON_1_MENU,
        type = MissionsTypes.S1_THE_SEARCH_FOR_NESSIE,
        requiredItems = {
            {
                itemID = 10248,
                itemCount = 1
            },
            {
                itemID = 9442,
                itemCount = 1
            },
            {
                itemID = 4828,
                itemCount = 1
            },
            {
                itemID = 7996,
                itemCount = 1
            },
            {
                itemID = 822,
                itemCount = 200
            },
            {
                itemID = 2974,
                itemCount = 10
            }
        },
        requiredMissions = { MissionsTypes.S1_FINDING_THE_SWAMP_MONSTER },
        rewardStr = "Reward: Cardboard Nessie + unlocks The menace of the Mini Minokawa Mission",
        rewardItems = {
            {
                itemID = 10688,
                itemCount = 1
            }
        }
    },
    {
        season = MissionsCat.SEASON_1_MENU,
        type = MissionsTypes.S1_MOTHMAN_RISING,
        requiredItems = {
            {
                itemID = 10680,
                itemCount = 1
            },
            {
                itemID = 6818,
                itemCount = 1
            },
            {
                itemID = 7350,
                itemCount = 1
            },
            {
                itemID = 9610,
                itemCount = 1
            },
            {
                itemID = 1206,
                itemCount = 1
            },
            {
                itemID = 10726,
                itemCount = 1
            }
        },
        requiredMissions = { MissionsTypes.S1_HERE_COME_THE_SHADY_AGENTS },
        rewardStr = "Reward: Mothman Wings",
        rewardItems = {
            {
                itemID = 10684,
                itemCount = 1
            }
        }
    },
    {
        season = MissionsCat.SEASON_1_MENU,
        type = MissionsTypes.S1_THE_MENACE_OF_THE_MINI_MINOKAWA,
        requiredItems = {
            {
                itemID = 9430,
                itemCount = 1
            },
            {
                itemID = 10578,
                itemCount = 1
            },
            {
                itemID = 6842,
                itemCount = 1
            },
            {
                itemID = 2856,
                itemCount = 100
            },
            {
                itemID = 1834,
                itemCount = 100
            },
            {
                itemID = 2722,
                itemCount = 1
            }
        },
        requiredMissions = { MissionsTypes.S1_THE_SEARCH_FOR_NESSIE },
        rewardStr = "Reward: Mini Minokawa + unlocks The Eye of the Heavens",
        rewardItems = {
            {
                itemID = 10694,
                itemCount = 1
            }
        }
    },
    {
        season = MissionsCat.SEASON_1_MENU,
        type = MissionsTypes.S1_THE_EYE_OF_THE_HEAVENS,
        requiredItems = {
            {
                itemID = 2714,
                itemCount = 200
            },
            {
                itemID = 7044,
                itemCount = 2
            },
            {
                itemID = 11098,
                itemCount = 2
            },
            {
                itemID = 9690,
                itemCount = 200
            },
            {
                itemID = 10676,
                itemCount = 5
            },
            {
                itemID = 10144,
                itemCount = 10
            }
        },
        requiredMissions = { MissionsTypes.S1_THE_MENACE_OF_THE_MINI_MINOKAWA },
        rewardStr = "Reward: Primordial Jade Lance",
        rewardItems = {
            {
                itemID = 11120,
                itemCount = 1
            }
        }
    },
    {
        season = MissionsCat.SEASON_2_MENU,
        type = MissionsTypes.S2_A_TALE_OF_TENTACLES,
        requiredItems = {
            {
                itemID = 5612,
                itemCount = 100
            },
            {
                itemID = 3812,
                itemCount = 200
            },
            {
                itemID = 8814,
                itemCount = 10
            },
            {
                itemID = 10226,
                itemCount = 10
            },
            {
                itemID = 9732,
                itemCount = 1
            },
            {
                itemID = 11264,
                itemCount = 10
            }
        },
        requiredMissions = {},
        rewardStr = "Reward: Robe of Tentacles + unlocks The Ray of the Manta and The Crust of the Crab",
        rewardItems = {
            {
                itemID = 12236,
                itemCount = 1
            }
        }
    },
    {
        season = MissionsCat.SEASON_2_MENU,
        type = MissionsTypes.S2_THE_RAY_OF_THE_MANTA,
        requiredItems = {
            {
                itemID = 5584,
                itemCount = 10
            },
            {
                itemID = 11110,
                itemCount = 2
            },
            {
                itemID = 5230,
                itemCount = 10
            },
            {
                itemID = 9656,
                itemCount = 10
            },
            {
                itemID = 10722,
                itemCount = 1
            },
            {
                itemID = 11576,
                itemCount = 20
            }
        },
        requiredMissions = { MissionsTypes.S2_A_TALE_OF_TENTACLES },
        rewardStr = "Reward: Neon Manta Ray + unlocks The Curse of the Ghost Pirate",
        rewardItems = {
            {
                itemID = 12232,
                itemCount = 1
            }
        }
    },
    {
        season = MissionsCat.SEASON_2_MENU,
        type = MissionsTypes.S2_THE_CRUST_OF_THE_CRAB,
        requiredItems = {
            {
                itemID = 11128,
                itemCount = 1
            },
            {
                itemID = 9404,
                itemCount = 1
            },
            {
                itemID = 11418,
                itemCount = 10
            },
            {
                itemID = 9034,
                itemCount = 10
            },
            {
                itemID = 11144,
                itemCount = 1
            },
            {
                itemID = 8604,
                itemCount = 1
            }
        },
        requiredMissions = { MissionsTypes.S2_A_TALE_OF_TENTACLES },
        rewardStr = "Reward: Cruising Crab + unlocks The Wings of Atlantis",
        rewardItems = {
            {
                itemID = 12238,
                itemCount = 1
            }
        }
    },
    {
        season = MissionsCat.SEASON_2_MENU,
        type = MissionsTypes.S2_THE_CURSE_OF_THE_GHOST_PIRATE,
        requiredItems = {
            {
                itemID = 11454,
                itemCount = 10
            },
            {
                itemID = 6816,
                itemCount = 1
            },
            {
                itemID = 11316,
                itemCount = 1
            },
            {
                itemID = 10256,
                itemCount = 10
            },
            {
                itemID = 10052,
                itemCount = 1
            },
            {
                itemID = 11166,
                itemCount = 10
            }
        },
        requiredMissions = { MissionsTypes.S2_THE_RAY_OF_THE_MANTA },
        rewardStr = "Reward: Ghost Pirate Set + 1 of 2 requirements for The Heart of the Ocean",
        rewardItems = {
            {
                itemID = 12228,
                itemCount = 1
            },
            {
                itemID = 12230,
                itemCount = 1
            }
        }
    },
    {
        season = MissionsCat.SEASON_2_MENU,
        type = MissionsTypes.S2_THE_WINGS_OF_ATLANTIS,
        requiredItems = {
            {
                itemID = 11544,
                itemCount = 2
            },
            {
                itemID = 6986,
                itemCount = 200
            },
            {
                itemID = 5604,
                itemCount = 10
            },
            {
                itemID = 2802,
                itemCount = 1
            },
            {
                itemID = 3584,
                itemCount = 200
            },
            {
                itemID = 11350,
                itemCount = 1
            }
        },
        requiredMissions = { MissionsTypes.S2_THE_CRUST_OF_THE_CRAB },
        rewardStr = "Reward: Atlantean Wings + 1 of 2 requirements for The Heart of the Ocean",
        rewardItems = {
            {
                itemID = 12234,
                itemCount = 1
            }
        }
    },
    {
        season = MissionsCat.SEASON_2_MENU,
        type = MissionsTypes.S2_THE_HEART_OF_THE_OCEAN,
        requiredItems = {
            {
                itemID = 10332,
                itemCount = 1
            },
            {
                itemID = 9738,
                itemCount = 20
            },
            {
                itemID = 10886,
                itemCount = 1
            },
            {
                itemID = 10132,
                itemCount = 1
            },
            {
                itemID = 9712,
                itemCount = 1
            },
            {
                itemID = 11480,
                itemCount = 10
            }
        },
        requiredMissions = { MissionsTypes.S2_THE_CURSE_OF_THE_GHOST_PIRATE, MissionsTypes.S2_THE_WINGS_OF_ATLANTIS },
        rewardStr = "Reward: Oceanaura!",
        rewardItems = {
            {
                itemID = 12240,
                itemCount = 1
            }
        }
    }
}

function isMissionComplete(player, type)
    local userData = marvelousData[player:getUserID()]

    if userData == nil then
        return false
    end

    for i, missionType in ipairs(userData.missionsComplete) do
        if missionType == type then
            return true
        end
    end
    return false
end

function isMissionAvailable(player, mission)
    if #mission.requiredMissions == 0 then
        return true
    end

    local userData = marvelousData[player:getUserID()]

    if userData == nil then
        return false
    end

    for _, requiredMission in ipairs(mission.requiredMissions) do
        local missionFound = false
        for _, completedMission in ipairs(userData.missionsComplete) do
            if completedMission == requiredMission then
                missionFound = true
                break
            end
        end
        if not missionFound then
            return false
        end
    end
    return true
end

function canClaim(player, mission)
    if not isMissionAvailable(player, mission) then
        return false
    end
    if isMissionComplete(player, mission.type) then
        return false
    end

    local hasAllItemsNeeded = true
    for i, item in ipairs(mission.requiredItems) do
        local hasAmount = player:getItemAmount(item.itemID)
        local hasEnough = hasAmount >= item.itemCount
        if not hasEnough then
            hasAllItemsNeeded = false
        end
    end
    return hasAllItemsNeeded
end

function onMarvelousMissions(world, player, cat)
    if cat < 0 or cat > 1 then
        return
    end

    local missionCategories = {}
    for i, category in ipairs(missionsNavigation) do
        local isCurrentCategory = (category.cat == cat) and "1" or "0"
        local tabString = string.format(
            "add_custom_button|%s|image:%s;image_size:228,92;frame:%s,%s;width:0.15;min_width:60;|",
            category.target,
            category.texture,
            isCurrentCategory,
            category.texture_y
        )
        table.insert(missionCategories, tabString)
    end

    local availableMissions = {}

    for i, mission in ipairs(missionsData) do
        if mission.season == cat then
            local hasAllItemsNeeded = true
            local isMissionComplete = isMissionComplete(player, mission.type)
            local isMissionAvailable = isMissionAvailable(player, mission)
            table.insert(availableMissions, "add_spacer|small|")
            table.insert(availableMissions, "add_spacer|small|")
            table.insert(availableMissions, string.format("add_custom_textbox|%s|size:medium;color:255,255,255,%s|", getMissionName(mission.type), (isMissionAvailable == true) and "255" or "80"))
            for x, item in ipairs(mission.requiredItems) do
                local hasAmount = player:getItemAmount(item.itemID)
                local hasEnough = hasAmount >= item.itemCount
                if not hasEnough then
                    hasAllItemsNeeded = false
                end
                table.insert(availableMissions, string.format("add_button_with_icon|info_%s|%s%s/%s`|staticGreyFrame,no_padding_x,is_count_label,%s|%s||", item.itemID, (hasEnough == true) and "`2" or "`4", hasAmount, item.itemCount, (isMissionAvailable == true) and "" or ",disabled", item.itemID))
            end
            table.insert(availableMissions, "add_button_with_icon||END_LIST|noflags|0||")
            table.insert(availableMissions, string.format("add_custom_textbox|`$%s`|size:small;color:255,255,255,%s", mission.rewardStr, (isMissionAvailable == true) and "255" or "80"))
            for x, item in ipairs(mission.rewardItems) do
                table.insert(availableMissions, string.format("add_button_with_icon|info_%s||staticYellowFrame,no_padding_x,%s|%s|%s|", item.itemID, (isMissionAvailable == true) and "" or ",disabled", item.itemID, item.itemCount))
            end
            table.insert(availableMissions, "add_button_with_icon||END_LIST|noflags|0||")
            table.insert(availableMissions, "add_spacer|small|")
            if isMissionComplete then
                table.insert(availableMissions, string.format("add_button|claim_myth_%s|Claimed|off|0|0|", mission.type))
            elseif hasAllItemsNeeded and isMissionAvailable then
                table.insert(availableMissions, string.format("add_button|claim_myth_%s|Claim|noflags|0|0|", mission.type))
            else
                table.insert(availableMissions, string.format("add_button|claim_myth_%s|Claim|off|0|0|", mission.type))
            end
        end
    end

    if cat == MissionsCat.SEASON_2_MENU then -- Aqua Color style
        player:setNextDialogRGBA(59, 130, 135, 168) -- Change color of the dialog's background
        player:setNextDialogBorderRGBA(0, 255, 255, 255) -- Change color of the dialog's border
    else -- Purple Color style
        player:setNextDialogRGBA(46, 26, 105, 168) -- Change color of the dialog's background
        player:setNextDialogBorderRGBA(65, 2, 250, 255) -- Change color of the dialog's border
    end

    player:onDialogRequest(
        "set_default_color|`o\n" ..
        "start_custom_tabs|\n" ..
        table.concat(missionCategories, "\n") .. "\n" ..
        "end_custom_tabs|\n" ..
        "add_label_with_icon|big|`wMarvelous Missions``|left|982|\n" ..
        "embed_data|tab|" .. cat .. "\n" ..
        "add_spacer|small|\n" ..
        "add_textbox|Start your mission towards some awesome rewards. Unless the mission states otherwise, rewards can only be claimed once. Some rewards are only available through events or certain times of the year so make sure to check back to see what's available.|left|\n" ..
        table.concat(availableMissions, "\n") .. "\n" ..
        "add_spacer|small|\n" ..
        "add_textbox|More missions coming soon! Check back for some more surprises!|left|\n" ..
        "add_spacer|small|\n" ..
        "add_button|back|Back|noflags|0|0|\n" ..
        "end_dialog|collectionQuests|||\n" ..
        "add_quick_exit|", 500 -- 500 is ms delay, its needed because otherwise dialogs with tabs kinda gets cursed in Growtopia, yes the delay is annoying, hopefuly in future gt will fix their issues
    )

    player:resetDialogColor() -- Reset the color (important)
end

onPlayerDialogCallback(function(world, player, data)
    local dialogName = data["dialog_name"] or ""
    if dialogName == "collectionQuests" then
        if data["buttonClicked"] ~= nil then
            if data["buttonClicked"] == "back" then
                player:onProfileUI(world, 1)
                return true
            end
            if startsWith(data["buttonClicked"], "tab_") then
                local tabNum = tonumber(data["buttonClicked"]:sub(5))
                onMarvelousMissions(world, player, tabNum - 1)
                return true
            end
            if startsWith(data["buttonClicked"], "claim_myth_") then
                local missionType = tonumber(string.sub(data["buttonClicked"], 12))
                for i, mission in ipairs(missionsData) do
                    if mission.type == missionType then
                        if not canClaim(player, mission) then
                            return true
                        end
                        if data["confirmClaim"] ~= nil then
                            for i, item in ipairs(mission.requiredItems) do
                                player:changeItem(item.itemID, -item.itemCount, 0)
                            end
                            for i, item in ipairs(mission.rewardItems) do
                                if not player:changeItem(item.itemID, item.itemCount, 0) then
                                    player:changeItem(item.itemID, item.itemCount, 1)
                                end
                            end
                            player:onAddNotification("", "`$Mission Complete!``", "", 0, 1500) -- texture, message, audio and the last is delay
                            -- player middle pos is like the very middle of a player sprite
                            local playerMiddlePosX = player:getMiddlePosX()
                            local playerMiddlePosY = player:getMiddlePosY()
                            local players = world:getPlayers()
                            for i = 1, #players do -- Show the particle effect to everyone in a world
                                local itPlayer = players[i]
                                itPlayer:onParticleEffect(46, playerMiddlePosX, playerMiddlePosY, 0, 0)
                            end
                            if not marvelousData[player:getUserID()] then
                                marvelousData[player:getUserID()] = { missionsComplete = { mission.type } }
                            else
                                table.insert(marvelousData[player:getUserID()].missionsComplete, mission.type)
                            end
                            return true
                        end
                        player:onDialogRequest(
                            "set_default_color|`o\n" ..
                            "add_label|big|Marvelous Mission|left|\n" ..
                            "embed_data|tab|" .. string.sub(data["tab"], 1, -2) .. "\n" ..
                            "embed_data|confirmClaim|1\n" ..
                            "add_spacer|small|\n" ..
                            "add_textbox|By selecting claim, the items will be removed from your inventory and your reward will be added.|left|\n" ..
                            "add_spacer|small|\n" ..
                            "add_button|" .. data["buttonClicked"] .. "|Claim|noflags|0|0|\n" ..
                            "end_dialog|collectionQuests||Back|", 500
                        )
                        return true
                    end
                end
                return true
            end
            if startsWith(data["buttonClicked"], "info_") then
                local itemID = tonumber(string.sub(data["buttonClicked"], 6))
                local item = getItem(itemID)
                if item == nil then
                    return true
                end
                local itemInfo = item:getInfo()
                local itemInfoArray = {}
                for i, info in ipairs(itemInfo) do
                    table.insert(itemInfoArray, string.format("add_textbox|%s|left|", info))
                end
                if #itemInfoArray > 0 then
                    table.insert(itemInfoArray, "add_spacer|small|")
                end
                player:onDialogRequest(
                    "set_default_color|`o\n" ..
                    "add_label_with_icon|big|`wAbout " .. item:getName() .. "``|left|" .. item:getID() .. "|\n" ..
                    "embed_data|tab|" .. string.sub(data["tab"], 1, -2) .. "\n" ..
                    "add_spacer|small|\n" ..
                    "add_textbox|" .. item:getDescription() .. "|left|\n" ..
                    "add_spacer|small|\n" ..
                    table.concat(itemInfoArray, "\n") .. "\n" ..
                    "end_dialog|collectionQuests|Close|Back|", 500
                )
                return true
            end
            return true
        end
        if data["tab"] ~= nil then
            onMarvelousMissions(world, player, tonumber(string.sub(data["tab"], 1, -2)))
            return true
        end
        return true
    end
    if dialogName == "playerProfile" then
        if data["buttonClicked"] ~= nil then
            if data["buttonClicked"] == "marvelous_missions" then
                onMarvelousMissions(world, player, MissionsCat.SEASON_1_MENU)
                return true
            end
        end
        return false
    end
    return false
end)