# fluent-plugin-out-http, a plugin for [Fluentd](http://fluentd.org)

A generic [fluentd][1] output plugin for sending logs to an HTTP endpoint.

[![Build Status](https://travis-ci.org/fluent-plugins-nursery/fluent-plugin-out-http.svg?branch=master)](https://travis-ci.org/fluent-plugins-nursery/fluent-plugin-out-http)

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
