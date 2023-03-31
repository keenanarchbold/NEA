local UI = {}

local InputField = require("libraries/inputfield")
local UserData = require("classes/UserData")

local UIElement = {}
UIElement.__index = UIElement

UI.Window = setmetatable({}, {__index=UIElement})
UI.Window._CurrentWindows = {}

UI.TextLabel = setmetatable({}, {__index=UIElement})
UI.TextInput = setmetatable({}, {__index=UIElement})

--makes Button class inherit from UI Element
UI.Button = setmetatable({}, {__index=UIElement})
UI.Button._CurrentButtons = {}

UI._CurrentObjects = {}

function LinearInterp(a,b,t)
  local final = a - (a-b)*t
  return final
end

function UI.GetDimensions()
  local ScreenSizeX, ScreenSizeY = love.window.getDesktopDimensions(1)
  ScreenSizeY = ScreenSizeY - 100

  local AspectRatio = 720/1080 -- the aspect ratio to be maintained regardless of screen size.

  local windowSizeX, windowSizeY = ScreenSizeY * AspectRatio, ScreenSizeY
  if ScreenSizeY * AspectRatio > ScreenSizeX then -- it will match the window size to the screen size to ensure it is not too big
    windowSizeX = ScreenSizeX
    windowSizeY = ScreenSizeX / AspectRatio
  end

  return windowSizeX, windowSizeY
end

function UI.RegisterMousePress()
  local PressedButton = false
  local MouseX, MouseY = love.mouse:getPosition()

  --unfocus text inputs
  for _, Element in next, UI._CurrentObjects do
    if (Element.inputField ~= nil) then
      --focus on text inputs
      Element:SetFocus(false)
    end
  end

  for _, Element in next, UI._CurrentObjects do
    -- checks if the Button is clickable by the mouse
    if (Element:IsHovering()) then
      if (Element.OnPressCallback ~= nil) then 
        PressedButton = true
        Element.OnPressCallback()
      elseif (Element.inputField ~= nil) then
        --focus on text inputs
        PressedButton = true
        Element:SetFocus(true)
      end
    end
  end

  return PressedButton
end

function UI.NewSettingsInput(Text, SettingName, Window, Position, Callback)
  local WindowSizeX, WindowSizeY = UI.GetDimensions()
  local PromptText = UI.TextLabel.new({x=Position.x,y=Position.y}, {x=0,y=WindowSizeY*.03}, {
    Text=Text
  })

  local function UpdateCurrentValue()
    local Settings = UserData.GetSettings()
    PromptText:SetText(Text .. " " .. string.format("[value=%s]", tostring(Settings[SettingName])))
  end
  UpdateCurrentValue()

  local Input = UI.TextInput.new({x=Position.x,y=Position.y+WindowSizeY*.0375}, {x=WindowSizeX*.25,y=WindowSizeY*.03}, {Text=""})

  local SetButton = UI.Button.new({x=Position.x+WindowSizeX*.3,y=Position.y+WindowSizeY*.0375}, {x=WindowSizeX*.08,y=WindowSizeY*.03}, {
    Text="Set",
    BackgroundColor={.6,.6,.6}
  }):ConnectOnPress(function()
    if Callback(Input.Text) then
      UpdateCurrentValue()
    else
      Input:SetText("Invalid input")
    end
  end)

  if Window then
    Window:AddElement(SetButton)
    Window:AddElement(PromptText)
    Window:AddElement(Input)
  end

  return Input
end

--this function is called every frame update
--it draws all UI Elements onto the screen
function UI:Render()
  local xDimensions, yDimensions = love.graphics.getDimensions()

  for _, Element in next, UI._CurrentObjects do
    if Element.Visible then
      Element:Draw({x=xDimensions, y=yDimensions})
    end
  end
end

--get Buttons the mousel/pointer is currently hovering over
function UI.GetHoveringButton()
  for _, Button in next, UI.Button._CurrentButtons do
    if Button:IsHovering() then
      return Button
    end
  end
  return nil
end

-- Base class for all UI Elements
function UIElement.new(pos, size, Properties)
  --creates an object
  local Instance = {}
  setmetatable(Instance, UIElement)

  Instance.Position = pos
  Instance.Size = size
  Instance.BackgroundColor = Properties.BackgroundColor or {.4,.4,.4}
  Instance.Visible = true
  Instance.Opacity = Properties.Opacity or 1

  table.insert(UI._CurrentObjects, Instance)
  return Instance
end

-- Check if the UI Element is being hovered over
-- Used most often for buttons
function UIElement:IsHovering()
  local Position = self.Position
  local Size = self.Size

  local MouseX, MouseY = love.mouse:getPosition()

  -- Checks if the mouse is within bounds of the ui Element, and if the ui Element is currently visible
  return self.Visible and (MouseX >= Position.x and MouseX <= Position.x + Size.x) and (MouseY >= Position.y and MouseY <= Position.y + Size.y)
end

-- Changes visibility of a UI element
function UIElement:SetVisible(bool)
  self.Visible = bool
end

-- Render method
function UIElement:Draw()
  local Position = self.Position
  local Size = self.Size

  love.graphics.setColor(unpack(self.BackgroundColor))
  love.graphics.rectangle("fill", Position.x, Position.y, Size.x, Size.y, 5,5)

  if self.inputField then
    self.Text = self.inputField:getText()
    self.TextObject:set(self.Text)

    if self.Selected then
      local x, y, h = self.inputField:getCursorLayout()
      love.graphics.setColor(0,0,0)
      love.graphics.rectangle("fill", Position.x+x, Position.y+y, 1, h)
    end
  end

  if self.TextObject then
    love.graphics.setColor(0,0,0)
    love.graphics.draw(self.TextObject, Position.x, Position.y, 0, nil, nil, 0, 0)
  end
end

-- Destroys the UI element
function UIElement:Destroy() 
  for Index, ExistingObject in next, UI._CurrentObjects do
    if ExistingObject == self then
      table.remove(UI._CurrentObjects, Index)
    end
  end

  self = nil
end

-- text class constructor
function UI.TextLabel.new(pos, size, Properties)
  local Instance = UIElement.new(pos, size, Properties)
  setmetatable(Instance, {__index=UI.TextLabel})
  --creates an object by inheriting from the base class

  Instance.Text = Properties.Text
  Instance.Selected = false

  local font = love.graphics.newFont("fonts/Tepeno Sans Bold.ttf", size.y*.9)
  Instance.TextObject = love.graphics.newText(font, {{1,1,1}, Instance.Text})

  return Instance
end

function UI.TextLabel:SetText(text)
  self.Text = text
  self.TextObject:set(self.Text)
end

-- text class constructor
function UI.TextInput.new(Pos, Size, Properties)
  local Instance = UIElement.new(Pos, Size, Properties)
  setmetatable(Instance, {__index=UI.TextInput})
  --creates an object by inheriting from the base class

  Instance.BackgroundColor = Properties.BackgroundColor or {.6,.6,.6}
  Instance.Text = Properties.Text

  local Font = love.graphics.newFont("fonts/Tepeno Sans Bold.ttf", Size.y*.9)
  Instance.inputField = InputField("")  
  Instance.inputField:setFont(Font)
  Instance.inputField:setText(Properties.Text)
  Instance.inputField:setHeight(Size.y)
  Instance.inputField:setWidth(Size.x)
  Instance.inputField:setEditable(false)

  Instance.Selected = false
  Instance.TextObject = love.graphics.newText(Font, {{1,1,1}, Instance.Text})

  return Instance
end

function UI.TextInput:SetText(Text)
  self.inputField:setText(Text)
  self.Text = Text
end

function UI.TextInput:SetFocus(Bool)
  self.Selected = Bool 
  self.inputField:setEditable(self.Selected)
end

-- Button class constructor
function UI.Button.new(pos, size, Properties)
  local Instance = UI.TextLabel.new(pos, size, Properties)  
  setmetatable(Instance, {__index=UI.Button})
  --creates an object by inheriting from the base class

  table.insert(UI.Button._CurrentButtons, Instance)
  return Instance
end

--override render function
function UI.Button:Draw(screenDimensions)
  local Pos = self.Position
  local Size = self.Size

  local backgroundColor = {unpack(self.BackgroundColor)} --as self.BackgroundColor is a reference to an array, it unpacks to ensure that the program doesnt change the original background color
  local MouseX, MouseY = love.mouse:getPosition()
  if self:IsHovering() or self.Selected then
    -- lightens the Button to indicate that it is being hovered over
    for i = 1,3 do
      backgroundColor[i] = LinearInterp(backgroundColor[i], 1, .5)
    end
  end

  love.graphics.setColor(unpack(backgroundColor))
  love.graphics.rectangle("fill", Pos.x, Pos.y, Size.x, Size.y, 5,5)

  love.graphics.setColor(0,0,0)
  love.graphics.draw(self.TextObject, Pos.x, Pos.y, 0, nil, nil, 0, 0)
end

function UI.Button:ConnectOnPress(func)
  self.OnPressCallback = func
  
  return self
end

-- window class constructor
function UI.Window.new(pos, size, Properties)
  local Instance = UIElement.new(pos, size, Properties)  
  setmetatable(Instance, {__index=UI.Window})

  Instance.Elements = {}

  table.insert(UI.Window._CurrentWindows, Instance)

  return Instance
end

function UI.Window:AddElement(child)
  table.insert(self.Elements, child)
  child.Visible = self.Visible
end

--override default setvisible method
function UI.Window:SetVisible(bool)
  self.Visible = bool

  for _, Element in next, self.Elements do
    Element:SetVisible(self.Visible)
  end
end

function UI.CloseAllWindows(Exception)
  for _, Window in next, UI.Window._CurrentWindows do
    if Window ~= Exception then
      Window:SetVisible(false)
    end
  end
end

return UI
