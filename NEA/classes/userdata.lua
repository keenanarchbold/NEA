local UserData = {}
local json = require("libraries/json") -- Used for encoding and decoding json

require("libraries/sqlite3") -- SQLite3

UserData._MainDBPath = love.filesystem.getSaveDirectory() .. "main.db"
UserData._CachedSettings = nil

-- Create a usersettings file if one doesn't exist already
function CreateSettingsFile()
    love.filesystem.setIdentity("NEA")
    
    --default file
    local DefaultSettings = json.encode({
        PathfindingSpeed=1,
        WalkingSpeed=1,
        MapScale=1
    })

    local File = love.filesystem.newFile("UserData") 
    File:open("w")
    File:write(DefaultSettings)
    File:close() 
end

--Update a specified setting
function UserData.UpdateSetting(Setting, Value)
    love.filesystem.setIdentity("NEA")

    local CurrentSettings = json.decode(love.filesystem.read("UserData"))
    CurrentSettings[Setting] = Value

    UserData._CachedSettings = CurrentSettings

    --Exception handling for file writing as it can fail sometimes
    local Success, ErrorMessage = pcall(function()
        love.filesystem.write("UserData", json.encode(CurrentSettings))
    end)

    if not Success then
        print(ErrorMessage)
    end
end

-- Get settings in lua table format
function UserData.GetSettings()
    if UserData._CachedSettings == nil then
        UserData._CachedSettings = json.decode(love.filesystem.read("UserData"))
    end
    return UserData._CachedSettings
end

--Execute an SQL command
function UserData.SQLExec(Query, Function)
    --Exception handling for SQL commands as they may fail sometimes
    local Success, ErrorMessage = pcall(function()
        local MainDB = sqlite3.open(UserData._MainDBPath)
        MainDB:exec(Query, Function)
        MainDB:close()
    end)

    if not Success then
        print(ErrorMessage)
    end
end

-- Called upon program opening
function UserData._Load()
    if love.filesystem.read("UserData") == nil then
        CreateSettingsFile()
    end
    
    UserData._CachedSettings = UserData.GetSettings()
end

UserData._Load()

return UserData