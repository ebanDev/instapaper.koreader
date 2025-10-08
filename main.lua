local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local socketutil = require("socketutil")
local url = require("socket.url")
local _ = require("gettext")
local T = require("ffi/util").template

local Instapaper = WidgetContainer:extend{
    name = "instapaper",
    base_url = "https://instapaper.com",
    cookie = nil,
    articles = {},
}

function Instapaper:init()
    self.ui.menu:registerToMainMenu(self)
end

function Instapaper:addToMainMenu(menu_items)
    menu_items.instapaper = {
        text = _("Instapaper"),
        sorting_hint = "more_tools",
        callback = function()
            if not NetworkMgr:isOnline() then
                NetworkMgr:promptWifiOn()
                return
            end
            self:showLoginDialog()
        end,
    }
end

function Instapaper:showLoginDialog()
    self.login_dialog = MultiInputDialog:new{
        title = _("Instapaper Login"),
        fields = {
            {
                text = "",
                hint = _("Username or Email"),
                type = "text",
            },
            {
                text = "",
                hint = _("Password"),
                type = "text",
                password = true,
            },
        },
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(self.login_dialog)
                    end,
                },
                {
                    text = _("Login"),
                    is_enter_default = true,
                    callback = function()
                        local username = self.login_dialog:getFields()[1]
                        local password = self.login_dialog:getFields()[2]
                        UIManager:close(self.login_dialog)
                        if username and username ~= "" and password and password ~= "" then
                            self:login(username, password)
                        else
                            UIManager:show(InfoMessage:new{
                                text = _("Username and password are required"),
                            })
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(self.login_dialog)
    self.login_dialog:onShowKeyboard()
end

function Instapaper:login(username, password)
    UIManager:show(InfoMessage:new{
        text = _("Logging in..."),
        timeout = 1,
    })

    local login_url = self.base_url .. "/user/login"
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
    }
    
    local code, response_headers = socketutil:set_timeout(
        socketutil.DEFAULT_RESPONSE_TIMEOUT,
        socketutil.DEFAULT_RESPONSE_TIMEOUT
    )
    
    local success, code, response_headers = pcall(function()
        return https.request(request)
    end)
    
    if success and (code == 302 or code == 303 or code == 200) then
        -- Extract cookies from response headers
        if response_headers and response_headers["set-cookie"] then
            self.cookie = response_headers["set-cookie"]
            UIManager:show(InfoMessage:new{
                text = _("Login successful!"),
                timeout = 1,
            })
            -- Now fetch article list
            self:fetchArticleList()
        else
            UIManager:show(InfoMessage:new{
                text = _("Login failed: No session cookie received"),
            })
        end
    else
        UIManager:show(InfoMessage:new{
            text = T(_("Login failed: %1"), tostring(code)),
        })
    end
end

function Instapaper:fetchArticleList()
    UIManager:show(InfoMessage:new{
        text = _("Fetching articles..."),
        timeout = 1,
    })

    local list_url = self.base_url .. "/u"
    local response = {}
    
    local headers = {
        ["Cookie"] = self.cookie or "",
    }
    
    local request = {
        url = list_url,
        method = "GET",
        headers = headers,
        sink = ltn12.sink.table(response),
    }
    
    local success, code = pcall(function()
        return https.request(request)
    end)
    
    if success and code == 200 then
        local html = table.concat(response)
        self:parseArticleList(html)
    else
        UIManager:show(InfoMessage:new{
            text = T(_("Failed to fetch articles: %1"), tostring(code)),
        })
    end
end

function Instapaper:parseArticleList(html)
    self.articles = {}
    
    -- Simple HTML parsing to extract articles
    -- Look for <article> tags within #article_list
    local article_list_start = html:find('<div[^>]*id="article_list"')
    if not article_list_start then
        UIManager:show(InfoMessage:new{
            text = _("No articles found or not logged in properly"),
        })
        return
    end
    
    local article_list_html = html:sub(article_list_start)
    
    -- Extract each article
    for article_html in article_list_html:gmatch('<article[^>]*>(.-)</article>') do
        local article = {}
        
        -- Extract title and href from <a class="article_title">
        -- Try different attribute orders
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
            
            -- Extract article ID from href (/read/ARTICLE_ID)
            local article_id = href:match('/read/(%d+)')
            article.id = article_id
            
            -- Extract date from span.date
            local date = article_html:match('<span[^>]*class="[^"]*date[^"]*"[^>]*>(.-)</span>')
            article.date = date or ""
            
            -- Extract image if present
            local img_url = article_html:match('<div[^>]*class="[^"]*article_image[^"]*"[^>]*>.-<img[^>]*src="([^"]*)"')
            if not img_url then
                img_url = article_html:match('<img[^>]*class="[^"]*article_image[^"]*"[^>]*src="([^"]*)"')
            end
            article.image_url = img_url
            
            table.insert(self.articles, article)
        end
    end
    
    if #self.articles > 0 then
        self:showArticleList()
    else
        UIManager:show(InfoMessage:new{
            text = _("No articles found"),
        })
    end
end

function Instapaper:fetchArticleContent(article_id)
    UIManager:show(InfoMessage:new{
        text = _("Fetching article content..."),
        timeout = 1,
    })
    
    local article_url = self.base_url .. "/read/" .. article_id
    local response = {}
    
    local headers = {
        ["Cookie"] = self.cookie or "",
    }
    
    local request = {
        url = article_url,
        method = "GET",
        headers = headers,
        sink = ltn12.sink.table(response),
    }
    
    local success, code = pcall(function()
        return https.request(request)
    end)
    
    if success and code == 200 then
        local html = table.concat(response)
        return self:parseArticleContent(html)
    else
        UIManager:show(InfoMessage:new{
            text = T(_("Failed to fetch article: %1"), tostring(code)),
        })
        return nil
    end
end

function Instapaper:parseArticleContent(html)
    local content = {}
    
    -- Extract title from #titlebar h1
    local titlebar_start = html:find('<[^>]*id="titlebar"')
    if titlebar_start then
        local titlebar_html = html:sub(titlebar_start)
        local h1_content = titlebar_html:match('<h1[^>]*>(.-)</h1>')
        if h1_content then
            -- Remove HTML tags from h1 content
            content.title = h1_content:gsub('<[^>]*>', '')
        end
    end
    
    -- Extract author from .author
    local author = html:match('<[^>]*class="[^"]*author[^"]*"[^>]*>(.-)</[^>]*>')
    if author then
        content.author = author:gsub('<[^>]*>', '')
    end
    
    -- Extract source from .original
    local source = html:match('<[^>]*class="[^"]*original[^"]*"[^>]*>(.-)</[^>]*>')
    if source then
        content.source = source:gsub('<[^>]*>', '')
    end
    
    -- Extract content from #story div
    local story_start = html:find('<div[^>]*id="story"')
    if story_start then
        local story_html = html:sub(story_start)
        -- Find matching closing div by counting nested divs
        local div_count = 0
        local pos = 1
        local story_end = nil
        
        while pos <= #story_html do
            local next_open = story_html:find('<div[^>]*>', pos)
            local next_close = story_html:find('</div>', pos)
            
            if not next_open and not next_close then
                break
            end
            
            if next_open and (not next_close or next_open < next_close) then
                div_count = div_count + 1
                pos = next_open + 1
            elseif next_close then
                div_count = div_count - 1
                if div_count == 0 then
                    story_end = next_close
                    break
                end
                pos = next_close + 1
            end
        end
        
        if story_end then
            local story_content = story_html:sub(1, story_end - 1)
            -- Remove the opening div tag
            story_content = story_content:gsub('^<div[^>]*>', '', 1)
            content.html = story_content
        end
    end
    
    return content
end

function Instapaper:showArticleList()
    local menu_items = {}
    
    for _, article in ipairs(self.articles) do
        table.insert(menu_items, {
            text = article.title,
            callback = function()
                if article.id then
                    local content = self:fetchArticleContent(article.id)
                    if content then
                        local info_text = ""
                        if content.title then
                            info_text = info_text .. _("Title: ") .. content.title .. "\n\n"
                        end
                        if content.author then
                            info_text = info_text .. _("Author: ") .. content.author .. "\n"
                        end
                        if content.source then
                            info_text = info_text .. _("Source: ") .. content.source .. "\n\n"
                        end
                        if content.html then
                            -- Show first 500 characters of HTML content
                            local preview = content.html:sub(1, 500)
                            if #content.html > 500 then
                                preview = preview .. "..."
                            end
                            info_text = info_text .. _("Content preview:\n") .. preview
                        end
                        
                        UIManager:show(InfoMessage:new{
                            text = info_text,
                        })
                    end
                else
                    UIManager:show(InfoMessage:new{
                        text = _("No article ID available"),
                    })
                end
            end,
        })
    end
    
    self.article_menu = Menu:new{
        title = _("Instapaper Articles"),
        item_table = menu_items,
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        onMenuHold = function(item)
            return true
        end,
    }
    
    UIManager:show(self.article_menu)
end

function Instapaper:onCloseWidget()
    -- Cleanup when widget is closed
end

return Instapaper
