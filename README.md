# fluent-plugin-out-http, a plugin for [Fluentd](http://fluentd.org)

A generic [fluentd][1] output plugin for sending logs to an HTTP endpoint.

[![Build Status](https://travis-ci.org/ento/fluent-plugin-out-http.svg?branch=master)](https://travis-ci.org/ento/fluent-plugin-out-http)

## Configs

    <match *>
      type http
      endpoint_url    http://localhost.local/api/
      http_method     put
      serializer      json
      rate_limit_msec 100
      authentication  basic
      username        alice
      password        bobpop
    </match>

----

Heavily based on [fluent-plugin-growthforecast][2]

  [1]: http://fluentd.org/
  [2]: https://github.com/tagomoris/fluent-plugin-growthforecast
