# Changelog

## 0.1.3
* Add configuration option: raise_on_error (default: true)
  * To have the plugin raise exceptions like it did in 0.1.1: keep using your configuration as-is
  * To suppress all exceptions: add `raise_on_error false` to your configuration

## 0.1.2
* #6 Catch all `StandardError`s during HTTP request to prevent td-agent from freezing

## 0.1.1
* #2 Use yajl instead of json as json serializer
* #1 Fix a bug where a nil HTTP response caused the plugin to stop working

## 0.1.0
* Initial release
