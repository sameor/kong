use strict;
use warnings FATAL => 'all';
use Test::Nginx::Socket::Lua;

$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

plan tests => repeat_each() * (blocks() * 3);

run_tests();

__DATA__

=== TEST 1: response.get_header() returns first header when multiple is given with same name
--- config
    location = /t {
        content_by_lua_block {
            ngx.header.Accept = {
                "application/json",
                "text/html",
            }
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            ngx.ctx.data = "content type header value: " .. sdk.response.get_header("Accept")
        }

        body_filter_by_lua_block {
            ngx.arg[1] = ngx.ctx.data
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
content type header value: application/json
--- no_error_log
[error]



=== TEST 2: response.get_header() returns values from case-insensitive metatable
--- config
    location = /t {
        content_by_lua_block {
            ngx.header["X-Foo-Header"] = "Hello"
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            local data = {}

            data[1] = "X-Foo-Header: " .. sdk.response.get_header("X-Foo-Header")
            data[2] = "x-Foo-header: " .. sdk.response.get_header("x-Foo-header")
            data[3] = "x_foo_header: " .. sdk.response.get_header("x_foo_header")
            data[4] = "x_Foo_header: " .. sdk.response.get_header("x_Foo_header")

            ngx.ctx.data = table.concat(data, "\n")
        }

        body_filter_by_lua_block {
            ngx.arg[1] = ngx.ctx.data
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
X-Foo-Header: Hello
x-Foo-header: Hello
x_foo_header: Hello
x_Foo_header: Hello
--- no_error_log
[error]



=== TEST 3: response.get_header() returns nil when header is missing
--- config
    location = /t {
        content_by_lua_block {
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            ngx.ctx.data = "X-Missing: " .. type(sdk.response.get_header("X-Missing"))
        }

        body_filter_by_lua_block {
            ngx.arg[1] = ngx.ctx.data
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
X-Missing: nil
--- no_error_log
[error]



=== TEST 4: response.get_header() returns nil when response header does not fit in default max_headers
--- config
    location = /t {
        content_by_lua_block {
            for i = 1, 100 do
                ngx.header["X-Header-" .. i] = "test"
            end

            ngx.header["Accept"] = "text/html"
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            ngx.ctx.data = "accept header value: " .. type(sdk.response.get_header("Accept"))
        }

        body_filter_by_lua_block {
            ngx.arg[1] = ngx.ctx.data
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
accept header value: nil
--- no_error_log
[error]



=== TEST 5: response.get_header() raises error when trying to fetch with invalid argument
--- config
    location = /t {
        content_by_lua_block {
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            local ok, err = pcall(sdk.response.get_header)
            if not ok then
                ngx.ctx.err = err
            end
        }

        body_filter_by_lua_block {
            ngx.arg[1] = "error: " .. ngx.ctx.err
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
error: header must be a string
--- no_error_log
[error]



=== TEST 6: response.get_header() returns not-only service header
--- http_config
    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock;

        location / {
            content_by_lua_block {
                ngx.header["X-Service-Header"] = "test"
            }
        }
    }
--- config
    location = /t {
        access_by_lua_block {
            ngx.header["X-Non-Service-Header"] = "test"
        }

        proxy_pass http://unix:$TEST_NGINX_HTML_DIR/nginx.sock;

        header_filter_by_lua_block {
            ngx.header.content_length = nil
        }

        body_filter_by_lua_block {
            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            local get_header = sdk.response.get_header

            ngx.arg[1] = "X-Service-Header: "     .. get_header("X-Service-Header") .. "\n" ..
                         "X-Non-Service-Header: " .. get_header("X-Non-Service-Header")

            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
X-Service-Header: test
X-Non-Service-Header: test
--- no_error_log
[error]



=== TEST 7: response.get_header() errors on non-supported phases
--- http_config
--- config
    location = /t {
        content_by_lua_block {
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            local phases = {
                "set",
                "rewrite",
                "access",
                "content",
                "log",
                "header_filter",
                "body_filter",
                "timer",
                "init_worker",
                "balancer",
                "ssl_cert",
                "ssl_session_store",
                "ssl_session_fetch",
            }

            local data = {}
            local i = 0

            for _, phase in ipairs(phases) do
                ngx.get_phase = function()
                    return phase
                end

                local ok, err = pcall(sdk.response.get_header, "name")
                if not ok then
                    i = i + 1
                    data[i] = err
                end
            end

            ngx.ctx.data = table.concat(data, "\n")
        }

        body_filter_by_lua_block {
            ngx.arg[1] = ngx.ctx.data
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- error_code: 200
--- response_body chop
kong.response.get_header is disabled in the context of set
kong.response.get_header is disabled in the context of rewrite
kong.response.get_header is disabled in the context of access
kong.response.get_header is disabled in the context of content
kong.response.get_header is disabled in the context of timer
kong.response.get_header is disabled in the context of init_worker
kong.response.get_header is disabled in the context of balancer
kong.response.get_header is disabled in the context of ssl_cert
kong.response.get_header is disabled in the context of ssl_session_store
kong.response.get_header is disabled in the context of ssl_session_fetch
--- no_error_log
[error]