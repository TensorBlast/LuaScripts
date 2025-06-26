#!/usr/bin/env lua
-- demo.lua
-- Demo script for the license manager

local manager = require("license_manager")

print("=== License Manager Demo ===")
print()

-- Initialize the manager
print("1. Initializing license manager...")
local success, error_msg = manager.init("demo_password_123")
if not success then
    print("Failed to initialize: " .. error_msg)
    return
end
print("✓ License manager initialized successfully")
print()

-- Add some sample licenses
print("2. Adding sample licenses...")

local licenses_to_add = {
    {
        name = "GitHub API Token",
        type = "api_key",
        value = "ghp_1234567890abcdef1234567890abcdef12345678",
        description = "Personal access token for GitHub API",
        tags = {"github", "api", "development"},
        expires_date = "2024-12-31",
        metadata = {
            vendor = "GitHub",
            scope = "repo,user",
            created_by = "demo"
        }
    },
    {
        name = "OpenAI API Key",
        type = "api_key",
        value = "sk-1234567890abcdef1234567890abcdef1234567890abcdef",
        description = "API key for OpenAI GPT services",
        tags = {"openai", "api", "ai"},
        metadata = {
            vendor = "OpenAI",
            model_access = "gpt-4",
            tier = "paid"
        }
    },
    {
        name = "Software License Key",
        type = "license_key",
        value = "ABCD-EFGH-IJKL-MNOP-QRST",
        description = "License key for premium software",
        tags = {"software", "premium"},
        expires_date = "2025-06-15",
        metadata = {
            vendor = "SoftwareCorp",
            version = "2.0",
            seats = "5"
        }
    },
    {
        name = "JWT Token",
        type = "token",
        value = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
        description = "JWT token for authentication",
        tags = {"jwt", "auth", "temporary"},
        metadata = {
            issuer = "auth-service",
            audience = "api-service"
        }
    }
}

local added_ids = {}
for _, license_data in ipairs(licenses_to_add) do
    local id = manager.add_license(license_data)
    if id then
        table.insert(added_ids, id)
        print("✓ Added license: " .. license_data.name .. " (ID: " .. id .. ")")
    else
        print("✗ Failed to add license: " .. license_data.name)
    end
end
print()

-- Display all licenses
print("3. Listing all licenses:")
local all_licenses = manager.list_licenses()
manager.print_licenses_table(all_licenses)
print()

-- Show detailed view of one license
print("4. Detailed view of first license:")
if #added_ids > 0 then
    local license = manager.get_license(added_ids[1])
    manager.print_license(license, {show_value = true})
else
    print("No licenses to display")
end
print()

-- Search functionality
print("5. Searching for 'api' licenses:")
local api_licenses = manager.search_licenses("api")
local api_list = {}
for _, license in pairs(api_licenses) do
    table.insert(api_list, license)
end
manager.print_licenses_table(api_list)
print()

-- Filter by type
print("6. Filtering by type 'api_key':")
local api_key_licenses = manager.get_licenses_by_type("api_key")
local api_key_list = {}
for _, license in pairs(api_key_licenses) do
    table.insert(api_key_list, license)
end
manager.print_licenses_table(api_key_list)
print()

-- Filter by tag
print("7. Filtering by tag 'api':")
local tagged_licenses = manager.get_licenses_by_tag("api")
local tagged_list = {}
for _, license in pairs(tagged_licenses) do
    table.insert(tagged_list, license)
end
manager.print_licenses_table(tagged_list)
print()

-- Show statistics
print("8. License statistics:")
manager.print_stats()
print()

-- Update a license
print("9. Updating a license (adding expiration to JWT token):")
if #added_ids >= 4 then
    local jwt_id = added_ids[4]  -- JWT token
    local success, error_msg = manager.update_license(jwt_id, {
        expires_date = "2024-02-01",
        description = "JWT token for authentication (updated with expiration)"
    })
    
    if success then
        print("✓ License updated successfully")
        local updated_license = manager.get_license(jwt_id)
        manager.print_license(updated_license)
    else
        print("✗ Failed to update license: " .. error_msg)
    end
else
    print("No license to update")
end
print()

-- Export licenses
print("10. Exporting licenses to file:")
local export_success = manager.export_to_file("demo_export.json", {include_values = false})
if export_success then
    print("✓ Licenses exported to demo_export.json (values hidden)")
else
    print("✗ Failed to export licenses")
end
print()

-- Test search by name
print("11. Finding license by name:")
local github_license = manager.get_license_by_name("GitHub API Token")
if github_license then
    print("✓ Found license by name:")
    manager.print_license(github_license)
else
    print("✗ License not found")
end
print()

-- Close the manager
print("12. Closing license manager...")
local close_success, close_error = manager.close()
if close_success then
    print("✓ License manager closed successfully")
else
    print("✗ Error closing manager: " .. close_error)
end

print()
print("=== Demo completed ===")
print("The encrypted database file 'licenses.dat' has been created.")
print("You can run this demo again to see the licenses persist between runs.")
print()
print("Try running: lua -e \"local m = require('license_manager'); m.init('demo_password_123'); m.print_stats()\"") 