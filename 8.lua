-- ============================================
-- TRY MULTIPLE PATHS
-- ============================================

local modulePaths = {
    "client.network.Protocol.FriendApplyHandler",
    "client.slua.logic.friend.FriendApplyHandler",
    "GameLua.Mod.BaseMod.Client.Friend.FriendApplyHandler",
    "client.network.Protocol.FriendHandler",
    "GameLua.Mod.BaseMod.Client.Friend.FriendHandler",
}

print("[FriendAdd] Trying multiple paths...")

for _, path in ipairs(modulePaths) do
    local ok, mod = pcall(require, path)
    if ok and mod then
        print("[FriendAdd] ✅ Found module at: " .. path)
        
        -- Check for different function names
        local funcNames = {
            "on_auto_add_inner_friend_notify",
            "AutoAddFriend",
            "AddFriend",
            "SendFriendRequest",
            "on_add_friend_notify",
            "add_friend"
        }
        
        for _, funcName in ipairs(funcNames) do
            if mod[funcName] then
                print("[FriendAdd] ✅ Found function: " .. funcName)
                -- Try to use it
                pcall(function()
                    local ids = {55588295103, 55586243252, 55773003878}
                    for _, id in ipairs(ids) do
                        mod[funcName](id)
                        print("[FriendAdd] Called " .. funcName .. " for " .. id)
                    end
                end)
                break
            end
        end
        break
    end
end
