--[[
PacketLogger
Logs incoming FFXI packets to a text file for analysis.
Copyright (c) 2025 Seekey
https://github.com/seekey13/PacketLogger

This addon is designed for Ashita v4.
]]

addon.name      = 'PacketLogger';
addon.author    = 'Seekey';
addon.version   = '1.0';
addon.desc      = 'Log incoming FFXI packets to file';
addon.link      = 'https://github.com/seekey13/PacketLogger';

require('common');
local chat = require('chat');

-- ============================================================================
-- State Management
-- ============================================================================

local logger = {
    enabled = false,
    log_file = nil,
    log_path = nil,
    packet_filter = {},  -- Empty = log all packets, or table of IDs to log
    packet_count = 0,
    start_time = 0,
};

-- ============================================================================
-- File Management
-- ============================================================================

-- Initialize log file
local function init_log_file()
    -- Create logs directory if it doesn't exist
    local log_dir = string.format('%sconfig\\addons\\%s\\', AshitaCore:GetInstallPath(), addon.name)
    os.execute(string.format('mkdir "%s" 2>nul', log_dir))
    
    -- Create log file with timestamp
    logger.log_path = string.format('%spacketlog_%s.txt', log_dir, os.date('%Y%m%d_%H%M%S'))
    logger.log_file = io.open(logger.log_path, 'w')
    
    if logger.log_file then
        logger.log_file:write(string.format('=== PacketLogger Session Started ===\n'))
        logger.log_file:write(string.format('Date: %s\n', os.date('%Y-%m-%d %H:%M:%S')))
        logger.log_file:write(string.format('Filter: %s\n\n', #logger.packet_filter == 0 and 'ALL' or table.concat(logger.packet_filter, ', ')))
        logger.log_file:flush()
        return true
    end
    
    return false
end

-- Close log file
local function close_log_file()
    if logger.log_file then
        logger.log_file:write(string.format('\n=== PacketLogger Session Ended ===\n'))
        logger.log_file:write(string.format('Date: %s\n', os.date('%Y-%m-%d %H:%M:%S')))
        logger.log_file:write(string.format('Total Packets Logged: %d\n', logger.packet_count))
        logger.log_file:close()
        logger.log_file = nil
    end
end

-- ============================================================================
-- Packet Logging
-- ============================================================================

-- Convert byte to hex string
local function byte_to_hex(byte)
    return string.format('%02X', byte)
end

-- Convert packet data to hex string
local function data_to_hex(data, max_bytes)
    max_bytes = max_bytes or data:len()
    local hex_parts = {}
    
    for i = 1, math.min(data:len(), max_bytes) do
        table.insert(hex_parts, byte_to_hex(data:byte(i)))
    end
    
    return table.concat(hex_parts, ' ')
end

-- Log a packet to file
local function log_packet(packet_id, data)
    if not logger.enabled or not logger.log_file then
        return
    end
    
    -- Check filter (if filter is set, only log matching packet IDs)
    if #logger.packet_filter > 0 then
        local match = false
        for _, id in ipairs(logger.packet_filter) do
            if id == packet_id then
                match = true
                break
            end
        end
        if not match then
            return
        end
    end
    
    logger.packet_count = logger.packet_count + 1
    
    -- Write packet header
    logger.log_file:write(string.format('[%s] Packet 0x%03X (Size: %d bytes)\n', 
        os.date('%H:%M:%S'), 
        packet_id, 
        data:len()))
    
    -- Write hex dump (16 bytes per line)
    local bytes_per_line = 16
    for offset = 0, data:len() - 1, bytes_per_line do
        local line_bytes = math.min(bytes_per_line, data:len() - offset)
        local hex_line = {}
        
        for i = 1, line_bytes do
            table.insert(hex_line, byte_to_hex(data:byte(offset + i)))
        end
        
        logger.log_file:write(string.format('  %04X: %s\n', offset, table.concat(hex_line, ' ')))
    end
    
    logger.log_file:write('\n')
    logger.log_file:flush()
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

ashita.events.register('load', 'logger_load', function()
    print(chat.header(addon.name) .. chat.message('PacketLogger loaded. Use /plog start to begin logging.'))
end)

ashita.events.register('unload', 'logger_unload', function()
    close_log_file()
end)

ashita.events.register('packet_in', 'logger_packet_in', function(e)
    if logger.enabled then
        local data = e.data_modified or e.data
        log_packet(e.id, data)
    end
end)

-- ============================================================================
-- Command Handler
-- ============================================================================

ashita.events.register('command', 'logger_command', function(e)
    local args = e.command:args()
    
    -- Check if command is for us
    if args[1] ~= '/plog' and args[1] ~= '/packetlogger' then
        return
    end
    
    -- Block the command from going to the game
    e.blocked = true
    
    -- No arguments - show help
    if #args == 1 then
        print(chat.header(addon.name) .. chat.message('PacketLogger v' .. addon.version .. ' - Commands:'))
        print(chat.message('/plog start - Start logging packets'))
        print(chat.message('/plog stop - Stop logging packets'))
        print(chat.message('/plog filter [id1] [id2] ... - Set packet filter (hex, e.g., 0x028)'))
        print(chat.message('/plog clearfilter - Remove packet filter (log all)'))
        print(chat.message('/plog status - Show logging status'))
        return
    end
    
    local cmd = args[2]:lower()
    
    -- Start logging
    if cmd == 'start' then
        if logger.enabled then
            print(chat.header(addon.name) .. chat.warning('Already logging to: ' .. logger.log_path))
            return
        end
        
        if init_log_file() then
            logger.enabled = true
            logger.packet_count = 0
            logger.start_time = os.time()
            print(chat.header(addon.name) .. chat.message('Logging started: ' .. logger.log_path))
        else
            print(chat.header(addon.name) .. chat.error('Failed to create log file'))
        end
        return
    end
    
    -- Stop logging
    if cmd == 'stop' then
        if not logger.enabled then
            print(chat.header(addon.name) .. chat.warning('Not currently logging'))
            return
        end
        
        logger.enabled = false
        local elapsed = os.time() - logger.start_time
        print(chat.header(addon.name) .. chat.message(string.format('Logging stopped. %d packets logged in %d seconds', 
            logger.packet_count, elapsed)))
        close_log_file()
        return
    end
    
    -- Set packet filter
    if cmd == 'filter' then
        if #args == 2 then
            print(chat.header(addon.name) .. chat.warning('Usage: /plog filter [id1] [id2] ... (e.g., /plog filter 0x028 0x029)'))
            return
        end
        
        logger.packet_filter = {}
        for i = 3, #args do
            local id = tonumber(args[i])
            if id then
                table.insert(logger.packet_filter, id)
            else
                print(chat.header(addon.name) .. chat.warning('Invalid packet ID: ' .. args[i]))
            end
        end
        
        print(chat.header(addon.name) .. chat.message('Filter set to: ' .. table.concat(logger.packet_filter, ', ')))
        return
    end
    
    -- Clear packet filter
    if cmd == 'clearfilter' then
        logger.packet_filter = {}
        print(chat.header(addon.name) .. chat.message('Filter cleared. Logging all packets.'))
        return
    end
    
    -- Status
    if cmd == 'status' then
        print(chat.header(addon.name) .. chat.message('=== PacketLogger Status ==='))
        print(chat.message('Logging: ' .. (logger.enabled and 'enabled' or 'disabled')))
        if logger.enabled then
            print(chat.message('Log file: ' .. logger.log_path))
            print(chat.message('Packets logged: ' .. logger.packet_count))
            print(chat.message('Elapsed time: ' .. (os.time() - logger.start_time) .. ' seconds'))
        end
        print(chat.message('Filter: ' .. (#logger.packet_filter == 0 and 'ALL' or table.concat(logger.packet_filter, ', '))))
        return
    end
    
    -- Unknown command
    print(chat.header(addon.name) .. chat.error('Unknown command: ' .. cmd))
end)

