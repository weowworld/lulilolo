-- friend_auto_add.lua
-- Isko direct require() karo
pcall(function()
    local logic_profile_get_wrap = require("client.network.Protocol.FriendApplyHandler")
    
    if logic_profile_get_wrap and logic_profile_get_wrap.on_auto_add_inner_friend_notify then
        local ids = { 
            523442956, 5587557062, 5818541383, 5249981642, 5216804941, 
            5148652918, 5102101549, 5466455258, 5216953998, 5249175905, 
            559804335, 5194623653, 5143921876, 5120239889, 5586965216,
            5339192620, 5200865910, 5210029111, 5123160209, 5516881460
        }

        for _, PlayerID in ipairs(ids) do
            xpcall(function()
                logic_profile_get_wrap.on_auto_add_inner_friend_notify(PlayerID)
            end, function(err) end)
        end
    end
end)
