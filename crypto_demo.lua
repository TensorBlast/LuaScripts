#!/usr/bin/env lua
-- crypto_demo.lua
-- Demonstration of optimized crypto.lua with luazen
-- This script shows the performance improvements and capabilities

local crypto = require('crypto')

print("=== Crypto.lua Optimization Demo ===\n")

-- Check if luazen is available
local info = crypto.get_info()
print("Crypto Implementation Info:")
for k, v in pairs(info) do
    print(string.format("  %s: %s", k, tostring(v)))
end
print()

-- Performance comparison
print("=== Performance Test ===")
local test_data = "This is a test message for encryption. " .. string.rep("Sample data for testing encryption performance! ", 50)
local password = "secure_test_password_123"

print(string.format("Test data size: %d bytes", #test_data))
print(string.format("Using algorithm: %s", info.algorithm))
print(string.format("Using KDF: %s", info.kdf))
print()

-- Encryption test
print("Testing encryption...")
local start_time = os.clock()
local encrypted = crypto.encrypt(test_data, password)
local encrypt_time = os.clock() - start_time

print(string.format("Encryption completed in %.6f seconds", encrypt_time))
print(string.format("Encrypted data version: %s", encrypted.version or "unknown"))
print(string.format("Ciphertext size: %d bytes", #encrypted.ciphertext))
print()

-- Decryption test
print("Testing decryption...")
start_time = os.clock()
local decrypted = crypto.decrypt(encrypted, password)
local decrypt_time = os.clock() - start_time

print(string.format("Decryption completed in %.6f seconds", decrypt_time))
print(string.format("Total round-trip time: %.6f seconds", encrypt_time + decrypt_time))
print(string.format("Data integrity verified: %s", tostring(decrypted == test_data)))
print()

-- Performance summary
if encrypt_time + decrypt_time > 0 then
    local throughput = (#test_data / 1024) / (encrypt_time + decrypt_time)
    print(string.format("Performance: %.2f KB/s", throughput))
end

-- Test wrong password
print("=== Security Test ===")
print("Testing with wrong password...")
local success, err = pcall(crypto.decrypt, encrypted, "wrong_password")
if not success then
    print("✅ Correctly rejected wrong password:", err)
else
    print("❌ Security failure: wrong password accepted")
end
print()

-- Run benchmark if luazen is available
if crypto.is_optimized() then
    print("=== Detailed Benchmark ===")
    crypto.benchmark()
else
    print("Luazen not available - install with: luarocks install luazen")
    print("Current implementation is pure Lua (much slower)")
end

print("\n=== Demo Complete ===") 