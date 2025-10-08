#!/usr/bin/env lua
--[[
Standalone test script for Instapaper plugin
This script tests the core functionality without requiring KoReader

Usage:
    lua test_standalone.lua <username> <password>

Requirements:
    - lua-socket
    - lua-sec
]]

local https = require("ssl.https")
local ltn12 = require("ltn12")
local url = require("socket.url")

-- Get credentials from command line or use test credentials
local username = arg[1] or "account@eban.eu.org"
local password = arg[2] or "sGEDKu&W94GCXq7#v#D#LnwxwhMdXaj!AibJktUSSfj*MU6sbsMe9ET#MV8dS"

print("=" .. string.rep("=", 70))
print("Instapaper Plugin Standalone Test")
print("=" .. string.rep("=", 70))
print()

-- Test 1: Login
print("[TEST 1] Login Test")
print("--------")
print("Username: " .. username)
print("Password: " .. string.rep("*", 10))
print()

local base_url = "https://instapaper.com"
local login_url = base_url .. "/user/login"
local body = string.format("username=%s&password=%s&keep_logged_in=yes",
    url.escape(username), url.escape(password))

local response = {}
local headers = {
    ["Content-Type"] = "application/x-www-form-urlencoded",
    ["Content-Length"] = tostring(#body),
}

local request = {
    url = login_url,
    method = "POST",
    headers = headers,
    source = ltn12.source.string(body),
    sink = ltn12.sink.table(response),
    redirect = false,  -- Don't follow redirects automatically
}

print("Sending login request to " .. login_url .. "...")
local success, code, response_headers = pcall(function()
    return https.request(request)
end)

if not success then
    print("✗ FAILED: " .. tostring(code))
    print("\nPossible causes:")
    print("  - Network connectivity issues")
    print("  - DNS resolution failure")
    print("  - SSL/TLS certificate issues")
    print("  - Missing lua-sec or lua-socket libraries")
    os.exit(1)
end

print("HTTP Status Code: " .. tostring(code))

if not (code == 302 or code == 303 or code == 200) then
    print("✗ FAILED: Unexpected status code")
    print("\nExpected: 200, 302, or 303")
    print("Got: " .. tostring(code))
    print("\nPossible causes:")
    print("  - Invalid credentials")
    print("  - Instapaper API changed")
    print("  - Server error")
    os.exit(1)
end

print("✓ Login request successful")

-- Extract cookies from response headers
if not response_headers or not response_headers["set-cookie"] then
    print("✗ FAILED: No session cookie received")
    print("\nResponse headers:")
    if response_headers then
        for k, v in pairs(response_headers) do
            print("  " .. k .. ": " .. tostring(v))
        end
    else
        print("  (nil)")
    end
    print("\nPossible causes:")
    print("  - Invalid credentials")
    print("  - Login API changed")
    print("  - Cookies are set differently (e.g., via JavaScript)")
    os.exit(1)
end

local cookie = response_headers["set-cookie"]
print("✓ Session cookie received")
print()

-- Test 2: Fetch Article List
print("[TEST 2] Fetch Article List")
print("--------")

local list_url = base_url .. "/u"
local list_response = {}

local list_request = {
    url = list_url,
    method = "GET",
    headers = {
        ["Cookie"] = cookie,
    },
    sink = ltn12.sink.table(list_response),
}

print("Fetching articles from " .. list_url .. "...")
local list_success, list_code = pcall(function()
    return https.request(list_request)
end)

if not list_success then
    print("✗ FAILED: " .. tostring(list_code))
    os.exit(1)
end

print("HTTP Status Code: " .. tostring(list_code))

if list_code ~= 200 then
    print("✗ FAILED: Could not fetch article list")
    print("Expected: 200")
    print("Got: " .. tostring(list_code))
    os.exit(1)
end

local html = table.concat(list_response)
print("✓ Article list retrieved (" .. #html .. " bytes)")
print()

-- Test 3: Parse HTML
print("[TEST 3] HTML Parsing Test")
print("--------")

-- Check for article_list div
local article_list_start = html:find('<div[^>]*id="article_list"')
if not article_list_start then
    print("✗ FAILED: Could not find #article_list div")
    print("\nDebugging info:")
    
    -- Check if we're on the login page instead
    if html:find("login") or html:find("password") then
        print("  Page appears to be a login page - session may not be valid")
    end
    
    -- Check if page structure changed
    if html:find("<article") then
        print("  Found <article> tags, but not in #article_list")
        print("  → HTML structure may have changed")
    else
        print("  No <article> tags found at all")
    end
    
    print("\nSaving response to /tmp/instapaper_debug.html for inspection...")
    local f = io.open("/tmp/instapaper_debug.html", "w")
    if f then
        f:write(html)
        f:close()
        print("✓ Saved to /tmp/instapaper_debug.html")
    end
    
    os.exit(1)
end

print("✓ Found #article_list container")

-- Extract articles
local article_list_html = html:sub(article_list_start)
local articles = {}

for article_html in article_list_html:gmatch('<article[^>]*>(.-)</article>') do
    local article = {}
    
    -- Extract title and href
    local title, href = article_html:match('<a[^>]*class="[^"]*article_title[^"]*"[^>]*title="([^"]*)"[^>]*href="([^"]*)"')
    if not title then
        title, href = article_html:match('<a[^>]*class="[^"]*article_title[^"]*"[^>]*href="([^"]*)"[^>]*title="([^"]*)"')
    end
    if not title then
        href = article_html:match('<a[^>]*class="[^"]*article_title[^"]*"[^>]*href="([^"]*)"')
        title = article_html:match('<a[^>]*class="[^"]*article_title[^"]*"[^>]*title="([^"]*)"')
    end
    
    if title and href then
        article.title = title
        article.href = href
        
        -- Extract article ID
        local article_id = href:match('/read/(%d+)')
        article.id = article_id
        
        -- Extract date
        local date = article_html:match('<span[^>]*class="[^"]*date[^"]*"[^>]*>(.-)</span>')
        article.date = date or ""
        
        -- Extract image
        local img_url = article_html:match('<div[^>]*class="[^"]*article_image[^"]*"[^>]*>.-<img[^>]*src="([^"]*)"')
        if not img_url then
            img_url = article_html:match('<img[^>]*class="[^"]*article_image[^"]*"[^>]*src="([^"]*)"')
        end
        article.image_url = img_url
        
        table.insert(articles, article)
    end
end

print("✓ Parsed " .. #articles .. " articles")
print()

if #articles == 0 then
    print("⚠ WARNING: No articles found")
    print("  This could mean:")
    print("  - Account has no saved articles")
    print("  - HTML structure has changed")
    print("  - Parsing logic needs updating")
    print()
end

-- Test 4: Display Sample Articles
if #articles > 0 then
    print("[TEST 4] Sample Articles")
    print("--------")
    local max_display = math.min(5, #articles)
    for i = 1, max_display do
        local article = articles[i]
        print(string.format("Article #%d:", i))
        print("  Title: " .. (article.title:sub(1, 60) .. (article.title:len() > 60 and "..." or "")))
        print("  ID: " .. (article.id or "N/A"))
        print("  Date: " .. (article.date or "N/A"))
        print("  URL: " .. (article.href or "N/A"))
        if article.image_url then
            print("  Image: " .. article.image_url)
        end
        print()
    end
    
    if #articles > max_display then
        print("... and " .. (#articles - max_display) .. " more articles")
        print()
    end
end

-- Summary
print("=" .. string.rep("=", 70))
print("TEST SUMMARY")
print("=" .. string.rep("=", 70))
print()
print("✓ All tests passed successfully!")
print()
print("Results:")
print("  • Login: SUCCESS")
print("  • Session Cookie: SUCCESS")
print("  • Article List Fetch: SUCCESS")
print("  • HTML Parsing: SUCCESS")
print("  • Articles Found: " .. #articles)
print()
print("Plugin is ready to use in KoReader!")
print()
