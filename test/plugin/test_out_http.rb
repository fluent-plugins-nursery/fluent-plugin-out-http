# -*- coding: utf-8 -*-
require 'net/http'
require 'uri'
require 'yajl'
require 'fluent/test/http_output_test'
require 'fluent/plugin/out_http'
require 'fluent/test/driver/output'
require 'fluent/test/helpers'
require_relative "./script/plugin/formatter_test"

module OS
  # ref. http://stackoverflow.com/questions/170956/how-can-i-find-which-operating-system-my-ruby-program-is-running-on
  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def OS.mac?
    (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  def OS.unix?
    !OS.windows?
  end

  def OS.linux?
    OS.unix? and not OS.mac?
  end
end

class HTTPOutputTestBase < Test::Unit::TestCase
  include Fluent::Test::Helpers

  def self.port
    5126
  end

  def self.server_config
    config = {BindAddress: '127.0.0.1', Port: port}
    if ENV['VERBOSE']
      logger = WEBrick::Log.new(STDOUT, WEBrick::BasicLog::DEBUG)
      config[:Logger] = logger
      config[:AccessLog] = []
    end
    config
  end

  def self.test_http_client(**opts)
    opts = opts.merge(open_timeout: 1, read_timeout: 1)
    Net::HTTP.start('127.0.0.1', port, **opts)
  end

  # setup / teardown for servers
  def setup
    Fluent::Test.setup
    @posts = []
    @puts = []
    @prohibited = 0
    @requests = 0
    @auth = false
    @headers = {}
    @dummy_server_thread = Thread.new do
      srv = WEBrick::HTTPServer.new(self.class.server_config)
      begin
        allowed_methods = %w(POST PUT)
        srv.mount_proc('/api') { |req,res|
          @requests += 1
          unless allowed_methods.include? req.request_method
            res.status = 405
            res.body = 'request method mismatch'
            next
          end
          req.each do |key, value|
            @headers[key] = value
          end
          if @auth and req.header['authorization'][0] == 'Basic YWxpY2U6c2VjcmV0IQ==' # pattern of user='alice' passwd='secret!'
            # ok, authorized
          # pattern of bear #{Base64.encode64('secret token!')}
          elsif @auth and req.header['authorization'][0] == 'bearer c2VjcmV0IHRva2VuIQ=='
          # pattern of jwt
          # header: {
          #  "alg": "HS256",
          #  "typ": "JWT"
          # }
          # payload: {
          #   "iss": "Hoge Publisher",
          #   "sub": "Hoge User"
          # }
          # signature:
          #   HS256(base64UrlEncode(header)  + "." +
          #         base64UrlEncode(payload) + "." +
          #         secret)
          elsif @auth and req.header['authorization'][0] == 'jwt eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJIb2dlIFB1Ymxpc2hlciIsInN1YiI6IkhvZ2UgVXNlciJ9.V2NL7YgCWNt5d3vTXFrcRLpRImO2cU2JZ4mQglqw3rE'
          elsif @auth
            res.status = 403
            @prohibited += 1
            next
          else
            # ok, authorization not required
          end

          record = {:auth => nil}
          if req.content_type == 'application/json'
            record[:json] = Yajl.load(req.body)
          elsif req.content_type == 'text/plain'
            puts req
            record[:data] = req.body
          elsif req.content_type == 'application/octet-stream'
            record[:data] = req.body
          else
            record[:form] = Hash[*(req.body.split('&').map{|kv|kv.split('=')}.flatten)]
          end

          instance_variable_get("@#{req.request_method.downcase}s").push(record)

          res.status = 200
        }
        srv.mount_proc('/modified-api') { |req,res|
          res.status = 303
          res.body = 'See other'
        }
        srv.mount_proc('/') { |req,res|
          res.status = 200
          res.body = 'running'
        }
        srv.start
      ensure
        srv.shutdown
      end
    end

    # to wait completion of dummy server.start()
    require 'thread'
    cv = ConditionVariable.new
    watcher = Thread.new {
      connected = false
      while not connected
        begin
          client = self.class.test_http_client
          client.request_get('/')
          connected = true
        rescue Errno::ECONNREFUSED
          sleep 0.1
        rescue StandardError => e
          p e
          sleep 0.1
        end
      end
      cv.signal
    }
    mutex = Mutex.new
    mutex.synchronize {
      cv.wait(mutex)
    }
  end

  def test_dummy_server
    client = self.class.test_http_client
    post_header = { 'Content-Type' => 'application/x-www-form-urlencoded' }

    assert_equal '200', client.request_get('/').code
    assert_equal '200', client.request_post('/api/service/metrics/hoge', 'number=1&mode=gauge', post_header).code

    assert_equal 1, @posts.size

    assert_equal '1', @posts[0][:form]['number']
    assert_equal 'gauge', @posts[0][:form]['mode']
    assert_nil @posts[0][:auth]

    assert_equal '303', client.request_get('/modified-api').code

    @auth = true

    assert_equal '403', client.request_post('/api/service/metrics/pos', 'number=30&mode=gauge', post_header).code

    req_with_auth = lambda do |number, mode, user, pass|
      req = Net::HTTP::Post.new("/api/service/metrics/pos")
      req.content_type = 'application/x-www-form-urlencoded'
      req.basic_auth user, pass
      req.set_form_data({'number'=>number, 'mode'=>mode})
      req
    end

    assert_equal '403', client.request(req_with_auth.call(500, 'count', 'alice', 'wrong password!')).code

    assert_equal '403', client.request(req_with_auth.call(500, 'count', 'alice', 'wrong password!')).code

    assert_equal 1, @posts.size

    assert_equal '200', client.request(req_with_auth.call(500, 'count', 'alice', 'secret!')).code

    assert_equal 2, @posts.size

  end

  def teardown
    @dummy_server_thread.kill
    @dummy_server_thread.join
  end

  def create_driver(conf)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::HTTPOutput).configure(conf)
  end
end

class HTTPOutputTest < HTTPOutputTestBase
  CONFIG = %[
    endpoint_url http://127.0.0.1:#{port}/api/
  ]

  CONFIG_QUERY_PARAM = %[
    endpoint_url http://127.0.0.1:#{port}/api?foo=bar&baz=qux
  ]

  CONFIG_JSON = %[
    endpoint_url http://127.0.0.1:#{port}/api/
    serializer json
  ]

  CONFIG_TEXT = %[
    endpoint_url http://127.0.0.1:#{port}/api/
    serializer text
  ]

  CONFIG_RAW = %[
    endpoint_url http://127.0.0.1:#{port}/api/
    serializer raw
  ]

  CONFIG_PUT = %[
    endpoint_url http://127.0.0.1:#{port}/api/
    http_method put
  ]

  CONFIG_HTTP_ERROR = %[
    endpoint_url https://127.0.0.1:#{port - 1}/api/
  ]

  CONFIG_HTTP_ERROR_SUPPRESSED = %[
    endpoint_url https://127.0.0.1:#{port - 1}/api/
    raise_on_error false
  ]

  RATE_LIMIT_MSEC = 1200

  CONFIG_RATE_LIMIT = %[
    endpoint_url http://127.0.0.1:#{port}/api/
    rate_limit_msec #{RATE_LIMIT_MSEC}
  ]

  def test_configure
    d = create_driver CONFIG
    assert_equal "http://127.0.0.1:#{self.class.port}/api/", d.instance.endpoint_url
    assert_equal :form, d.instance.serializer

    d = create_driver CONFIG_JSON
    assert_equal "http://127.0.0.1:#{self.class.port}/api/", d.instance.endpoint_url
    assert_equal :json, d.instance.serializer
  end

  test 'lack of tag in chunk_keys' do
    assert_raise_message(/'tag' in chunk_keys is required./) do
      create_driver(Fluent::Config::Element.new(
                      'ROOT', '', {
                        '@type' => 'http',
                        'endpoint_url' => "http://127.0.0.1:#{self.class.port}/api/",
                        'buffered' => true,
                      }, [
                        Fluent::Config::Element.new('buffer', 'mykey', {
                                                      'chunk_keys' => 'mykey'
                                                    }, [])
                      ]
                    ))
    end
  end

  def test_emit_form
    d = create_driver CONFIG
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1, 'binary' => "\xe3\x81\x82".force_encoding("ascii-8bit") })
    end

    assert_equal 1, @posts.size
    record = @posts[0]

    assert_equal '50', record[:form]['field1']
    assert_equal '20', record[:form]['field2']
    assert_equal '10', record[:form]['field3']
    assert_equal '1', record[:form]['otherfield']
    assert_equal URI.encode_www_form_component("あ").upcase, record[:form]['binary'].upcase
    assert_nil record[:auth]

    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    end

    assert_equal 2, @posts.size
  end

  def test_emit_form_with_query_params
    d = create_driver CONFIG_QUERY_PARAM
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1, 'binary' => "\xe3\x81\x82".force_encoding("ascii-8bit") })
    end

    assert_equal 1, @posts.size
    record = @posts[0]

    assert_equal '50', record[:form]['field1']
    assert_equal '20', record[:form]['field2']
    assert_equal '10', record[:form]['field3']
    assert_equal '1', record[:form]['otherfield']
    assert_equal URI.encode_www_form_component("あ").upcase, record[:form]['binary'].upcase
    assert_nil record[:auth]

    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    end

    assert_equal 2, @posts.size
  end

  def test_emit_form_with_custom_headers
    d = create_driver CONFIG + %[custom_headers {"key":"custom","token":"arbitrary"}]
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1, 'binary' => "\xe3\x81\x82".force_encoding("ascii-8bit") })
    end

    assert_true @headers.has_key?("key")
    assert_equal "custom", @headers["key"]
    assert_true @headers.has_key?("token")
    assert_equal "arbitrary", @headers["token"]

    assert_equal 1, @posts.size
    record = @posts[0]

    assert_equal '50', record[:form]['field1']
    assert_equal '20', record[:form]['field2']
    assert_equal '10', record[:form]['field3']
    assert_equal '1', record[:form]['otherfield']
    assert_equal URI.encode_www_form_component("あ").upcase, record[:form]['binary'].upcase
    assert_nil record[:auth]

    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    end

    assert_equal 2, @posts.size
  end

  class BufferedEmitTest < self
    def test_emit_form
      d = create_driver CONFIG + %[buffered true]
      d.run(default_tag: 'test.metrics', shutdown: false) do
        d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1, 'binary' => "\xe3\x81\x82".force_encoding("ascii-8bit") })
      end

      assert_equal 1, @posts.size
      record = @posts[0]

      assert_equal '50', record[:form]['field1']
      assert_equal '20', record[:form]['field2']
      assert_equal '10', record[:form]['field3']
      assert_equal '1', record[:form]['otherfield']
      assert_equal URI.encode_www_form_component("あ").upcase, record[:form]['binary'].upcase
      assert_nil record[:auth]

      d.run(default_tag: 'test.metrics', shutdown: false) do
        d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
      end

      assert_equal 2, @posts.size
    end

    def test_emit_form_with_placeholders
      d = create_driver(Fluent::Config::Element.new(
                          'ROOT', '' ,
                          {"endpoint_url" => "${endpoint}",
                          "buffered" => true},
                          [Fluent::Config::Element.new('buffer', 'tag, endpoint', {"@type" => "memory"} ,[])]))

      d.run(default_tag: 'test.metrics', shutdown: false) do
        d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1, 'binary' => "\xe3\x81\x82".force_encoding("ascii-8bit"), 'endpoint' => "http://127.0.0.1:#{self.class.port}/modified-api/" })
      end

      assert_equal 0, @posts.size # post into other URI
      assert_equal "http://127.0.0.1:#{self.class.port}/modified-api/", d.instance.endpoint_url
    end

    def test_emit_form_put
      d = create_driver CONFIG_PUT + %[buffered true]
      d.run(default_tag: 'test.metrics', shutdown: false) do
        d.feed({ 'field1' => 50 })
      end

      assert_equal 0, @posts.size
      assert_equal 1, @puts.size
      record = @puts[0]

      assert_equal '50', record[:form]['field1']
      assert_nil record[:auth]

      d.run(default_tag: 'test.metrics', shutdown: false) do
        d.feed({ 'field1' => 50 })
      end

      assert_equal 0, @posts.size
      assert_equal 2, @puts.size
    end

    def test_emit_json
      binary_string = "\xe3\x81\x82"
      d = create_driver CONFIG_JSON + %[buffered true]
      d.run(default_tag: 'test.metrics') do
        d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1, 'binary' => binary_string })
      end

      assert_equal 1, @posts.size
      record = @posts[0]

      assert_equal 50, record[:json]['field1']
      assert_equal 20, record[:json]['field2']
      assert_equal 10, record[:json]['field3']
      assert_equal 1, record[:json]['otherfield']
      assert_equal binary_string, record[:json]['binary']
      assert_nil record[:auth]
    end
  end

  def test_emit_form_put
    d = create_driver CONFIG_PUT
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50 })
    end

    assert_equal 0, @posts.size
    assert_equal 1, @puts.size
    record = @puts[0]

    assert_equal '50', record[:form]['field1']
    assert_nil record[:auth]

    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50 })
    end

    assert_equal 0, @posts.size
    assert_equal 2, @puts.size
  end

  def test_emit_json
    binary_string = "\xe3\x81\x82"
    d = create_driver CONFIG_JSON
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1, 'binary' => binary_string })
    end

    assert_equal 1, @posts.size
    record = @posts[0]

    assert_equal 50, record[:json]['field1']
    assert_equal 20, record[:json]['field2']
    assert_equal 10, record[:json]['field3']
    assert_equal 1, record[:json]['otherfield']
    assert_equal binary_string, record[:json]['binary']
    assert_nil record[:auth]
  end

  def test_emit_text
    binary_string = "\xe3\x81\x82"
    d = create_driver CONFIG_TEXT
    d.run(default_tag: 'test.metrics') do
      d.feed({ "message" => "hello" })
    end
    assert_equal 1, @posts.size
    record = @posts[0]
    assert_equal 'hello', record[:data]
    assert_nil record[:auth]
  end

  def test_emit_raw
    binary_string = "\xe3\x81\x82"
    d = create_driver CONFIG_RAW + %[format msgpack]
    d.run(default_tag: 'test.metrics') do
      d.feed({ "message" => "hello" })
    end
    assert_equal 1, @posts.size
    record = @posts[0]
    assert_equal ({ "message" => "hello" }).to_msgpack, record[:data]
    assert_nil record[:auth]
  end

  def test_http_error_is_raised
    d = create_driver CONFIG_HTTP_ERROR
    assert_raise Errno::ECONNREFUSED do
      d.run(default_tag: 'test.metrics') do
        d.feed({ 'field1' => 50 })
      end
    end
  end

  def test_http_error_is_suppressed_with_raise_on_error_false
    d = create_driver CONFIG_HTTP_ERROR_SUPPRESSED
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50 })
    end
    # drive asserts the next output chain is called;
    # so no exception means our plugin handled the error

    assert_equal 0, @requests
  end

  def test_rate_limiting
    d = create_driver CONFIG_RATE_LIMIT
    record = { :k => 1 }

    last_emit = _current_msec
    d.run(default_tag: 'test.metrics') do
      d.feed(record)
    end

    assert_equal 1, @posts.size

    d.run(default_tag: 'test.metrics') do
      d.feed({})
    end
    assert last_emit + RATE_LIMIT_MSEC > _current_msec, "Still under rate limiting interval"
    assert_equal 1, @posts.size

    wait_msec = 500
    sleep (last_emit + RATE_LIMIT_MSEC - _current_msec + wait_msec) * 0.001

    assert last_emit + RATE_LIMIT_MSEC < _current_msec, "No longer under rate limiting interval"
    d.run(default_tag: 'test.metrics') do
      d.feed(record)
    end
    assert_equal 2, @posts.size
  end

  def _current_msec
    Time.now.to_f * 1000
  end

  def test_auth
    @auth = true # enable authentication of dummy server

    d = create_driver(CONFIG)
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    end # failed in background, and output warn log

    assert_equal 0, @posts.size
    assert_equal 1, @prohibited

    d = create_driver(CONFIG + %[
      authentication basic
      username alice
      password wrong_password
    ])
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    end # failed in background, and output warn log

    assert_equal 0, @posts.size
    assert_equal 2, @prohibited

    d = create_driver(CONFIG + %[
      authentication basic
      username alice
      password secret!
    ])
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    end # failed in background, and output warn log

    assert_equal 1, @posts.size
    assert_equal 2, @prohibited

    require 'base64'
    d = create_driver(CONFIG + %[
      authentication bearer
      token #{Base64.encode64('secret token!')}
    ])
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    end # failed in background, and output warn log

    assert_equal 2, @posts.size
    assert_equal 2, @prohibited

    d = create_driver(CONFIG + %[
      authentication jwt
      token eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJIb2dlIFB1Ymxpc2hlciIsInN1YiI6IkhvZ2UgVXNlciJ9.V2NL7YgCWNt5d3vTXFrcRLpRImO2cU2JZ4mQglqw3rE
    ])
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    end # failed in background, and output warn log

    assert_equal 3, @posts.size
    assert_equal 2, @prohibited
  end

  class CustomFormatterTest < self
    def test_new_config
      config = Fluent::Config::Element.new(
        'ROOT', '',
        {"@type" => "http",
         "endpoint_url" => "http://127.0.0.1:#{self.class.port}/api/",
         "serializer" => "json"}, [
          Fluent::Config::Element.new('format', '', {
                                        "@type" => "test"
                                      }, [])
        ])
      d = create_driver config
      payload = {"field" => 1}
      d.run(default_tag: 'test.metrics') do
        d.feed(payload)
      end

      record = @posts[0]
      expected = {"wrapped" => true, "record" => payload}
      assert_equal expected, record[:json]
    end

    def test_legacy_config
      config = %[
        endpoint_url http://127.0.0.1:#{self.class.port}/api/
        serializer json
        format test
      ]

      d = create_driver config
      payload = {"field" => 1}
      d.run(default_tag: 'test.metrics') do
        d.feed(payload)
      end

      record = @posts[0]
      expected = {"wrapped" => true, "record" => payload}
      assert_equal expected, record[:json]
    end
  end
end

class HTTPSOutputTest < HTTPOutputTestBase
  def self.port
    5127
  end

  def self.server_config
    config = super
    config[:SSLEnable] = true
    config[:SSLCertName] = [["CN", WEBrick::Utils::getservername]]
    config
  end

  def self.test_http_client
    super(
      use_ssl: true,
      verify_mode: OpenSSL::SSL::VERIFY_NONE,
    )
  end

  def test_configure
    test_uri = URI.parse("https://127.0.0.1/")

    ssl_config = %[
    endpoint_url https://127.0.0.1:#{self.class.port}/api/
    ]
    d = create_driver ssl_config
    expected_endpoint_url = "https://127.0.0.1:#{self.class.port}/api/"
    assert_equal expected_endpoint_url, d.instance.endpoint_url
    http_opts = d.instance.http_opts(test_uri)
    assert_equal true, http_opts[:use_ssl]
    assert_equal OpenSSL::SSL::VERIFY_PEER, http_opts[:verify_mode]

    no_verify_config = %[
    endpoint_url https://127.0.0.1:#{self.class.port}/api/
    ssl_no_verify true
    ]
    d = create_driver no_verify_config
    http_opts = d.instance.http_opts(test_uri)
    assert_equal true, http_opts[:use_ssl]
    assert_equal OpenSSL::SSL::VERIFY_NONE, http_opts[:verify_mode]

    cacert_file_config = %[
    endpoint_url https://127.0.0.1:#{self.class.port}/api/
    ssl_no_verify true
    cacert_file /tmp/ssl.cert
    ]
    d = create_driver cacert_file_config
    FileUtils::touch '/tmp/ssl.cert'
    http_opts = d.instance.http_opts(test_uri)
    assert_equal true, http_opts[:use_ssl]
    assert_equal OpenSSL::SSL::VERIFY_NONE, http_opts[:verify_mode]
    assert_equal true, File.file?('/tmp/ssl.cert')
    puts http_opts
    assert_equal File.join('/tmp/ssl.cert'), http_opts[:ca_file]
  end

  def test_emit_form_ssl
    config = %[
    endpoint_url https://127.0.0.1:#{self.class.port}/api/
    ssl_no_verify true
    ]
    d = create_driver config
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50 })
    end

    assert_equal 1, @posts.size
    record = @posts[0]

    assert_equal '50', record[:form]['field1']
  end

  def test_emit_form_ssl_ca
    config = %[
    endpoint_url https://127.0.0.1:#{self.class.port}/api/
    ssl_no_verify true
    cacert_file /tmp/ssl.cert
    ]
    d = create_driver config
    d.run(default_tag: 'test.metrics') do
      d.feed({ 'field1' => 50 })
    end

    assert_equal 1, @posts.size
    record = @posts[0]

    assert_equal '50', record[:form]['field1']
  end
end
