# Changelog

### 1.1.5
* Add :raw serializer

### 1.1.4
* Add custom formatter feature
* Tweak Travis CI tasks

### 1.1.3
* Send query_string to endpoint_url

### 1.1.2
* Added custom headers feature

## 1.1.1
* Added plain text transport capability
* Added specify cacert file for ssl verify

## 1.1.0
* Support for jwt token authentication

## 1.0.1
* Added endpoint_url placeholder support

## 1.0.0
* Use Fluentd v1 API

## 0.2.0
### Added
* SSL is now supported if `endpoint_url` uses the `https` scheme (uses ruby-2.1 syntax internally)
* New config: set `ssl_no_verify` to `true` to bypass SSL certificate verification.
  Use at your own risk.
### Changed
* Fixed tests:
  * Removed some warnings
  * Fixed failing binary test to use UTF-8
### Removed
* Dropped support of Ruby 1.9-2.0

## 0.1.4
* #11 Updated Fluentd dependency to:  [">= 0.10.0", "< 2"]
* #10 `password` is now marked as a [secret option](https://github.com/fluent/fluentd/pull/604)

## 0.1.3
* Added a new configuration option: `raise_on_error` (default: true)
  * In order to let the plugin raise exceptions like it did in 0.1.1: keep using your configuration as-is
  * In order to suppress all exceptions: add `raise_on_error false` to your configuration

## 0.1.2
* #6 Catch all `StandardError`s during HTTP request to prevent td-agent from freezing

## 0.1.1
* #2 Use yajl instead of json as json serializer
* #1 Fix a bug where a nil HTTP response caused the plugin to stop working

## 0.1.0
* Initial release
