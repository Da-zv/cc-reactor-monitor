local reactor = peripheral.find("BigReactors-Reactor")
local monitor = peripheral.find("monitor") 
local REDSTONE_SIDE = "top"

-- Update rate of the program in seconds
-- def: 0.25
local UPDATE_RATE = 0.25

assert(reactor, "reactor not found on the left")
assert(monitor, "monitor not found")


-- Tables for circural buffers
local generatedHistory = {
values = {},
sum = 0,
index = 1
}

local storedHistory = {
values = {},
sum = 0,
index = 1
}
--

-- Status of the reactor
local status = {
    stored = reactor.getEnergyStored(),
    generated = reactor.getEnergyProducedLastTick(),
    fuel = reactor.getFuelAmount(),
    waste = reactor.getWasteAmount(),
    consumed = reactor.getFuelConsumedLastTick()
}

-- Update the status
local function updateStatus()
    status.stored = reactor.getEnergyStored()
    status.generated = reactor.getEnergyProducedLastTick()
    status.fuel = reactor.getFuelAmount()
    status.waste = reactor.getWasteAmount()
    status.consumed = reactor.getFuelConsumedLastTick()
end

-- Line at which UI elements should be
-- For now its a Label Y position then value is Y+1 (below the label)
local UI = {
    storedY = 1,
    generatedY = 4,
    fuelY = 7,
    wasteY = 9,
    efficiencyY = 12,
    barWidth = 20
}
-- Monitor scale
local OFFLINE_SCALE = 5
local ONLINE_SCALE = 1.5

-- size of the buffer for average
local BUFFER_SIZE = 20

local MAX_FUEL = reactor.getFuelAmountMax()
local MAX_ENERGY = reactor.getEnergyCapacity()

-- functions

local function round(num, decimals)
    local mult = 10^(decimals or 0)
    return math.floor(num * mult + 0.5) / mult 
end

local function getAverage(tbl, newest)
    tbl.sum = tbl.sum - tbl.values[tbl.index]
    tbl.values[tbl.index] = newest
    tbl.sum = tbl.sum + newest
    
    tbl.index = tbl.index + 1
    if tbl.index > BUFFER_SIZE then
        tbl.index = 1
    end

    return tbl.sum/BUFFER_SIZE
end    

local function formatValue(value, sign)
    sign = sign or ""
    return string.format("%-20s", round(value,2) .. sign)
end

local function getPercent(value, max)
    if max <= 0 then
        return 0
    end
    
    return math.max(0, math.min((value/max)*100, 100))
end

local function makeBar(size, percent)
    assert(size, "makeBar: size is nil")
    assert(percent, "makeBar: percent is nil") 
    
    local formatString = "%-" .. size .. "s"
    local filled = math.floor(size * percent / 100)
    return "[" .. string.format(formatString, string.rep("#", filled)) .. "] "
end

-- Check if active
local function displayOffline()
    monitor.clear()
    monitor.setCursorPos(1,1)
    monitor.setTextScale(OFFLINE_SCALE)
    monitor.write("Offline")
end

-- Prepare the monitor:
local function prepareMonitor()
    monitor.clear()

    monitor.setTextScale(ONLINE_SCALE)

    monitor.setCursorPos(1, UI.storedY)
    monitor.write("Stored energy: ")

    monitor.setCursorPos(1, UI.generatedY)
    monitor.write("Generated: ")

    monitor.setCursorPos(1, UI.fuelY)
    monitor.write("Fuel: ")

    monitor.setCursorPos(1, UI.wasteY)
    monitor.write("Waste: ")

    monitor.setCursorPos(1, UI.efficiencyY)
    monitor.write("efficiency: ")
end


-- Prepare data:
for i = 1, BUFFER_SIZE do
    updateStatus()
    generatedHistory.values[i] = status.generated
    generatedHistory.sum = generatedHistory.sum + status.generated

    storedHistory.values[i] = status.stored
    storedHistory.sum = storedHistory.sum + status.stored
end

local function displayOnline()
    
    local avgGenerated = getAverage(generatedHistory, status.generated)

    local avgStored = getAverage(storedHistory, status.stored) 
    local energyPercent = getPercent(avgStored, MAX_ENERGY)
    local fuelPercent = getPercent(status.fuel, MAX_FUEL)
    
    -- Energy stored update
    monitor.setCursorPos(1, UI.storedY+1)
    monitor.write(makeBar(UI.barWidth, energyPercent))
    monitor.write(formatValue(energyPercent, "%"))
    --
    
    -- Energy generated last tick
    monitor.setCursorPos(1, UI.generatedY+1)
    monitor.write(formatValue((avgGenerated), " FE/t"))
    --

    -- Fuel
    monitor.setCursorPos(1, UI.fuelY+1)
    monitor.write(formatValue(fuelPercent, "%"))

    -- Output redstone if fuel < 90%, stop if fuel > 95%
    if status.fuel < MAX_FUEL*0.90 then
        redstone.setAnalogOutput(REDSTONE_SIDE, 15)
    elseif status.fuel >= MAX_FUEL * 0.95 then
        redstone.setAnalogOutput(REDSTONE_SIDE, 0)
    end 
    --
    
    -- Waste
    monitor.setCursorPos(1, UI.wasteY+1)
    monitor.write(formatValue(status.waste))    
    --
    
    -- Efficiency
    monitor.setCursorPos(1, UI.efficiencyY+1)
    if status.consumed > 0 then
    monitor.write(formatValue((status.generated/status.consumed), " FE/mB"))
    else
        monitor.write("N/A")
    end
    --
end

-- Main loop start
prepareMonitor()
while true do    
    if not reactor.getActive() then
        displayOffline()
        while not reactor.getActive() do    
        sleep(1)
        end
        prepareMonitor()
    end
    
    updateStatus()
    displayOnline()
    
    sleep(UPDATE_RATE)
end 










