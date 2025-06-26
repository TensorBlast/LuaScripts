-- license_manager.lua
-- Main license manager interface
-- High-level API for license operations with validation and error handling

local db = require("db")
local manager = {}

-- State
local is_initialized = false

-- Utility functions
local function format_date(timestamp)
    if not timestamp then
        return "Never"
    end
    return os.date("%Y-%m-%d %H:%M:%S", timestamp)
end

local function parse_date(date_str)
    if not date_str or date_str == "" then
        return nil
    end
    
    -- Try to parse YYYY-MM-DD format
    local year, month, day = date_str:match("(%d%d%d%d)-(%d%d)-(%d%d)")
    if year and month and day then
        return os.time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = 0,
            min = 0,
            sec = 0
        })
    end
    
    return nil
end

local function validate_password(password)
    if not password or password == "" then
        return false, "Password is required"
    end
    
    if #password < 8 then
        return false, "Password must be at least 8 characters long"
    end
    
    return true
end

-- Public API
function manager.init(password, db_file)
    local valid, error_msg = validate_password(password)
    if not valid then
        return false, error_msg
    end
    
    local success, error_msg = db.init(password, db_file)
    if not success then
        return false, error_msg
    end
    
    is_initialized = true
    return true
end

function manager.add_license(license_data)
    if not is_initialized then
        return false, "Manager not initialized"
    end
    
    -- Validate and process input
    if not license_data then
        return false, "License data is required"
    end
    
    -- Process expiration date
    if license_data.expires_date and type(license_data.expires_date) == "string" then
        local expires_timestamp = parse_date(license_data.expires_date)
        if not expires_timestamp then
            return false, "Invalid expiration date format. Use YYYY-MM-DD"
        end
        license_data.expires_date = expires_timestamp
    end
    
    -- Process tags (ensure it's a table)
    if license_data.tags and type(license_data.tags) == "string" then
        -- Split comma-separated tags
        local tags = {}
        for tag in license_data.tags:gmatch("[^,]+") do
            table.insert(tags, tag:match("^%s*(.-)%s*$"))  -- trim whitespace
        end
        license_data.tags = tags
    end
    
    return db.add_license(license_data)
end

function manager.get_license(id)
    if not is_initialized then
        return nil, "Manager not initialized"
    end
    
    return db.get_license(id)
end

function manager.get_license_by_name(name)
    if not is_initialized then
        return nil, "Manager not initialized"
    end
    
    local all_licenses = db.get_all_licenses()
    if not all_licenses then
        return nil
    end
    
    for _, license in pairs(all_licenses) do
        if license.name == name then
            return license
        end
    end
    
    return nil
end

function manager.get_all_licenses()
    if not is_initialized then
        return nil, "Manager not initialized"
    end
    
    return db.get_all_licenses()
end

function manager.update_license(id, updates)
    if not is_initialized then
        return false, "Manager not initialized"
    end
    
    -- Process expiration date
    if updates.expires_date and type(updates.expires_date) == "string" then
        local expires_timestamp = parse_date(updates.expires_date)
        if not expires_timestamp then
            return false, "Invalid expiration date format. Use YYYY-MM-DD"
        end
        updates.expires_date = expires_timestamp
    end
    
    -- Process tags
    if updates.tags and type(updates.tags) == "string" then
        local tags = {}
        for tag in updates.tags:gmatch("[^,]+") do
            table.insert(tags, tag:match("^%s*(.-)%s*$"))
        end
        updates.tags = tags
    end
    
    return db.update_license(id, updates)
end

function manager.delete_license(id)
    if not is_initialized then
        return false, "Manager not initialized"
    end
    
    return db.delete_license(id)
end

function manager.search_licenses(query)
    if not is_initialized then
        return nil, "Manager not initialized"
    end
    
    local results_hash = db.search_licenses(query)
    if not results_hash then
        return {}
    end
    
    -- Convert hash table to array
    local results_array = {}
    for id, license in pairs(results_hash) do
        table.insert(results_array, license)
    end
    
    return results_array
end

function manager.get_licenses_by_tag(tag)
    if not is_initialized then
        return nil, "Manager not initialized"
    end
    
    local results_hash = db.get_licenses_by_tag(tag)
    if not results_hash then
        return {}
    end
    
    -- Convert hash table to array
    local results_array = {}
    for id, license in pairs(results_hash) do
        table.insert(results_array, license)
    end
    
    return results_array
end

function manager.get_licenses_by_type(license_type)
    if not is_initialized then
        return nil, "Manager not initialized"
    end
    
    local results_hash = db.get_licenses_by_type(license_type)
    if not results_hash then
        return {}
    end
    
    -- Convert hash table to array
    local results_array = {}
    for id, license in pairs(results_hash) do
        table.insert(results_array, license)
    end
    
    return results_array
end

function manager.get_stats()
    if not is_initialized then
        return nil, "Manager not initialized"
    end
    
    return db.get_stats()
end

function manager.list_licenses(options)
    if not is_initialized then
        return nil, "Manager not initialized"
    end
    
    options = options or {}
    local all_licenses = db.get_all_licenses()
    
    if not all_licenses then
        return {}
    end
    
    local licenses_list = {}
    for id, license in pairs(all_licenses) do
        table.insert(licenses_list, license)
    end
    
    -- Sort by creation date (newest first) by default
    table.sort(licenses_list, function(a, b)
        return (a.created_date or 0) > (b.created_date or 0)
    end)
    
    -- Apply filters
    if options.type then
        local filtered = {}
        for _, license in ipairs(licenses_list) do
            if license.type == options.type then
                table.insert(filtered, license)
            end
        end
        licenses_list = filtered
    end
    
    if options.tag then
        local filtered = {}
        for _, license in ipairs(licenses_list) do
            if license.tags then
                for _, tag in ipairs(license.tags) do
                    if tag == options.tag then
                        table.insert(filtered, license)
                        break
                    end
                end
            end
        end
        licenses_list = filtered
    end
    
    -- Apply limit
    if options.limit and options.limit > 0 then
        local limited = {}
        for i = 1, math.min(options.limit, #licenses_list) do
            limited[i] = licenses_list[i]
        end
        licenses_list = limited
    end
    
    return licenses_list
end

function manager.print_license(license, options)
    if not license then
        print("License not found")
        return
    end
    
    options = options or {}
    
    print("License Details:")
    print("  ID: " .. license.id)
    print("  Name: " .. license.name)
    print("  Type: " .. license.type)
    
    if options.show_value then
        print("  Value: " .. license.value)
    else
        print("  Value: [HIDDEN - use --show-value to display]")
    end
    
    print("  Description: " .. (license.description or ""))
    print("  Created: " .. format_date(license.created_date))
    
    if license.expires_date then
        print("  Expires: " .. format_date(license.expires_date))
        
        local now = os.time()
        if license.expires_date <= now then
            print("  Status: EXPIRED")
        elseif license.expires_date <= (now + 30 * 24 * 60 * 60) then
            print("  Status: EXPIRING SOON")
        else
            print("  Status: ACTIVE")
        end
    else
        print("  Expires: Never")
        print("  Status: ACTIVE")
    end
    
    if license.tags and #license.tags > 0 then
        print("  Tags: " .. table.concat(license.tags, ", "))
    end
    
    if license.metadata and next(license.metadata) then
        print("  Metadata:")
        for k, v in pairs(license.metadata) do
            print("    " .. k .. ": " .. tostring(v))
        end
    end
end

function manager.print_licenses_table(licenses_list, options)
    if not licenses_list or #licenses_list == 0 then
        print("No licenses found.")
        return
    end
    
    options = options or {}
    
    -- Calculate column widths
    local max_name_width = 4  -- "Name"
    local max_type_width = 4  -- "Type"
    local max_status_width = 6  -- "Status"
    
    for _, license in ipairs(licenses_list) do
        max_name_width = math.max(max_name_width, #license.name)
        max_type_width = math.max(max_type_width, #license.type)
        
        local status = "ACTIVE"
        if license.expires_date then
            local now = os.time()
            if license.expires_date <= now then
                status = "EXPIRED"
            elseif license.expires_date <= (now + 30 * 24 * 60 * 60) then
                status = "EXPIRING SOON"
            end
        end
        max_status_width = math.max(max_status_width, #status)
    end
    
    -- Print header
    local header = string.format("%-" .. max_name_width .. "s | %-" .. max_type_width .. "s | %-" .. max_status_width .. "s | %s",
        "Name", "Type", "Status", "Created")
    print(header)
    print(string.rep("-", #header))
    
    -- Print licenses
    for _, license in ipairs(licenses_list) do
        local status = "ACTIVE"
        if license.expires_date then
            local now = os.time()
            if license.expires_date <= now then
                status = "EXPIRED"
            elseif license.expires_date <= (now + 30 * 24 * 60 * 60) then
                status = "EXPIRING SOON"
            end
        end
        
        local created = format_date(license.created_date)
        local row = string.format("%-" .. max_name_width .. "s | %-" .. max_type_width .. "s | %-" .. max_status_width .. "s | %s",
            license.name, license.type, status, created)
        print(row)
    end
    
    print("\nTotal: " .. #licenses_list .. " license(s)")
end

function manager.print_stats()
    if not is_initialized then
        print("Manager not initialized")
        return
    end
    
    local stats = db.get_stats()
    if not stats then
        print("Failed to get statistics")
        return
    end
    
    print("License Statistics:")
    print("  Total Licenses: " .. stats.total_licenses)
    
    if stats.expired > 0 then
        print("  Expired: " .. stats.expired)
    end
    
    if stats.expiring_soon > 0 then
        print("  Expiring Soon (30 days): " .. stats.expiring_soon)
    end
    
    if next(stats.by_type) then
        print("\n  By Type:")
        for type_name, count in pairs(stats.by_type) do
            print("    " .. type_name .. ": " .. count)
        end
    end
    
    if next(stats.by_tag) then
        print("\n  By Tag:")
        for tag, count in pairs(stats.by_tag) do
            print("    " .. tag .. ": " .. count)
        end
    end
end

function manager.export_to_file(filename, options)
    if not is_initialized then
        return false, "Manager not initialized"
    end
    
    options = options or {}
    local all_licenses = db.get_all_licenses()
    
    if not all_licenses then
        return false, "Failed to get licenses"
    end
    
    local file = io.open(filename, "w")
    if not file then
        return false, "Failed to open file for writing"
    end
    
    -- Export as JSON-like format
    file:write("{\n")
    file:write('  "export_date": "' .. os.date("%Y-%m-%d %H:%M:%S") .. '",\n')
    file:write('  "licenses": [\n')
    
    local license_count = 0
    for _, _ in pairs(all_licenses) do
        license_count = license_count + 1
    end
    
    local current = 0
    for id, license in pairs(all_licenses) do
        current = current + 1
        file:write("    {\n")
        file:write('      "id": "' .. license.id .. '",\n')
        file:write('      "name": "' .. license.name .. '",\n')
        file:write('      "type": "' .. license.type .. '",\n')
        
        if options.include_values then
            file:write('      "value": "' .. license.value .. '",\n')
        end
        
        file:write('      "description": "' .. (license.description or "") .. '",\n')
        file:write('      "created_date": ' .. (license.created_date or 0) .. ',\n')
        
        if license.expires_date then
            file:write('      "expires_date": ' .. license.expires_date .. ',\n')
        end
        
        if license.tags and #license.tags > 0 then
            file:write('      "tags": ["' .. table.concat(license.tags, '", "') .. '"],\n')
        end
        
        if license.metadata and next(license.metadata) then
            file:write('      "metadata": {\n')
            local meta_count = 0
            for _, _ in pairs(license.metadata) do
                meta_count = meta_count + 1
            end
            local meta_current = 0
            for k, v in pairs(license.metadata) do
                meta_current = meta_current + 1
                file:write('        "' .. k .. '": "' .. tostring(v) .. '"')
                if meta_current < meta_count then
                    file:write(',')
                end
                file:write('\n')
            end
            file:write('      }\n')
        else
            file:write('      "metadata": {}\n')
        end
        
        file:write("    }")
        if current < license_count then
            file:write(',')
        end
        file:write('\n')
    end
    
    file:write("  ]\n")
    file:write("}\n")
    file:close()
    
    return true
end

function manager.close()
    if is_initialized then
        local success, error_msg = db.close()
        is_initialized = false
        return success, error_msg
    end
    return true
end

return manager 