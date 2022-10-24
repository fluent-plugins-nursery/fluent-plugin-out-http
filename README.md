# fluent-plugin-out-http, a plugin for [Fluentd](http://fluentd.org)

A generic [fluentd][1] output plugin for sending logs to an HTTP endpoint.

**NOTE:** This plugin name is overlapped from Fluentd core plugin which name is `out_http`. But core plugin does not provide buffered/non-buffered switch and batch/non-batch request switch. If you want to use these switch features. Please consider to use this plugin.

[![Build Status](https://travis-ci.org/fluent-plugins-nursery/fluent-plugin-out-http.svg?branch=master)](https://travis-ci.org/fluent-plugins-nursery/fluent-plugin-out-http)

## Installation

### For bundler

Write the following line in Gemfile:

```gemfile
gem "fluent-plugin-out-http"
```

and then,

```console
$ bundle install
```

### for fluentd

```console
$ fluent-gem install fluent-plugin-out-http
```

### For td-agent

```console
$ td-agent-gem install fluent-plugin-out-http
```

## Configuration options

    <match *>
      @type http
      endpoint_url    http://localhost.local/api/
      ssl_no_verify   false  # default: false
      http_method     put    # default: post
      serializer      json   # default: form
      rate_limit_msec 100    # default: 0 = no rate limiting
      raise_on_error  false  # default: true
      recoverable_status_codes 503, 400 # default: 503
      cacert_file     /etc/ssl/endpoint1.cert # default: ''
      client_cert_path /path/to/client_cert.crt # default: ''
      private_key_path /path/to/private_key.key # default: ''
      private_key_passphrase yourpassphrase # default: ''
      custom_headers  {"token":"arbitrary"} # default: nil
      authentication  basic  # default: none
      username        alice  # default: ''
      password        bobpop # default: '', secret: true
      token           tokent # default: ''
      buffered        true   # default: false. Switch non-buffered/buffered mode
      bulk_request    false  # default: false. Send events as application/x-ndjson
      compress_request true  # default: false. Send compressed events
    </match>

## Usage notes

If you'd like to retry failed requests, consider using [fluent-plugin-bufferize][3].
Or, specify appropriate `recoverable_status_codes` parameter.

To send events with bulk_request, you should specify `bulk_request` as `true`
Note that when this parameter as `true`, Fluentd always send events as `application/x-ndjson`.
Currently, `application/x-ndjson` is only supported MIME type for bulk_request.

----

Heavily based on [fluent-plugin-growthforecast][2]

  [1]: http://fluentd.org/
  [2]: https://github.com/tagomoris/fluent-plugin-growthforecast
  [3]: https://github.com/sabottenda/fluent-plugin-bufferize

## How to release

1. Update `gem.version` of the `gemspec` file.
1. Update `CHANGELOG.md`.
1. Commit them.
1. `$ bundle exec rake release`
    * It will add and push the tag, and publish the gem.
