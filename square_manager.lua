local square    = require('square');
local primitives = require('primitives');
local structOffset = 12;
local structWidth = 1156;

--Thanks to Velyn for the event system and interface hidden signatures!
local pGameMenu = ashita.memory.find('FFXiMain.dll', 0, "8B480C85C974??8B510885D274??3B05", 16, 0);
local pEventSystem = ashita.memory.find('FFXiMain.dll', 0, "A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3", 0, 0);
local pInterfaceHidden = ashita.memory.find('FFXiMain.dll', 0, "8B4424046A016A0050B9????????E8????????F6D81BC040C3", 0, 0);

local function GetMenuName()
    local subPointer = ashita.memory.read_uint32(pGameMenu);
    local subValue = ashita.memory.read_uint32(subPointer);
    if (subValue == 0) then
        return '';
    end
    local menuHeader = ashita.memory.read_uint32(subValue + 4);
    local menuName = ashita.memory.read_string(menuHeader + 0x46, 16);
    return string.gsub(menuName, '\x00', '');
end

local function GetEventSystemActive()
    if (pEventSystem == 0) then
        return false;
    end
    local ptr = ashita.memory.read_uint32(pEventSystem + 1);
    if (ptr == 0) then
        return false;
    end

    return (ashita.memory.read_uint8(ptr) == 1);

end

local function GetInterfaceHidden()
    if (pEventSystem == 0) then
        return false;
    end
    local ptr = ashita.memory.read_uint32(pInterfaceHidden + 10);
    if (ptr == 0) then
        return false;
    end

    return (ashita.memory.read_uint8(ptr + 0xB4) == 1);
end

local function GetButtonAlias(comboIndex, buttonIndex)
    local macroComboBinds = {
        [1] = 'L2',
        [2] = 'R2',
        [3] = 'L2R2',
        [4] = 'R2L2',
        [5] = 'L2x2',
        [6] = 'R2x2',
        [7] = 'L1',
        [8] = 'R1',
        [9] = 'L1R1',
        [10] = 'R1L1',
        [11] = 'L1x2',
        [12] = 'R1x2'
    };
    return string.format('%s:%d', macroComboBinds[comboIndex], buttonIndex);
end

local SquareManager = {};
SquareManager.Squares = T{};

function SquareManager:Initialize(layout, singleStruct1, doubleStruct1, singleStruct2, doubleStruct2)
    self.SingleStruct1 = ffi.cast('AbilitySquarePanelState_t*', singleStruct1);
    self.DoubleStruct1 = ffi.cast('AbilitySquarePanelState_t*', doubleStruct1);
    self.SingleStruct2 = ffi.cast('AbilitySquarePanelState_t*', singleStruct2);
    self.DoubleStruct2 = ffi.cast('AbilitySquarePanelState_t*', doubleStruct2);
    self.Layout = layout;
    self.Hidden = false;

    self.SinglePrimitives1 = T{};
    for _,primitiveInfo in ipairs(layout.SingleDisplay1.Primitives) do
        local prim = {
            Object = primitives.new(primitiveInfo),
            OffsetX = primitiveInfo.OffsetX,
            OffsetY = primitiveInfo.OffsetY,
        };
        self.SinglePrimitives1:append(prim);
    end

    self.DoublePrimitives1 = T{};
    for _,primitiveInfo in ipairs(layout.DoubleDisplay1.Primitives) do
        local prim = {
            Object = primitives.new(primitiveInfo),
            OffsetX = primitiveInfo.OffsetX,
            OffsetY = primitiveInfo.OffsetY,
        };
        self.DoublePrimitives1:append(prim);
    end

    self.SinglePrimitives2 = T{};
    for _,primitiveInfo in ipairs(layout.SingleDisplay2.Primitives) do
        local prim = {
            Object = primitives.new(primitiveInfo),
            OffsetX = primitiveInfo.OffsetX,
            OffsetY = primitiveInfo.OffsetY,
        };
        self.SinglePrimitives2:append(prim);
    end

    self.DoublePrimitives2 = T{};
    for _,primitiveInfo in ipairs(layout.DoubleDisplay2.Primitives) do
        local prim = {
            Object = primitives.new(primitiveInfo),
            OffsetX = primitiveInfo.OffsetX,
            OffsetY = primitiveInfo.OffsetY,
        };
        self.DoublePrimitives2:append(prim);
    end

    self.Squares = T{
        [1] = {},
        [2] = {},
        [7] = {},
        [8] = {},
    };


    local count = 0;
    for _,squareInfo in ipairs(layout.DoubleDisplay1.Squares) do
        local buttonIndex = (count < 8) and (count + 1) or (count - 7);
        local tableIndex = (count < 8) and 1 or 2;

        local singlePointer = ffi.cast('AbilitySquareState_t*', singleStruct1 + structOffset + (structWidth * (buttonIndex - 1)));
        local doublePointer = ffi.cast('AbilitySquareState_t*', doubleStruct1 + structOffset + (structWidth * count));

        local newSquare = square:New(doublePointer, GetButtonAlias(tableIndex, buttonIndex));
        newSquare.SinglePointer = singlePointer;
        newSquare.DoublePointer = doublePointer;

        count = count + 1;
        newSquare.MinX = squareInfo.OffsetX + layout.DoubleDisplay1.ImageObjects.Frame.OffsetX;
        newSquare.MaxX = newSquare.MinX + layout.DoubleDisplay1.ImageObjects.Frame.Width;
        newSquare.MinY = squareInfo.OffsetY + layout.DoubleDisplay1.ImageObjects.Frame.OffsetY;
        newSquare.MaxY = newSquare.MinY + layout.DoubleDisplay1.ImageObjects.Frame.Height;
        self.Squares[tableIndex][buttonIndex] = newSquare;
    end
    for i = 3,6 do
        self.Squares[i] = T{};
        count = 0;
        for _,squareInfo in ipairs(layout.SingleDisplay1.Squares) do
            local buttonIndex = count + 1;
            local singlePointer = ffi.cast('AbilitySquareState_t*', singleStruct1 + structOffset + (structWidth * count));
            local newSquare = square:New(singlePointer, GetButtonAlias(i, buttonIndex));
            newSquare.MinX = squareInfo.OffsetX + layout.SingleDisplay1.ImageObjects.Frame.OffsetX;
            newSquare.MaxX = newSquare.MinX + layout.SingleDisplay1.ImageObjects.Frame.Width;
            newSquare.MinY = squareInfo.OffsetY + layout.SingleDisplay1.ImageObjects.Frame.OffsetY;
            newSquare.MaxY = newSquare.MinY + layout.SingleDisplay1.ImageObjects.Frame.Height;
            self.Squares[i][buttonIndex] = newSquare;
            count = count + 1;
        end
    end
    local count = 0;
    for _,squareInfo in ipairs(layout.DoubleDisplay2.Squares) do
        local buttonIndex = (count < 8) and (count + 1) or (count - 7);
        local tableIndex = (count < 8) and 7 or 8;

        local singlePointer = ffi.cast('AbilitySquareState_t*', singleStruct2 + structOffset + (structWidth * (buttonIndex - 1)));
        local doublePointer = ffi.cast('AbilitySquareState_t*', doubleStruct2 + structOffset + (structWidth * count));

        local newSquare = square:New(doublePointer, GetButtonAlias(tableIndex, buttonIndex));
        newSquare.SinglePointer = singlePointer;
        newSquare.DoublePointer = doublePointer;

        count = count + 1;
        newSquare.MinX = squareInfo.OffsetX + layout.DoubleDisplay2.ImageObjects.Frame.OffsetX;
        newSquare.MaxX = newSquare.MinX + layout.DoubleDisplay2.ImageObjects.Frame.Width;
        newSquare.MinY = squareInfo.OffsetY + layout.DoubleDisplay2.ImageObjects.Frame.OffsetY;
        newSquare.MaxY = newSquare.MinY + layout.DoubleDisplay2.ImageObjects.Frame.Height;
        self.Squares[tableIndex][buttonIndex] = newSquare;
    end
    for i = 9,12 do
        self.Squares[i] = T{};
        count = 0;
        for _,squareInfo in ipairs(layout.SingleDisplay2.Squares) do
            local buttonIndex = count + 1;
            local singlePointer = ffi.cast('AbilitySquareState_t*', singleStruct2 + structOffset + (structWidth * count));
            local newSquare = square:New(singlePointer, GetButtonAlias(i, buttonIndex));
            newSquare.MinX = squareInfo.OffsetX + layout.SingleDisplay2.ImageObjects.Frame.OffsetX;
            newSquare.MaxX = newSquare.MinX + layout.SingleDisplay2.ImageObjects.Frame.Width;
            newSquare.MinY = squareInfo.OffsetY + layout.SingleDisplay2.ImageObjects.Frame.OffsetY;
            newSquare.MaxY = newSquare.MinY + layout.SingleDisplay2.ImageObjects.Frame.Height;
            self.Squares[i][buttonIndex] = newSquare;
            count = count + 1;
        end
    end
end

function SquareManager:GetSquareByButton(macroState, macroIndex)
    local squareSet = self.Squares[macroState];
    if (squareSet ~= nil) then
        local square = squareSet[macroIndex];
        if (square ~= nil) then
            return square;
        end
    end
end

function SquareManager:Activate(macroState, button)
    local square = self:GetSquareByButton(macroState, button);
    if square then
        square:Activate();
    end
end

function SquareManager:Destroy()
    for _,squareSet in ipairs(self.Squares) do
        for _,square in ipairs(squareSet) do
            square:Destroy();
        end
    end

    if (type(self.SinglePrimitives1) == 'table') then
        for _,primitive in ipairs(self.SinglePrimitives1) do
            primitive.Object:destroy();
        end
        self.SinglePrimitives1 = nil;
    end
    if (type(self.DoublePrimitives1) == 'table') then
        for _,primitive in ipairs(self.DoublePrimitives1) do
            primitive.Object:destroy();
        end
        self.DoublePrimitives1 = nil;
    end
    if (type(self.SinglePrimitives2) == 'table') then
        for _,primitive in ipairs(self.SinglePrimitives2) do
            primitive.Object:destroy();
        end
        self.SinglePrimitives2 = nil;
    end
    if (type(self.DoublePrimitives2) == 'table') then
        for _,primitive in ipairs(self.DoublePrimitives2) do
            primitive.Object:destroy();
        end
        self.DoublePrimitives2 = nil;
    end

    self.SingleStruct1 = nil;
    self.DoubleStruct1 = nil;
    self.SingleStruct2 = nil;
    self.DoubleStruct2 = nil;
end

function SquareManager:GetHidden()
    if (self.SingleStruct1 == nil) or (self.DoubleStruct1 == nil) or (self.SingleStruct2 == nil) or (self.DoubleStruct2 == nil) then
        return true;
    end

    if (gSettings.HideWhileZoning) then
        if (gPlayer:GetLoggedIn() == false) then
            return true;
        end
    end

    if (gSettings.HideWhileCutscene) then
        if (GetEventSystemActive()) then
            return true;
        end
    end

    if (gSettings.HideWhileMap) then
        if (string.match(GetMenuName(), 'map')) then
            return true;
        end
    end

    if (GetInterfaceHidden()) then
        return true;
    end

    return false;
end

function SquareManager:HidePrimitives(primitives)
    for _,primitive in ipairs(primitives) do
        primitive.Object.visible = false;
    end
end

function SquareManager:HitTest(x, y)
    local pos, width, height, type;
    if (self.DoubleDisplay1 == true) then
        pos = gSettings.Position[gSettings.Layout].DoubleDisplay1;
        width = self.Layout.DoubleDisplay1.PanelWidth;
        height = self.Layout.DoubleDisplay1.PanelHeight;
        type = 'DoubleDisplay1'; -- TODO
    elseif (self.SingleDisplay1 == true) then
        pos = gSettings.Position[gSettings.Layout].SingleDisplay1;
        width = self.Layout.SingleDisplay1.PanelWidth;
        height = self.Layout.SingleDisplay1.PanelHeight;
        type = 'SingleDisplay1';
    elseif (self.DoubleDisplay2 == true) then
        pos = gSettings.Position[gSettings.Layout].DoubleDisplay2;
        width = self.Layout.DoubleDisplay2.PanelWidth;
        height = self.Layout.DoubleDisplay2.PanelHeight;
        type = 'DoubleDisplay2';
    elseif (self.SingleDisplay2 == true) then
        pos = gSettings.Position[gSettings.Layout].SingleDisplay2;
        width = self.Layout.SingleDisplay2.PanelWidth;
        height = self.Layout.SingleDisplay2.PanelHeight;
        type = 'SingleDisplay2';
    end

    if (pos ~= nil) then
        if (x >= pos[1]) and (y >= pos[2]) then
            local offsetX = x - pos[1];
            local offsetY = y - pos[2];
            if (offsetX < width) and (offsetY < height) then
                return true, type;
            end
        end
    end

    return false;
end

function SquareManager:Tick()
    self.SingleDisplay1 = true;
    self.SingleDisplay2 = true;
    self.DoubleDisplay1 = true;
    self.DoubleDisplay2 = true;

    if (self:GetHidden()) then
        self:HidePrimitives(self.SinglePrimitives1);
        self:HidePrimitives(self.DoublePrimitives1);
        self:HidePrimitives(self.SinglePrimitives2);
        self:HidePrimitives(self.DoublePrimitives2);
        return;
    end

    local macroState = gController:GetMacroState();
    if (gBindingGUI:GetActive()) then
        macroState = gBindingGUI:GetMacroState();
    end

    if (macroState > 0 and gSettings.SwapToSingleDisplay) then
        if (macroState < 7) then
            self.SingleDisplay2 = false;
        else
            self.SingleDisplay1 = false;
        end
        self.DoubleDisplay1 = false;
        self.DoubleDisplay2 = false;
    end

    if (self.SingleDisplay1) then
        local tableIndex = macroState
        if (tableIndex == 0) or (not gSettings.SwapToSingleDisplay) then
            tableIndex = 3
        end
        for _,squareClass in ipairs(self.Squares[tableIndex]) do
            if (tableIndex > 0 and tableIndex < 3) then
                squareClass.StructPointer = squareClass.SinglePointer;
                squareClass.Updater.StructPointer = squareClass.SinglePointer;
            end
            squareClass:Update();
        end
        local pos = gSettings.Position[gSettings.Layout].SingleDisplay1;
        self.SingleStruct1.PositionX = pos[1];
        self.SingleStruct1.PositionY = pos[2];
        self.SingleStruct1.Render = 1;
        self:UpdatePrimitives(self.SinglePrimitives1, pos);
    else
        self:HidePrimitives(self.SinglePrimitives1);
    end
    if (self.DoubleDisplay1) then
        for _,tableIndex in ipairs(T{1, 2}) do
            for _,squareClass in ipairs(self.Squares[tableIndex]) do
                squareClass.StructPointer = squareClass.DoublePointer;
                squareClass.Updater.StructPointer = squareClass.DoublePointer;
                squareClass:Update();
            end
        end
        local pos = gSettings.Position[gSettings.Layout].DoubleDisplay1;
        self.DoubleStruct1.PositionX = pos[1];
        self.DoubleStruct1.PositionY = pos[2];
        self.DoubleStruct1.Render = 1;
        self:UpdatePrimitives(self.DoublePrimitives1, pos);
    else
        self:HidePrimitives(self.DoublePrimitives1);
    end

    if (self.SingleDisplay2) then
        local tableIndex = macroState
        if (tableIndex == 0) or (not gSettings.SwapToSingleDisplay) then
            tableIndex = 9
        end
        for _,squareClass in ipairs(self.Squares[tableIndex]) do
            if (tableIndex > 6 and tableIndex < 9) then
                squareClass.StructPointer = squareClass.SinglePointer;
                squareClass.Updater.StructPointer = squareClass.SinglePointer;
            end
            squareClass:Update();
        end
        local pos = gSettings.Position[gSettings.Layout].SingleDisplay2;
        self.SingleStruct2.PositionX = pos[1];
        self.SingleStruct2.PositionY = pos[2];
        self.SingleStruct2.Render = 1;
        self:UpdatePrimitives(self.SinglePrimitives2, pos);
    else
        self:HidePrimitives(self.SinglePrimitives2);
    end
    if (self.DoubleDisplay2) then
        for _,tableIndex in ipairs(T{7, 8}) do
            for _,squareClass in ipairs(self.Squares[tableIndex]) do
                squareClass.StructPointer = squareClass.DoublePointer;
                squareClass.Updater.StructPointer = squareClass.DoublePointer;
                squareClass:Update();
            end
        end
        local pos = gSettings.Position[gSettings.Layout].DoubleDisplay2;
        self.DoubleStruct2.PositionX = pos[1];
        self.DoubleStruct2.PositionY = pos[2];
        self.DoubleStruct2.Render = 1;
        self:UpdatePrimitives(self.DoublePrimitives2, pos);
    else
        self:HidePrimitives(self.DoublePrimitives2);
    end
end

function SquareManager:UpdateBindings(bindings)
    for comboKey,squareSet in ipairs(self.Squares) do
        for buttonKey,square in ipairs(squareSet) do
            square:UpdateBinding(bindings[GetButtonAlias(comboKey, buttonKey)]);
        end
    end
end

function SquareManager:UpdatePrimitives(primitives, position)
    for _,primitive in ipairs(primitives) do
        primitive.Object.position_x = position[1] + primitive.OffsetX;
        primitive.Object.position_y = position[2] + primitive.OffsetY;
        primitive.Object.visible = true;
    end
end

return SquareManager;