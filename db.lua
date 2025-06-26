-- db.lua
-- Database interface for encrypted license storage
-- Handles CRUD operations and file I/O with ChaCha20-Poly1305 encryption

local crypto = require("crypto")
local cjson = require("cjson")
local db = {}

-- Use fast JSON serialization instead of custom serialization
cjson.encode_sparse_array(true)  -- Handle sparse arrays properly

-- Configuration
local DB_FILE = "licenses.dat"
local DB_VERSION = "1.0"

-- Internal state
local licenses = {}
local is_initialized = false
local master_password = nil

-- Utility functions
local function generate_id()
    -- Generate a simple unique ID based on timestamp and random data
    local timestamp = os.time()
    local random_part = math.random(1000, 9999)
    return string.format("%d_%d", timestamp, random_part)
end

local function validate_license(license)
    if not license then
        return false, "License data is required"
    end
    
    if not license.name or license.name == "" then
        return false, "License name is required"
    end
    
    if not license.type or license.type == "" then
        return false, "License type is required"
    end
    
    if not license.value or license.value == "" then
        return false, "License value is required"
    end
    
    -- Validate type
    local valid_types = {api_key = true, license_key = true, token = true, certificate = true}
    if not valid_types[license.type] then
        return false, "Invalid license type. Must be: api_key, license_key, token, or certificate"
    end
    
    return true
end

local function serialize_data(data)
    -- Use lua-cjson for fast JSON serialization
    return cjson.encode(data)
end

local function deserialize_data(str)
    -- Use lua-cjson for fast JSON deserialization
    return cjson.decode(str)
end

-- Database operations
function db.init(password, db_file)
    if is_initialized then
        return true
    end
    
    master_password = password
    DB_FILE = db_file or DB_FILE
    
    -- Try to load existing database
    local file = io.open(DB_FILE, "rb")
    if file then
        local encrypted_data = file:read("*all")
        file:close()
        
        if #encrypted_data > 0 then
            -- Deserialize the encrypted data structure
            local data_parts = {}
            local pos = 1
            
            -- Check for format marker
            if encrypted_data:sub(1, 4) == "LZ2\x00" then
                -- New luazen format
                data_parts.version = "luazen_v2"
                pos = 5 -- Skip format marker
                
                -- Read salt (16 bytes)
                data_parts.salt = encrypted_data:sub(pos, pos + 15)
                pos = pos + 16
                
                -- Read nonce (24 bytes for XChaCha20)
                data_parts.nonce = encrypted_data:sub(pos, pos + 23)
                pos = pos + 24
                
                -- Read AAD length (4 bytes)
                local aad_len = string.unpack("<I4", encrypted_data:sub(pos, pos + 3))
                pos = pos + 4
                
                -- Read AAD
                data_parts.aad = encrypted_data:sub(pos, pos + aad_len - 1)
                pos = pos + aad_len
                
                -- Read ciphertext (rest) - includes authentication tag
                data_parts.ciphertext = encrypted_data:sub(pos)
                
            else
                -- Legacy format
                -- Read salt (16 bytes)
                data_parts.salt = encrypted_data:sub(pos, pos + 15)
                pos = pos + 16
                
                -- Read nonce (12 bytes for ChaCha20)
                data_parts.nonce = encrypted_data:sub(pos, pos + 11)
                pos = pos + 12
                
                -- Read AAD length (4 bytes)
                local aad_len = string.unpack("<I4", encrypted_data:sub(pos, pos + 3))
                pos = pos + 4
                
                -- Read AAD
                data_parts.aad = encrypted_data:sub(pos, pos + aad_len - 1)
                pos = pos + aad_len
                
                -- Read tag (32 bytes)
                data_parts.tag = encrypted_data:sub(pos, pos + 31)
                pos = pos + 32
                
                -- Read ciphertext (rest)
                data_parts.ciphertext = encrypted_data:sub(pos)
            end
            
            -- Decrypt and deserialize
            local success, decrypted_data = pcall(crypto.decrypt, data_parts, password)
            if success then
                local db_data = deserialize_data(decrypted_data)
                if db_data and db_data.licenses then
                    licenses = db_data.licenses
                end
            else
                return false, "Failed to decrypt database: " .. decrypted_data
            end
        end
    end
    
    is_initialized = true
    return true
end

function db.save()
    if not is_initialized then
        return false, "Database not initialized"
    end
    
    -- Prepare data for encryption
    local db_data = {
        version = DB_VERSION,
        timestamp = os.time(),
        licenses = licenses
    }
    
    local serialized_data = serialize_data(db_data)
    
    -- Encrypt the data
    local encrypted_data = crypto.encrypt(serialized_data, master_password)
    
    -- Serialize the encrypted data structure with format marker
    local file_data
    if encrypted_data.version == "luazen_v2" then
        -- New luazen format: version marker + salt + nonce + aad + ciphertext
        file_data = "LZ2\x00" .. -- 4-byte format marker for luazen v2
                   encrypted_data.salt .. 
                   encrypted_data.nonce .. 
                   string.pack("<I4", #encrypted_data.aad) ..
                   encrypted_data.aad ..
                   encrypted_data.ciphertext
    else
        -- Legacy format: no version marker, separate tag field
        file_data = encrypted_data.salt .. 
                   encrypted_data.nonce .. 
                   string.pack("<I4", #encrypted_data.aad) ..
                   encrypted_data.aad ..
                   (encrypted_data.tag or string.rep("\0", 32)) ..
                   encrypted_data.ciphertext
    end
    
    -- Write to file
    local file = io.open(DB_FILE, "wb")
    if not file then
        return false, "Failed to open database file for writing"
    end
    
    file:write(file_data)
    file:close()
    
    return true
end

function db.add_license(license_data)
    if not is_initialized then
        return false, "Database not initialized"
    end
    
    local valid, error_msg = validate_license(license_data)
    if not valid then
        return false, error_msg
    end
    
    -- Create license record
    local license = {
        id = generate_id(),
        name = license_data.name,
        type = license_data.type,
        value = license_data.value,
        description = license_data.description or "",
        created_date = os.time(),
        expires_date = license_data.expires_date,
        tags = license_data.tags or {},
        metadata = license_data.metadata or {}
    }
    
    licenses[license.id] = license
    
    -- Auto-save
    local success, error_msg = db.save()
    if not success then
        -- Rollback
        licenses[license.id] = nil
        return false, "Failed to save: " .. error_msg
    end
    
    return license.id
end

function db.get_license(id)
    if not is_initialized then
        return nil, "Database not initialized"
    end
    
    return licenses[id]
end

function db.get_all_licenses()
    if not is_initialized then
        return nil, "Database not initialized"
    end
    
    local result = {}
    for id, license in pairs(licenses) do
        result[id] = license
    end
    return result
end

function db.update_license(id, updates)
    if not is_initialized then
        return false, "Database not initialized"
    end
    
    local license = licenses[id]
    if not license then
        return false, "License not found"
    end
    
    -- Create updated license
    local updated_license = {}
    for k, v in pairs(license) do
        updated_license[k] = v
    end
    
    -- Apply updates
    for k, v in pairs(updates) do
        if k ~= "id" and k ~= "created_date" then  -- Protect immutable fields
            updated_license[k] = v
        end
    end
    
    -- Validate updated license
    local valid, error_msg = validate_license(updated_license)
    if not valid then
        return false, error_msg
    end
    
    -- Store backup for rollback
    local backup = license
    licenses[id] = updated_license
    
    -- Auto-save
    local success, error_msg = db.save()
    if not success then
        -- Rollback
        licenses[id] = backup
        return false, "Failed to save: " .. error_msg
    end
    
    return true
end

function db.delete_license(id)
    if not is_initialized then
        return false, "Database not initialized"
    end
    
    local license = licenses[id]
    if not license then
        return false, "License not found"
    end
    
    -- Store backup for rollback
    local backup = license
    licenses[id] = nil
    
    -- Auto-save
    local success, error_msg = db.save()
    if not success then
        -- Rollback
        licenses[id] = backup
        return false, "Failed to save: " .. error_msg
    end
    
    return true
end

function db.search_licenses(query)
    if not is_initialized then
        return nil, "Database not initialized"
    end
    
    local results = {}
    query = query:lower()
    
    for id, license in pairs(licenses) do
        local match = false
        
        -- Search in name, description, type
        if license.name:lower():find(query) or
           license.description:lower():find(query) or
           license.type:lower():find(query) then
            match = true
        end
        
        -- Search in tags
        if not match and license.tags then
            for _, tag in ipairs(license.tags) do
                if tag:lower():find(query) then
                    match = true
                    break
                end
            end
        end
        
        -- Search in metadata
        if not match and license.metadata then
            for k, v in pairs(license.metadata) do
                if tostring(k):lower():find(query) or tostring(v):lower():find(query) then
                    match = true
                    break
                end
            end
        end
        
        if match then
            results[id] = license
        end
    end
    
    return results
end

function db.get_licenses_by_tag(tag)
    if not is_initialized then
        return nil, "Database not initialized"
    end
    
    local results = {}
    tag = tag:lower()
    
    for id, license in pairs(licenses) do
        if license.tags then
            for _, license_tag in ipairs(license.tags) do
                if license_tag:lower() == tag then
                    results[id] = license
                    break
                end
            end
        end
    end
    
    return results
end

function db.get_licenses_by_type(license_type)
    if not is_initialized then
        return nil, "Database not initialized"
    end
    
    local results = {}
    license_type = license_type:lower()
    
    for id, license in pairs(licenses) do
        if license.type:lower() == license_type then
            results[id] = license
        end
    end
    
    return results
end

function db.get_stats()
    if not is_initialized then
        return nil, "Database not initialized"
    end
    
    local stats = {
        total_licenses = 0,
        by_type = {},
        by_tag = {},
        expired = 0,
        expiring_soon = 0  -- within 30 days
    }
    
    local now = os.time()
    local thirty_days = 30 * 24 * 60 * 60
    
    for _, license in pairs(licenses) do
        stats.total_licenses = stats.total_licenses + 1
        
        -- Count by type
        stats.by_type[license.type] = (stats.by_type[license.type] or 0) + 1
        
        -- Count by tags
        if license.tags then
            for _, tag in ipairs(license.tags) do
                stats.by_tag[tag] = (stats.by_tag[tag] or 0) + 1
            end
        end
        
        -- Check expiration
        if license.expires_date then
            if license.expires_date <= now then
                stats.expired = stats.expired + 1
            elseif license.expires_date <= (now + thirty_days) then
                stats.expiring_soon = stats.expiring_soon + 1
            end
        end
    end
    
    return stats
end

function db.close()
    if is_initialized then
        local success, error_msg = db.save()
        is_initialized = false
        master_password = nil
        licenses = {}
        return success, error_msg
    end
    return true
end

return db
