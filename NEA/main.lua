-- External libraries/modules
local Tween = require("libraries/tween") --Primarily used to easily handle simple animations
local json = require("libraries/json") -- Used for encoding and decoding json

-- Classes/modules I made
local UserData = require("classes/UserData")
local UI = require("classes/UI")
local Grid = require("classes/Grid")

--SQL database setup
UserData.SQLExec([[
  CREATE TABLE MapsTbl (MapID INTEGER PRIMARY KEY AUTOINCREMENT, MapName STRING, SerializedMapID INTEGER);
  CREATE TABLE JourneysTbl (JourneyID INTEGER PRIMARY KEY AUTOINCREMENT, JourneyTime FLOAT, MapID INTEGER, StartNodeX INTEGER, StartNodeY INTEGER, EndNodeX INTEGER, EndNodeY INTEGER);
]])

love.keyboard.setKeyRepeat(true)

--General variables
local CanPlaceGrid = true
local DefaultFont = love.graphics.newFont("fonts/Tepeno Sans Bold.ttf", 18)

function love.load()
  local WindowSizeX, WindowSizeY = UI.GetDimensions()

  -- Setting up the window
  love.window.setTitle("Map Planner")
  love.window.setMode(WindowSizeX, WindowSizeY, {centered=true, borderless=false})

  local CurrentJourneyID = 1
  local JourneyIDText, MapNameText, JourneyTimeText;

  local SaveButtons = {}
  local CurrentImportPage = 1
  local SaveButtonsPerPage = 15

  local PageNumber;

  --setting up windows
  local ImportWindow = UI.Window.new({x=WindowSizeX*.125,y=WindowSizeY*.125}, {x=WindowSizeX*.75,y=WindowSizeY*.75}, {})
  local SettingsWindow = UI.Window.new({x=WindowSizeX*.125,y=WindowSizeY*.125}, {x=WindowSizeX*.75,y=WindowSizeY*.75}, {})
  local AddJourneysWindow = UI.Window.new({x=WindowSizeX*.2,y=WindowSizeY*.375}, {x=WindowSizeX*.6,y=WindowSizeY*.35}, {})
  local JourneysWindow = UI.Window.new({x=WindowSizeX*.2,y=WindowSizeY*.375}, {x=WindowSizeX*.6,y=WindowSizeY*.35}, {})

  -- Subroutines

  -- Updates the journey viewer
  local function LoadJourneyViewer(JourneyID)
    local ButtonCount = 0

    UserData.SQLExec(string.format([[SELECT * FROM JourneysTbl WHERE JourneyID=%d;]], tonumber(JourneyID)), function(udata, cols, values, names)
      local Record = {}
      for i=1,cols do
        Record[names[i]] = values[i]
      end

      local MapName = "N/A"

      --Find map relation to get the map name
      UserData.SQLExec(string.format([[SELECT * FROM MapsTbl WHERE MapID=%d;]], Record.MapID), function(udata, cols, values, names)
        local Record2 = {}
        for i=1,cols do
          Record2[names[i]] = values[i]
        end

        MapName = Record2.MapName
        return 0
      end)

      JourneyIDText:SetText("Journey ID: " .. Record.JourneyID)
      MapNameText:SetText("Map Name: " .. MapName)
      JourneyTimeText:SetText("Journey Time: " ..tostring(Record.JourneyTime) .. " seconds")

      return 0
    end)
  end

  -- Used to cycle through each saved journeyt
  local function CycleJourneyViewer(increment)
    UserData.SQLExec([[
      SELECT * FROM JourneysTbl ORDER BY JourneyID DESC;
    ]], function(udata, cols, values, names)
      local Record = {}
      for i=1,cols do
        Record[names[i]] = values[i]
      end

      if tonumber(Record.JourneyID) == CurrentJourneyID + increment then
        CurrentJourneyID = CurrentJourneyID + increment
        LoadJourneyViewer(CurrentJourneyID)
        return
      end

      return 0
    end)
  end

  local function UpdateImportWindow()
    for _, SaveButton in next, SaveButtons do
      SaveButton:Destroy()
    end

    PageNumber:SetText(CurrentImportPage)

    local Min = SaveButtonsPerPage*(CurrentImportPage-1)
    local Max = SaveButtonsPerPage*CurrentImportPage
    local ButtonCount = 0
    UserData.SQLExec(string.format([[SELECT * FROM MapsTbl WHERE MapID > %d AND MapID <= %d ORDER BY MapID ASC;]], Min, Max), function(udata, cols, values, names)
      local Record = {}
      for i=1,cols do
        Record[names[i]] = values[i]
      end


      print("This tha life for me", Record.MapID)

      local SaveButton = UI.TextInput.new({x=WindowSizeX*.125+10,y=WindowSizeY*.2+10 + ButtonCount*WindowSizeY*0.035}, {x=WindowSizeX*.4-20,y=WindowSizeY*0.03}, {
        Text=Record.MapName,
        BackgroundColor={.8,.8,.8}
      })
      SaveButton:SetFocus(false)      
      ImportWindow:AddElement(SaveButton)
      table.insert(SaveButtons, SaveButton)

      local SetNameButton = UI.Button.new({x=SaveButton.Position.x + WindowSizeX*.41 - 20, y=SaveButton.Position.y}, {x=WindowSizeX*.225-20,y=SaveButton.Size.y}, {
        Text="Set Name",
        BackgroundColor={.7,.7,.7}
      })
      ImportWindow:AddElement(SetNameButton)
      table.insert(SaveButtons, SetNameButton)

      SetNameButton:ConnectOnPress(function()
        local NewMapName = tostring(SaveButton.Text)
        if NewMapName and string.len(NewMapName) > 0 then
          SaveButton:SetText(NewMapName)
          UserData.SQLExec(string.format("UPDATE MapsTbl SET MapName = \"%s\" WHERE MapID = %d;", NewMapName, Record.MapID))
        else
          SaveButton:SetText("Invalid input")
        end
      end)

      local LoadButton = UI.Button.new({x=SetNameButton.Position.x + WindowSizeX*.235 - 20, y=SetNameButton.Position.y}, {x=WindowSizeX*.125-20,y=SetNameButton.Size.y}, {
        Text="Load",
        BackgroundColor={.7,.7,.7}
      })
      LoadButton:ConnectOnPress(function()
        Grid:LoadMapSave(tonumber(Record.MapID))
      end)
      
      ImportWindow:AddElement(LoadButton)
      table.insert(SaveButtons, LoadButton)

      local DeleteButton = UI.Button.new({x=LoadButton.Position.x + WindowSizeX*.135 - 20, y=LoadButton.Position.y}, {x=WindowSizeX*.065-20,y=LoadButton.Size.y}, {
        Text="X",
        BackgroundColor={.7,.7,.7}
      })

      DeleteButton:ConnectOnPress(function()
        UserData.SQLExec(string.format("DELETE FROM MapsTbl WHERE MapID=%d;", Record.MapID))
        UpdateImportWindow()
      end)

      ImportWindow:AddElement(DeleteButton)
      table.insert(SaveButtons, DeleteButton)
      
      ButtonCount = ButtonCount + 1
      return 0
    end)
  end

  --Settings window title text
  SettingsWindow:AddElement(UI.TextLabel.new({x=WindowSizeX*.15,y=WindowSizeY*.15}, {x=0,y=WindowSizeY*.05}, {
    Text="Settings"
  }))

  --Settings text fields
  UI.NewSettingsInput("Map Scale (1 cell:xm) (default=1)", "MapScale", SettingsWindow, {
    x=WindowSizeX*.15,
    y=WindowSizeY*.225
  }, function(Scale)
    Scale = tonumber(Scale)
    if Scale and Scale > 0 then
      UserData.UpdateSetting("MapScale", Scale)
      return true
    end
  end)

  UI.NewSettingsInput("Walking Speed (m/s) (default=1)", "WalkingSpeed", SettingsWindow, {
    x=WindowSizeX*.15,
    y=WindowSizeY*.325
  }, function(Speed)
    Speed = tonumber(Speed)
    if Speed and Speed > 0 then
      UserData.UpdateSetting("WalkingSpeed", Speed)
      return true
    end
  end)

  UI.NewSettingsInput("Pathfinding Speed (default=1)", "PathfindingSpeed", SettingsWindow, {
    x=WindowSizeX*.15,
    y=WindowSizeY*.425
  }, function(Speed)
    Speed = tonumber(Speed)

    if Speed and Speed > 0 then
      UserData.UpdateSetting("PathfindingSpeed", Speed)
      return true
    end
  end)

  local JourneysButton = UI.Button.new({x=WindowSizeX*.15,y=WindowSizeY*.8}, {x=WindowSizeX*.25,y=WindowSizeY*.03}, {
    Text="Add Journey",
    BackgroundColor={.6,.6,.6}
  }):ConnectOnPress(function()
    UI.CloseAllWindows()
    AddJourneysWindow:SetVisible(not AddJourneysWindow.Visible)
  end)
  SettingsWindow:AddElement(JourneysButton)

  --Journeys stuff

  JourneyIDText = UI.TextLabel.new({x=WindowSizeY*.15,y=WindowSizeY*.46}, {x=0,y=WindowSizeY*.03}, {
    Text="Journey ID: N/A"
  })

  JourneyTimeText = UI.TextLabel.new({x=WindowSizeY*.15,y=WindowSizeY*.54}, {x=0,y=WindowSizeY*.03}, {
    Text="Journey Time: N/A"
  })

  MapNameText = UI.TextLabel.new({x=WindowSizeY*.15,y=WindowSizeY*.5}, {x=0,y=WindowSizeY*.03}, {
    Text="Map Name: N/A"
  })

  JourneysWindow:AddElement(UI.TextLabel.new({x=WindowSizeY*.15,y=WindowSizeY*.4}, {x=0,y=WindowSizeY*.05}, {
    Text="Journeys"
  }))

  JourneysWindow:AddElement(JourneyIDText)
  JourneysWindow:AddElement(MapNameText)
  JourneysWindow:AddElement(JourneyTimeText)

  local JourneysButton = UI.Button.new({x=WindowSizeX*.45,y=WindowSizeY*.8}, {x=WindowSizeX*.25,y=WindowSizeY*.03}, {
    Text="View Journeys",
    BackgroundColor={.6,.6,.6}
  }):ConnectOnPress(function()
    UI.CloseAllWindows()
    JourneysWindow:SetVisible(not JourneysWindow.Visible)

    LoadJourneyViewer(CurrentJourneyID)
  end)
  SettingsWindow:AddElement(JourneysButton)


  JourneysWindow:AddElement(UI.Button.new({x=WindowSizeX*.225,y=WindowSizeY*.59}, {x=WindowSizeX*.25,y=WindowSizeY*.03}, {
    Text="Load Journey",
    BackgroundColor={.6,.6,.6}
  }):ConnectOnPress(function()
    UserData.SQLExec(string.format([[SELECT * FROM JourneysTbl WHERE JourneyID==%d;]], CurrentJourneyID), function(udata, cols, values, names)
      local Record = {}
      for i=1,cols do
        Record[names[i]] = values[i]
      end

      Grid:LoadMapSave(tonumber(Record.MapID))
      Grid:PlaceNode(tonumber(Record.StartNodeX), tonumber(Record.StartNodeY), 2)
      Grid:PlaceNode(tonumber(Record.EndNodeX), tonumber(Record.EndNodeY), 3)

      return 0
    end)
  end))

  JourneysWindow:AddElement(UI.Button.new({x=WindowSizeX*.225,y=WindowSizeY*.675}, {x=WindowSizeX*.175,y=WindowSizeY*.03}, {
    Text="Back",
    BackgroundColor={.6,.6,.6}
  }):ConnectOnPress(function()
    CycleJourneyViewer(-1)
  end))

  JourneysWindow:AddElement(UI.Button.new({x=WindowSizeX*.6,y=WindowSizeY*.675}, {x=WindowSizeX*.175,y=WindowSizeY*.03}, {
    Text="Next",
    BackgroundColor={.6,.6,.6}
  }):ConnectOnPress(function()
    CycleJourneyViewer(1)
  end))

  --AddJourneys window title text
  AddJourneysWindow:AddElement(UI.TextLabel.new({x=WindowSizeY*.15,y=WindowSizeY*.4}, {x=0,y=WindowSizeY*.05}, {
    Text="Add Journeys"
  }))
  AddJourneysWindow:AddElement(UI.TextLabel.new({x=WindowSizeY*.15,y=WindowSizeY*.55}, {x=0,y=WindowSizeY*.02}, {
    Text="Start and end node must be present"
  }))
  AddJourneysWindow:AddElement(UI.TextLabel.new({x=WindowSizeY*.15,y=WindowSizeY*.575}, {x=0,y=WindowSizeY*.02}, {
    Text="A map must be selected"
  }))

  local PromptText = UI.TextLabel.new({x=WindowSizeY*.15,y=WindowSizeY*.475}, {x=0,y=WindowSizeY*.03}, {
    Text="Journey Time (seconds)"
  })
  local JourneyTimeInput = UI.TextInput.new({x=PromptText.Position.x,y=PromptText.Position.y+WindowSizeY*.0375}, {x=WindowSizeX*.25,y=WindowSizeY*.03}, {})

  AddJourneysWindow:AddElement(PromptText)
  AddJourneysWindow:AddElement(JourneyTimeInput)

  AddJourneysWindow:AddElement(UI.Button.new({x=WindowSizeX*.225,y=WindowSizeY*.65}, {x=WindowSizeX*.275,y=WindowSizeY*.03}, {
    Text="Record Journey",
    BackgroundColor={.6,.6,.6}
  }):ConnectOnPress(function()
    local journeyTime = tonumber(JourneyTimeInput.Text)

    local startPoint, endPoint = Grid:GetStartEndPoints()

    if (journeyTime ~= nil) and (journeyTime > 0) and (startPoint ~= nil and endPoint ~= nil) and (Grid.CurrentMapID ~= nil) then
      AddJourneysWindow:SetVisible(false)

      local JourneyID = 1

      UserData.SQLExec([[
        SELECT * FROM JourneysTbl ORDER BY JourneyID DESC LIMIT 1;
      ]], function(udata, cols, values, names)
        for i=1,cols do
          if names[i] == "JourneyID" then
            JourneyID = values[i] + 1
          end
        end
  
        return 0
      end)

      UserData.SQLExec(string.format("INSERT INTO JourneysTbl (JourneyID, MapID, JourneyTime, StartNodeX, StartNodeY, EndNodeX, EndNodeY) VALUES (%d, %d, %f, %d, %d, %d, %d);", JourneyID, Grid.CurrentMapID, journeyTime, startPoint.x, startPoint.y, endPoint.x, endPoint.y))
    else
      JourneyTimeInput:SetText("Invalid input")
    end
  end))

  --setting up Buttons
  --clear
  UI.Button.new({x=25,y=20}, {x=90,y=35}, {
    Text="Clear"
  }):ConnectOnPress(function()
    Grid:Clear()
  end)

  --find route
  UI.Button.new({x=25+100,y=20}, {x=150,y=35}, {
    Text="Find Route"
  }):ConnectOnPress(function()
    if Grid.CurrentRoute ~= nil then return end
    Grid:FindRoute()
  end)

  PageNumber = UI.TextLabel.new({x=WindowSizeX*.5,y=WindowSizeY*.8}, {x=0,y=WindowSizeY*.03}, {
    Text=CurrentImportPage
  })
  ImportWindow:AddElement(PageNumber)
  
  --Import window title text  
  ImportWindow:AddElement(UI.TextLabel.new({x=WindowSizeX*.125,y=WindowSizeY*.15}, {x=0,y=WindowSizeY*.03}, {
    Text="Drag an image file or select an existing save"
  }))
  
  ImportWindow:AddElement(UI.Button.new({x=WindowSizeX*.225,y=WindowSizeY*.8}, {x=WindowSizeX*.175,y=WindowSizeY*.03}, {
    Text="Back",
    BackgroundColor={.6,.6,.6}
  }):ConnectOnPress(function()
    CurrentImportPage = math.max(CurrentImportPage-1, 1)
    UpdateImportWindow()
  end))

  ImportWindow:AddElement(UI.Button.new({x=WindowSizeX*.6,y=WindowSizeY*.8}, {x=WindowSizeX*.175,y=WindowSizeY*.03}, {
    Text="Next",
    BackgroundColor={.6,.6,.6}
  }):ConnectOnPress(function()
    CurrentImportPage = CurrentImportPage + 1
    UpdateImportWindow()
  end))

  --import button
  UI.Button.new({x=25,y=WindowSizeY - 55}, {x=160,y=35}, {
    Text="Import Map"
  }):ConnectOnPress(function()
    UpdateImportWindow()

    UI.CloseAllWindows(ImportWindow)
    ImportWindow:SetVisible(not ImportWindow.Visible)
  end)

  --save map button
  UI.Button.new({x=25+170,y=WindowSizeY - 55}, {x=150,y=35}, {
    Text="Save Map"
  }):ConnectOnPress(function()
    local GridData = Grid:GetGridData()
    local SerializedMap = json.encode(GridData)
  
    local SerializedMapID = 1 -- default value if no existing map ids are found

    -- finds highest serialized map id and adds 1 to ensure all values are unique
    UserData.SQLExec([[
      SELECT * FROM MapsTbl ORDER BY SerializedMapID DESC LIMIT 1;
    ]], function(udata, cols, values, names)
      for i=1,cols do
        if names[i] == "MapID" then
          SerializedMapID = values[i] + 1
        end
      end

      return 0
    end)

    UserData.SQLExec(string.format([[INSERT INTO MapsTbl (MapID, MapName, SerializedMapID) VALUES (%d, "Map %d", %d);]], SerializedMapID, SerializedMapID, SerializedMapID))

    Grid.CurrentMapID = SerializedMapID

    love.filesystem.setIdentity("mapsaves")
    local file = love.filesystem.newFile(SerializedMapID) 
    file:open("w")
    file:write(SerializedMap)
    file:close()
    
    UpdateImportWindow()
  end)

  --settings button
  UI.Button.new({x=WindowSizeX-175,y=WindowSizeY - 55}, {x=150,y=35}, {
    Text="Settings"
  }):ConnectOnPress(function()
    UI.CloseAllWindows(SettingsWindow)
    SettingsWindow:SetVisible(not SettingsWindow.Visible)
  end)

  --Node selectors
  local ModeButtons = {}
  for i = 1, 3 do
    local Size = {x=50,y=50}
    local Mode = UI.Button.new({x=WindowSizeX-200 + (60*(i-1)),y=20}, Size, {
      BackgroundColor=Grid.DrawingModeColors[i]
    })
    Mode:ConnectOnPress(function()
      Grid.DrawingMode = i
      for _, Button in next, ModeButtons do
        Button.Selected = false
        Button.Size = {x=50,y=50}
      end
      Mode.Selected = true
      Mode.Size = {x=30,y=30}
    end)

    table.insert(ModeButtons, Mode)
  end

  ImportWindow:SetVisible(false)
  SettingsWindow:SetVisible(false)
  AddJourneysWindow:SetVisible(false)
  JourneysWindow:SetVisible(false)
end  

--Called on every update
function love.update(dt)
  for _, TweenInstance in next, Tween._CurrentTweens do
    TweenInstance:Update(dt)
  end 

  local HoveredButton = UI.GetHoveringButton()
  if (HoveredButton == nil) and (CanPlaceGrid == true) and (Grid.CurrentRoute == nil or Grid.CurrentRoute._Completed == true) then
    Grid:RegisterInput()
  end

  Grid:Update(dt)
end

-- Renders the program, called on every frame
function love.draw()
  local WindowSizeX, WindowSizeY = UI.GetDimensions()

  --Draws the background
  love.graphics.setColor({1,1,1})
  love.graphics.rectangle("fill", 0,0, WindowSizeX, WindowSizeY)

  Grid:DrawGrid() -- renders the grid
  UI:Render() -- renders UI Elements

  local CurrentRoute = Grid.CurrentRoute
  local settings = UserData.GetSettings()

  -- Travel time estimation
  if CurrentRoute and CurrentRoute.Completed then
    local eta = (CurrentRoute:GetLength() * settings.MapScale)/settings.WalkingSpeed
    love.graphics.print("Estimated Travel Time: " .. math.floor(eta) .. " seconds", DefaultFont, 25,80,0,1,1)
  end

  love.graphics.print("Current Map ID: " .. (Grid.CurrentMapID or "None"), DefaultFont, 25,60,0,1,1)
end

function love.mousepressed()
  if UI.RegisterMousePress() == true then
    CanPlaceGrid = false
  end
end

function love.mousereleased()
  CanPlaceGrid = true
end

--Used for text inputs
function love.textinput(text)
  --for text input
  for Index, UIObject in next, UI._CurrentObjects do
    if UIObject.inputField then
      UIObject.inputField:textinput(text)
    end
  end
end

function love.keypressed(key, u)
  if key == "rctrl" then
     debug.debug()
  end

  --Used for text inputs
  for Index, UIObject in next, UI._CurrentObjects do
    if UIObject.inputField then
      UIObject.inputField:keypressed(key)
    end
  end
end

--Translating image files onto the grid
function love.filedropped(File)
	local FileName = File:getFilename()
	local FileExtension = FileName:match("%.%w+$")

  --Making sure the file is an image file
	if FileExtension == ".png" or FileExtension == ".jpg" then
		File:open("r")

    Grid.CurrentMapID = nil

		local FileData = File:read("data")
		local ImageData = love.image.newImageData(FileData)
    
    local Width, Height = ImageData:getDimensions()
    local GridWidth, GridHeight = Grid:GetDimensions()

    local WidthRatio = (Width-1)/GridWidth 
    local HeightRatio = (Height-1)/GridHeight

    -- Define thresholds in order to ignore background pixels
    local ColorThreshold = .5
    local AlphaThreshold = .9

    for x = 0, GridWidth-1 do
      for y = 0, GridHeight-1 do
        local r, g, b, alpha = ImageData:getPixel(math.floor(x*WidthRatio),math.floor(y*HeightRatio))
        if (alpha > AlphaThreshold) and (r < ColorThreshold and g < ColorThreshold and b < ColorThreshold) then
          Grid:PlaceNode(x, y, 1)
        end
      end 
    end
    File:close()
	end
end