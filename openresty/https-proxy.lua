-- /usr/local/openresty/nginx/conf/lua/https-proxy.lua
local ngx = ngx
local socket = require "ngx.socket.tcp"

local M = {}

-- TCP连接池
local connection_pool = {}
local connection_pool_size = 100

-- 获取或创建后端连接
function M.get_backend_connection(host, port)
    local key = host .. ":" .. port
    local pool = connection_pool[key] or {}

    -- 从池中获取可用连接
    for i, conn in ipairs(pool) do
        if conn and conn.sock then
            table.remove(pool, i)
            return conn
        end
    end

    -- 创建新连接
    local conn = {}
    conn.sock, err = socket()
    if not conn.sock then
        return nil, "创建socket失败: " .. err
    end

    conn.sock:settimeouts(5000, 5000, 30000)  -- 连接,发送,读取超时

    local ok, err = conn.sock:connect(host, port)
    if not ok then
        return nil, "连接后端失败: " .. err
    end

    conn.host = host
    conn.port = port
    conn.create_time = ngx.now()

    return conn
end

-- 归还连接到池
function M.return_backend_connection(conn)
    if not conn or not conn.sock then
        return
    end

    local key = conn.host .. ":" .. conn.port
    local pool = connection_pool[key] or {}

    -- 如果池已满，关闭连接
    if #pool >= connection_pool_size then
        conn.sock:close()
        return
    end

    -- 放入连接池
    table.insert(pool, conn)
    connection_pool[key] = pool
end

-- 透明转发TCP数据
function M.transparent_proxy(client_sock, backend_host, backend_port)
    -- 获取后端连接
    local backend, err = M.get_backend_connection(backend_host, backend_port)
    if not backend then
        client_sock:close()
        return false, err
    end

    local backend_sock = backend.sock

    -- 双向数据转发
    local function forward(src, dst, name)
        local buffer_size = 8192
        while true do
            local data, err, partial = src:receive(buffer_size)

            if err then
                if err ~= "closed" and err ~= "timeout" then
                    ngx.log(ngx.ERR, name, " 接收错误: ", err)
                end
                break
            end

            local to_send = data or partial
            if to_send and #to_send > 0 then
                local bytes, err = dst:send(to_send)
                if not bytes then
                    ngx.log(ngx.ERR, name, " 发送错误: ", err)
                    break
                end
            end
        end
    end

    -- 使用协程并发处理双向数据流
    local co_client_to_backend = ngx.thread.spawn(forward, client_sock, backend_sock, "client->backend")
    local co_backend_to_client = ngx.thread.spawn(forward, backend_sock, client_sock, "backend->client")

    -- 等待转发完成
    ngx.thread.wait(co_client_to_backend)
    ngx.thread.wait(co_backend_to_client)

    -- 关闭客户端连接
    client_sock:close()

    -- 归还后端连接到池（如果连接仍然有效）
    if backend_sock and not backend_sock:closed() then
        M.return_backend_connection(backend)
    else
        backend_sock:close()
    end

    return true
end

-- 启动TCP代理服务器
function M.start_proxy_server(port, backend_host, backend_port)
    local sock, err = socket()
    if not sock then
        return nil, "创建监听socket失败: " .. err
    end

    -- 绑定和监听
    sock:settimeout(0)  -- 非阻塞模式
    local ok, err = sock:bind("0.0.0.0", port)
    if not ok then
        return nil, "绑定端口失败: " .. err
    end

    local ok, err = sock:listen(1024)
    if not ok then
        return nil, "监听失败: " .. err
    end

    ngx.log(ngx.INFO, "HTTPS透明代理启动，监听端口: ", port)

    -- 接受连接循环
    while true do
        local client, err = sock:accept()
        if client then
            -- 为每个连接创建协程处理
            ngx.thread.spawn(function()
                M.transparent_proxy(client, backend_host, backend_port)
            end)
        else
            if err ~= "timeout" then
                ngx.log(ngx.ERR, "接受连接失败: ", err)
            end
            ngx.sleep(0.001)  -- 短暂休眠，避免CPU占用过高
        end
    end
end

return M