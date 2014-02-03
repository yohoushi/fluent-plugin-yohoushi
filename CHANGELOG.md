## 0.1.2 (2014/02/03)

Fixes:

* Revert background post. I met troubles that fluentd process does not die.

## 0.1.1 (2014/01/29)

Enhancement:

* Enrich log a bit

## 0.1.0 (2014/01/29)

Changes:

* fluent-plugin-yohoushi is now a buffered plugin, it will post in background

## 0.0.5 (2014/01/25)

Fixes:

* Fix ${time} placeholder

## 0.0.4 (2014/01/25)

Enhancement:

* Add `enable_ruby false` option
* Add `tag_prefix` and `tag_suffix` placeholders

## 0.0.3 (2013/12/12)

Changes:

* Rename ${tags} placeholders to ${tag\_parts} placeholder to support plugin standard (see fluent-plugin-record-reformer, fluent-plugin-rewrite-tag-filter)

## 0.0.2 (2013/12/12)

Enhancement:

* Support derive

Fixes:

* Fix NameError of ConfigError

## 0.0.1 (2013/08/29)

First version
