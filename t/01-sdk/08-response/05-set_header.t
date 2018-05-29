use strict;
use warnings FATAL => 'all';
use Test::Nginx::Socket::Lua;

$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

plan tests => repeat_each() * (blocks() * 3);

run_tests();

__DATA__

=== TEST 1: response.set_header() errors if arguments are not given
--- config
    location = /t {
        content_by_lua_block {
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            local ok, err = pcall(sdk.response.set_header)
            if not ok then
                ngx.ctx.err = err
            end
        }

        body_filter_by_lua_block {
            ngx.arg[1] = ngx.ctx.err
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
header must be a string
--- no_error_log
[error]



=== TEST 2: response.set_header() errors if name is not a string
--- config
    location = /t {
        content_by_lua_block {
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            local ok, err = pcall(sdk.response.set_header, 127001, "foo")
            if not ok then
                ngx.ctx.err = err
            end
        }

        body_filter_by_lua_block {
            ngx.arg[1] = ngx.ctx.err
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
header must be a string
--- no_error_log
[error]



=== TEST 3: response.set_header() errors if value is not a string
--- config
    location = /t {
        content_by_lua_block {
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            local ok, err = pcall(sdk.response.set_header, "foo", {})
            if not ok then
                ngx.ctx.err = err
            end
        }

        body_filter_by_lua_block {
            ngx.arg[1] = ngx.ctx.err
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
invalid value for "foo": got table, expected string, number or boolean
--- no_error_log
[error]



=== TEST 4: response.set_header() errors if value is not given
--- config
    location = /t {
        content_by_lua_block {
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            local _, err = pcall(sdk.response.set_header, "foo")
            if not ok then
                ngx.ctx.err = err
            end
        }

        body_filter_by_lua_block {
            ngx.arg[1] = ngx.ctx.err
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
invalid value for "foo": got nil, expected string, number or boolean
--- no_error_log
[error]



=== TEST 5: response.set_header() sets a header in the downstream response
--- config
    location = /t {
        content_by_lua_block {
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            sdk.response.set_header("X-Foo", "hello world")
        }

        body_filter_by_lua_block {
            ngx.arg[1] = "X-Foo: " .. ngx.header["X-Foo"]
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
X-Foo: hello world
--- no_error_log
[error]



=== TEST 6: response.set_header() replaces all headers with that name if any exist
--- config
    location = /t {
        content_by_lua_block {
            ngx.header["X-Foo"] = { "First", "Second" }
        }

        header_filter_by_lua_block {
            ngx.header.content_length = nil

            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            sdk.response.set_header("X-Foo", "hello world")
        }

        body_filter_by_lua_block {
            local new_headers = ngx.resp.get_headers()

            ngx.arg[1] = "type: " ..  type(new_headers["X-Foo"])
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
type: string
--- no_error_log
[error]



=== TEST 7: response.set_header() can set to an empty string
--- http_config
    server {
        listen unix:$TEST_NGINX_HTML_DIR/nginx.sock;

        location /t {
            content_by_lua_block {
            }

            header_filter_by_lua_block {
                local SDK = require "kong.sdk"
                local sdk = SDK.new()

                sdk.response.set_header("X-Foo", "")
            }
        }
    }
--- config
    location = /t {
        proxy_pass http://unix:$TEST_NGINX_HTML_DIR/nginx.sock;

        header_filter_by_lua_block {
            ngx.header.content_length = nil
        }

        body_filter_by_lua_block {
            ngx.arg[1] = "type: " .. type(ngx.resp.get_headers()["X-Foo"]) .. "\n" ..
                         "X-Foo: {" .. ngx.resp.get_headers()["X-Foo"] .. "}"
            ngx.arg[2] = true
        }
    }
--- request
GET /t
--- response_body chop
type: string
X-Foo: {}
--- no_error_log
[error]



=== TEST 8: response.set_header() errors on non-supported phases
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

                local ok, err = pcall(sdk.response.set_header, "name", "value")
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
kong.response.set_header is disabled in the context of set
kong.response.set_header is disabled in the context of rewrite
kong.response.set_header is disabled in the context of access
kong.response.set_header is disabled in the context of content
kong.response.set_header is disabled in the context of log
kong.response.set_header is disabled in the context of body_filter
kong.response.set_header is disabled in the context of timer
kong.response.set_header is disabled in the context of init_worker
kong.response.set_header is disabled in the context of balancer
kong.response.set_header is disabled in the context of ssl_cert
kong.response.set_header is disabled in the context of ssl_session_store
kong.response.set_header is disabled in the context of ssl_session_fetch
--- no_error_log
[error]