use lib 'lib';
use Test::Nginx::Socket;
use Cwd qw(cwd);
use Test::Nginx::Socket 'no_plan';

repeat_each(2);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';

no_long_string();

run_tests();

__DATA__

=== TEST 1: Content Length greater than maximum size
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER;
    location /foo {
        content_by_lua '
            local len = 1024 * 1024
            ngx.header.content_length = len
            local t = {}
            for i=1,len do
                t[i] = 0
            end
            ngx.print(table.concat(t))
        ';
    }

    location /t {
        content_by_lua '
            local httpipe = require "resty.httpipe"
            local hp = httpipe:new()

            hp:set_timeout(5000)

            local res, err = hp:request("127.0.0.1", ngx.var.server_port, {
                path = "/foo",
                maxsize = 1024
            })

            ngx.say(err)
        ';
    }
--- request
GET /t
--- response_body
exceeds maxsize
--- no_error_log
[error]



=== TEST 2: Chunked with length greater than maximum size
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER;
    location /foo {
        content_by_lua '
            local len = 1024 * 1024
            local t = {}
            for i=1,len do
                t[i] = 0
            end
            ngx.print(table.concat(t))
        ';
    }

    location /t {
        content_by_lua '
            local httpipe = require "resty.httpipe"
            local hp = httpipe:new()

            hp:set_timeout(5000)

            local res, err = hp:request("127.0.0.1", ngx.var.server_port, {
                path = "/foo",
                maxsize = 1024
            })

            ngx.say(err)
        ';
    }
--- request
GET /t
--- response_body
exceeds maxsize
--- no_error_log
[error]



=== TEST 3: HTTP/1.0 with length greater than maximum size
--- http_config eval: $::HttpConfig
--- config
    lua_http10_buffering on;
    resolver $TEST_NGINX_RESOLVER;
    location /foo {
        content_by_lua '
            local len = 1024 * 1024
            local t = {}
            for i=1,len do
                t[i] = 0
            end
            ngx.print(table.concat(t))
        ';
    }

    location /t {
        content_by_lua '
            local httpipe = require "resty.httpipe"
            local hp = httpipe:new()

            hp:set_timeout(5000)

            local res, err = hp:request("127.0.0.1", ngx.var.server_port, {
                path = "/foo",
                maxsize = 1024,
                version = 10
            })

            ngx.say(err)
        ';
    }
--- request
GET /t
--- response_body
exceeds maxsize
--- no_error_log
[error]


=== TEST 4: HTTP/1.0 with length less than maximum size
--- http_config eval: $::HttpConfig
--- config
    lua_http10_buffering on;
    resolver $TEST_NGINX_RESOLVER;
    location /foo {
        content_by_lua '
            local len = 1023
            local t = {}
            for i=1,len do
                t[i] = "a"
            end
            ngx.print(table.concat(t))
        ';
    }

    location /t {
        content_by_lua '
            local httpipe = require "resty.httpipe"
            local hp = httpipe:new()

            hp:set_timeout(5000)

            local res, err = hp:request("127.0.0.1", ngx.var.server_port, {
                path = "/foo",
                maxsize = 1024,
                version = 10
            })

            ngx.say(err)
            ngx.say(#res.body)
        ';
    }
--- request
GET /t
--- response_body
nil
1023
--- no_error_log
[error]
