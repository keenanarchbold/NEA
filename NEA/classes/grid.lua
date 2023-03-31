local UI = require("classes/UI")
local UserData = require("classes/UserData")
local json = require("libraries/json") -- Used for encoding and decoding json

local tween = require("libraries/tween") -- I didn't create this module, though I made minor edits. Primarily used to easily handle simple animations

local Grid = {}

--::// Stack class
local Stack = {}

function Stack.new()
  local NewStack = {}
  setmetatable(NewStack, {__index=Stack})

  NewStack._Stack = {}

  return NewStack
end

function Stack:Push(Element)
  table.insert(self._Stack, Element)
end

function Stack:Peek()
  return self._Stack[#self._Stack]
end

function Stack:Pop()
  return table.remove(self._Stack, #self._Stack)
end

function Stack:IsEmpty()
  return #self._Stack == 0
end

--::// Route class
local Route = {}

function Route.new(startNode, endNode)
  local NewRoute = {}
  setmetatable(NewRoute, {__index=Route})

  NewRoute._StartNode = startNode 
  NewRoute._EndNode = endNode
  NewRoute._Completed = false
  NewRoute._Length = 0

  local route = Grid:_Dijkstra(NewRoute._StartNode, NewRoute._EndNode)
  NewRoute._RouteFunction = route

  return NewRoute
end

-- Called on each update
function Route:Update()
  local Prev = self._RouteFunction()
  if Prev then
    self:Complete(Prev)
    self.Route = nil
  end
end
 
-- Destroys the route
function Route:Destroy()
  for y, yTbl in next, Grid.GridTbl do
    for x, Properties in next, yTbl do
      if Properties[1] == 5 or Properties[1] == 4 then 
        Properties[1] = 0
      end
    end
  end

  self = nil
  Grid.CurrentRoute = nil
end

-- Called when pathfinding algorithm is complete
function Route:Complete(CompletedRoute)
  local Node = self._EndNode

  -- Use a stack to reverse the route (it is reversed by the dijkstra algorithm by default)
  local RouteStack = Stack.new()

  local Length = 0
  while true do
    local Prev = CompletedRoute[Node.y][Node.x]
    if Prev then
      RouteStack:Push({x=Prev.x, y=Prev.y})
      Node = Prev

      Length = Length + 1
    else
      break
    end
  end
  self._Length = Length


  --Overrides initial :Update() method
  function self:Update()
    local Next = RouteStack:Pop()
    if Next then
      local NodeType = Grid.GridTbl[Next.y][Next.x][1]
      if NodeType ~= 2 and NodeType ~= 3 then
        Grid:PlaceNode(Next.x, Next.y, 4)
      end
    else
      for y, yTbl in next, Grid.GridTbl do
        for x, Properties in next, yTbl do
          if Properties[1] == 5 then 
            Properties[1] = 0
          end
        end
      end

      self._Completed = true
      return true 
    end
  end
end

-- Returns length of the route
function Route:GetLength()
  return self._Length
end

-- Returns completion status of the route
function Route:IsCompleted()
  return self._Completed
end

--:://Grid class
--:://private methods
-- Initializes the grid, called upon program opening
function Grid:_CreateGrid() 
  self.GridTbl = {}
  self.CurrentMapID = nil
  self.DrawingMode = 1
  self.DrawingModeColors = {
    {0,0,0},
    {0,1,.15},
    {1,.2,0},
    {.95,.95,.35}, -- path
    {1, 1,.5} -- calculating path
  }

  local xCells, yCells = self:GetDimensions()

  -- Three dimensional array
  for y = 0, yCells-1 do
    local xCoordinates = {} -- represents a row of cells
    for x = 0, xCells-1 do
      xCoordinates[x] = {0, 1} -- represents a single cell: drawingMode, size, animationPlayed
    end
    Grid.GridTbl[y] = xCoordinates
  end
end

--Dijkstra Algorithm
function Grid:_Dijkstra(source, nodeGoal) -- source {x,y}
  local Distances = {}
  local Prev = {}
  local Queue = {}
  local Paths = {}

  for y, yTbl in next, Grid.GridTbl do
    Distances[y] = {}
    Prev[y] = {}
    for x, _ in next, yTbl do
      Distances[y][x] = math.huge
      Prev[y][x] = nil
      table.insert(Queue, {y=y,x=x})
    end
  end
  Distances[source.y][source.x] = 0

  --should be called on every update
  return function()
    local ClosestDist, Node, QueueIndex = math.huge, nil, nil -- node with minimum Distance
    for i, coords in next, Queue do
      local Dist = Distances[coords.y][coords.x]
      if Dist < ClosestDist then
        ClosestDist, Node, QueueIndex = Dist, coords, i
      end
    end
  
    table.remove(Queue, QueueIndex)
    if Node ~= nil then
      --gets node's Neighbours
      local NodeNeighbours = {
        Grid:_GetEmptyCell(Node.x-1,Node.y),
        Grid:_GetEmptyCell(Node.x+1,Node.y),
        Grid:_GetEmptyCell(Node.x,Node.y+1),
        Grid:_GetEmptyCell(Node.x,Node.y-1)
      }
  
      for _, Neighbour in next, NodeNeighbours do
        local Dist = (math.abs(Node.x - Neighbour.x)^2 + math.abs(Node.y-Neighbour.y)^2)^(1/2) -- using pythagoras to get the Distance
        local Alt = Distances[Node.y][Node.x] + Dist
  
        if Alt < Distances[Neighbour.y][Neighbour.x] then
          Distances[Neighbour.y][Neighbour.x] = Alt
          Prev[Neighbour.y][Neighbour.x] = Node
  
          --visually displaying pathfinding progress
          if Grid.GridTbl[Neighbour.y][Neighbour.x][1] == 0 then
            Grid.GridTbl[Neighbour.y][Neighbour.x][1] = 5
            Grid.GridTbl[Neighbour.y][Neighbour.x][3] = false
          end
        end
      end
    end 

    if #Queue == 0 then
      --return the path array when the Queue is empty
      return Prev
    end
  end
end

--gets an 'empty' cell i.e a cell that can be traversed
function Grid:_GetEmptyCell(x, y)
  if Grid.GridTbl[y] and Grid.GridTbl[y][x] and Grid.GridTbl[y][x][1] ~= 1 then
    return {y=y, x=x}--Grid.GridTbl[y][x]
  end
end

--::// public methods
function Grid:GetDimensions()
  local ScreenSizeX, ScreenSizeY = UI.GetDimensions()
  Grid.CellSize = ScreenSizeX * 0.05

  local xCells = math.floor(ScreenSizeX/Grid.CellSize)
  local yCells = math.floor(ScreenSizeY/Grid.CellSize)

  return xCells, yCells
end

--Called on every update
function Grid:Update(dt)
  if self.CurrentRoute and self.CurrentRoute:IsCompleted() == false  then
    local Settings = UserData.GetSettings()

    --Pathfinding speed affects how many times the pathfinding algorithm is called per update

    for i = 1, Settings.PathfindingSpeed do
      self.CurrentRoute:Update()
    end
  end
end

--Get the start and end points if there are any
function Grid:GetStartEndPoints()
  local startPoint = nil
  local endPoint = nil

  for y,tbl in next, self.GridTbl do
    for x,Properties in next, tbl do
      if Properties[1] == 2 then
        startPoint = {x=x,y=y}
      elseif Properties[1] == 3 then
        endPoint = {x=x, y=y}
      end
    end
  end

  return startPoint, endPoint
end

--Called when the 'find route' Button is pressed
function Grid:FindRoute()
  if self.CurrentRoute and self.CurrentRoute:IsCompleted() == false then return end -- ensure no routes can be started while one is active

  local startPoint, endPoint = self:GetStartEndPoints()

  if startPoint~=nil and endPoint~=nil then
    local route = Route.new(startPoint, endPoint)
    self.CurrentRoute = route
  end
end

--Renders the grid
function Grid:DrawGrid()
  local ScreenSizeX, ScreenSizeY = UI.GetDimensions()
  local MouseX, MouseY = love.mouse:getPosition()
  local HoveredX, HoveredY = math.floor(MouseX/Grid.CellSize), math.floor(MouseY/Grid.CellSize) -- cell the mouse is hovering over

  for y,tbl in next, Grid.GridTbl do
    for x,Properties in next, tbl do
      love.graphics.setColor(Grid.DrawingModeColors[Properties[1]] or {0,0,0})

      if Properties[1] == 0 then --cancel animation if empty
        Properties[2] = 1
        Properties[3] = true
      else
        if Properties[3] == false then
          Properties[3] = true

          Properties[2] = 1.5
          tween.new(.5, Properties, {[2]=1}, "outCubic") --animate the size
        end
      end
      local sizeMultiplier = Properties[2]
      love.graphics.rectangle(Properties[1] == 0 and "line" or "fill", x*Grid.CellSize - (Grid.CellSize*(sizeMultiplier-1)/2),y*Grid.CellSize - (Grid.CellSize*(sizeMultiplier-1)/2),Grid.CellSize*sizeMultiplier,Grid.CellSize*sizeMultiplier)
    end
  end
  love.graphics.setColor({1,0,0})
  love.graphics.print(HoveredX .. ", " .. HoveredY, ScreenSizeX - 40,ScreenSizeY - 20)
end

--Clear all nodes, called when 'clear' Button is pressed
function Grid:Clear()
  self:ClearCurrentRoute()

  for y,tbl in next, self.GridTbl do
    for x,Properties in next, tbl do
      self.GridTbl[y][x][1] = 0
    end
  end
end

-- Removes the current route
function Grid:ClearCurrentRoute()
  if Grid.CurrentRoute then
    Grid.CurrentRoute:Destroy()
  end
end

function Grid:PlaceNode(x,y, NodeType)
  NodeType = NodeType or self.DrawingMode

  if NodeType == 2 or NodeType == 3 then
    --ensuring there is only ONE start point and ONE end point for route finding
    for y,tbl in next, self.GridTbl do
      for x,Properties in next, tbl do
        if Properties[1] == NodeType then
          self.GridTbl[y][x][1] = 0
        end
      end
    end
  end

  self.GridTbl[y][x][1] = NodeType
  self.GridTbl[y][x][3] = false
end

-- Checking for user input
function Grid:RegisterInput()
  local MouseX, MouseY = love.mouse:getPosition()
  local HoveredX, HoveredY = math.floor(MouseX/self.CellSize), math.floor(MouseY/self.CellSize)

  if love.mouse.isDown(1) then
    self:ClearCurrentRoute()

    -- Places a node at mouse position
    if self.GridTbl[HoveredY][HoveredX][1] ~= self.DrawingMode then
      self:PlaceNode(HoveredX, HoveredY)
    end
  elseif love.mouse.isDown(2) then  
    self:ClearCurrentRoute()

    -- Attempt to clear selected node at mouse position
    self.GridTbl[HoveredY][HoveredX][1] = 0
  end
end

  -- Loads a map from a given Map ID
function Grid:LoadMapSave(MapID)
  UserData.SQLExec(string.format([[SELECT * FROM MapsTbl WHERE MapID=%d;]], MapID), function(udata, cols, values, names)
    local Record = {}
    for i=1,cols do
      Record[names[i]] = values[i]
    end

    local SerializedMapID = Record.SerializedMapID
    love.filesystem.setIdentity("mapsaves")

    local SerializedMap = love.filesystem.read(SerializedMapID)

    -- Decodes the map from JSON format
    local DecodedMap = json.decode(SerializedMap)

    for y, yTbl in next, DecodedMap do
      for x, NodeType in next, yTbl do
        self.GridTbl[tonumber(y)][tonumber(x)][1] = NodeType
      end
    end

    return 0
  end)

  self.CurrentMapID = tonumber(MapID)
end

-- Encodes the grid for data saving
function Grid:GetGridData()
  local Data = {} 

  for y, yTbl in next, self.GridTbl do
    Data[tostring(y)] = {}
    for x, Properties in next, yTbl do
      Data[tostring(y)][tostring(x)] = Properties[1]
    end
  end

  return Data
end

Grid:_CreateGrid()

return Grid