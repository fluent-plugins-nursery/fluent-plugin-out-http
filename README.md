# fluent-plugin-out-http-ext, a plugin for [Fluentd](http://fluentd.org)

[![Build Status](https://travis-ci.org/kawasakitoshiya/fluent-plugin-out-http-ext.svg)](https://travis-ci.org/kawasakitoshiya/fluent-plugin-out-http-ext)
[![Coverage Status](https://coveralls.io/repos/kawasakitoshiya/fluent-plugin-out-http-ext/badge.svg?branch=master&service=github)](https://coveralls.io/github/kawasakitoshiya/fluent-plugin-out-http-ext?branch=master)

**This is a fork of [ento / fluent-plugin-out-http](https://github.com/ento/fluent-plugin-out-http)**

A generic [fluentd][1] output plugin for sending logs to an HTTP endpoint

## Configuration options

    <match *>
      type http_ext
      endpoint_url    http://localhost.local/api/<data.id> # <data.id> refres to data.id in the record like {"data"=> {"id"=> 1, "name"=> "foo"}}
      http_method     put    # default: post
      serializer      json   # default: form
      rate_limit_msec 100    # default: 0 = no rate limiting
      raise_on_error  false  # default: true
      authentication  basic  # default: none
      username        alice  # default: ''
      password        bobpop # default: '', secret: true
      use_ssl         true   # default: false
      <headers>
        HeaderExample1 header1
        HeaderExample2 header2
      </headers>
    </match>

## Usage notes

If you'd like to retry failed requests, consider using [fluent-plugin-bufferize][3].

----

Heavily based on [fluent-plugin-growthforecast][2]

  [1]: http://fluentd.org/
  [2]: https://github.com/tagomoris/fluent-plugin-growthforecast
  [3]: https://github.com/sabottenda/fluent-plugin-bufferize
