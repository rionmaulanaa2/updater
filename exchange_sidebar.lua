--==============================================================--
-- 🧩 Sidebar Button - Exchange System (Auto Send Message /exchange)
--==============================================================--

print("(Loaded) Sidebar Button - Exchange System")

--========================--
-- Sidebar Button Setup
--========================--

local exchangeButton = {
    active = true,
    buttonAction = "trigger_exchange_command", -- Nama action unik
    buttonTemplate = "BaseEventButton",
    counter = 0,
    counterMax = 0,
    itemIdIcon = 14186, -- Ganti ID item icon sesuai selera
    name = "ExchangeButton",
    order = 55, -- Order 55 agar pas di bawah atau dekat tombol Online (Order 50)
    rcssClass = "daily_challenge",
    text = "`oExchange``" -- Teks tombol sidebar
}

-- Register the sidebar button
addSidebarButton(json.encode(exchangeButton))

-- Function to send the sidebar button to a player
local function sendExchangeButton(player)
    if not player then return end
    player:sendVariant({
        "OnEventButtonDataSet",
        exchangeButton.name,
        1, -- Angka 1 ini yang bikin langsung nongol di game tanpa start event
        json.encode(exchangeButton)
    })
end

-- Kirim sidebar button ke semua player yang saat ini sedang online di server
for _, plr in ipairs(getServerPlayers() or {}) do
    sendExchangeButton(plr)
end

-- Callback saat player login baru
onPlayerLoginCallback(sendExchangeButton)

-- Callback saat player pindah/masuk world
onPlayerEnterWorldCallback(function(world, player)
    sendExchangeButton(player)
end)

--==============================================================--
-- Handle Sidebar Button Click (Auto Send /exchange)
--==============================================================--

onPlayerActionCallback(function(world, player, data)
    local action = data["action"]
    if action == exchangeButton.buttonAction then
        -- Langsung kirim pesan /exchange atas nama player tersebut ke world
        world:sendPlayerMessage(player, "/exchange")
        return true
    end
    return false
end)