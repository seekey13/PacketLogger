--[[
PacketLogger - Configuration UI Module
ImGui-based configuration interface for the PacketLogger addon
]]

local config_ui = {};
local imgui = require('imgui');

-- ============================================================================
-- State
-- ============================================================================

local config_ui_visible = { true };

-- Settings reference (set via init)
local settings = nil;
local update_settings_fn = nil;

-- ============================================================================
-- UI Constants
-- ============================================================================

local MIN_WINDOW_WIDTH = 300;
local MIN_WINDOW_HEIGHT = 200;
local MAX_WINDOW_WIDTH = 600;
local MAX_WINDOW_HEIGHT = 800;

-- ============================================================================
-- Packet Filter Definitions
-- ============================================================================

local PACKET_FILTERS = {
    -- High-Frequency Position/Movement Updates
    { id = 13, name = '0x00D - NPC Update' },
    { id = 14, name = '0x00E - Entity Update' },
    { id = 15, name = '0x00F - Entity Movement Complete' },
    { id = 21, name = '0x015 - Data Download' },
    
    -- Combat/Action Updates
    { id = 40, name = '0x028 - Action' },
    { id = '0x028_0x1844', name = '0x028 (0x1844) - Autoattack' },
    { id = '0x028_0x58E0', name = '0x028 (0x58E0) - Healing/Regen' },
    { id = 41, name = '0x029 - Message' },
    { id = 118, name = '0x076 - Party Effects Update' },
    
    -- Inventory/Equipment
    { id = 30, name = '0x01E - Modify Inventory' },
    { id = 31, name = '0x01F - Item Update' },
    { id = 32, name = '0x020 - Inventory Finish' },
    { id = 80, name = '0x050 - Equipment Update' },
    
    -- UI/Menu Updates
    { id = 52, name = '0x034 - Char Appearance' },
    { id = 55, name = '0x037 - Character Update' },
    { id = 97, name = '0x061 - Server Message' },
    { id = 99, name = '0x063 - Party Status Icons' },
    
    -- Zone/Loading
    { id = 10, name = '0x00A - Zone In' },
    { id = 11, name = '0x00B - Zone Out' },
    { id = 29, name = '0x01D - Server IP' },
    
    -- Chat/Communication
    { id = 23, name = '0x017 - Chat Message' },
    { id = 27, name = '0x01B - Server Message' },
    
    -- Additional Common Packets
    { id = 103, name = '0x067 - Examine' },
    { id = 223, name = '0x0DF - Character Stats' },
    { id = 281, name = '0x119 - Chat Channel' },
};

-- ============================================================================
-- UI State Variables (for imgui)
-- ============================================================================

-- Create checkbox state for each packet filter (default enabled)
local filter_states = {};
for i, filter in ipairs(PACKET_FILTERS) do
    filter_states[filter.id] = { true };
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Sync UI state from settings
local function sync_from_settings()
    if not settings or not settings.filtered_packets then return end
    
    -- Reset all filter states to false
    for id, state in pairs(filter_states) do
        state[1] = false;
    end
    
    -- Set filter states based on settings
    for _, packet_id in ipairs(settings.filtered_packets) do
        if filter_states[packet_id] then
            filter_states[packet_id][1] = true;
        end
    end
end

-- Sync settings from UI state
local function sync_to_settings()
    if not settings then return end
    
    settings.filtered_packets = {};
    
    -- Build filtered packets list from UI state
    for id, state in pairs(filter_states) do
        if state[1] then
            table.insert(settings.filtered_packets, id);
        end
    end
    
    if update_settings_fn then 
        update_settings_fn();
    end
end

-- ============================================================================
-- Module Functions
-- ============================================================================

-- Initialize the module with settings reference and update function
-- Args:
--   s (table) - Reference to the settings table
--   update_fn (function) - Function to call when settings are updated
function config_ui.init(s, update_fn)
    settings = s;
    update_settings_fn = update_fn;
    
    -- If no filters set, enable all by default
    if not settings.filtered_packets or #settings.filtered_packets == 0 then
        for i, filter in ipairs(PACKET_FILTERS) do
            table.insert(settings.filtered_packets, filter.id);
        end
    end
    
    sync_from_settings();
end

-- Check if the config window is visible
-- Returns: boolean
function config_ui.is_visible()
    return config_ui_visible[1];
end

-- Open the config window
function config_ui.open()
    sync_from_settings();
    config_ui_visible[1] = true;
end

-- Close the config window
function config_ui.close()
    config_ui_visible[1] = false;
end

-- Render the config UI (call from d3d_present event)
function config_ui.render()
    if not config_ui_visible[1] then
        return;
    end
    
    if not settings then
        return;
    end
    
    -- Set window flags for auto-sizing
    imgui.SetNextWindowSizeConstraints({ MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT }, { MAX_WINDOW_WIDTH, MAX_WINDOW_HEIGHT });
    
    if imgui.Begin('PacketLogger Filters', config_ui_visible, ImGuiWindowFlags_AlwaysAutoResize) then
        imgui.Text('Check packets to FILTER OUT (not log):');
        imgui.Separator();
        
        -- Render checkboxes for each packet filter
        for i, filter in ipairs(PACKET_FILTERS) do
            if imgui.Checkbox(filter.name, filter_states[filter.id]) then
                sync_to_settings();
            end
        end
    end
    imgui.End();
end

return config_ui;
