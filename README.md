# fluent-plugin-yohoushi [![Build Status](https://secure.travis-ci.org/yohoushi/fluent-plugin-yohoushi.png?branch=master)](http://travis-ci.org/sonots/fluent-plugin-yohoushi) [![Dependency Status](https://gemnasium.com/sonots/fluent-plugin-yohoushi.png)](https://gemnasium.com/yohoushi/fluent-plugin-yohoushi)

Fluentd plugin to post data to yohoushi where [yohoushi](http://yohoushi.github.io/yohoushi/) is a visualization graph tool.

## Configuration

    <match foo.bar.**>
      type yohoushi
      base_uri http://yohoushi.local:4804
      key1 foo_count /foobar/foo_count
      key2 bar_count /foobar/bar_count
    </source>

Assuming following inputs are coming:

    foo.bar: {"foo_count":1,"bar_count":2}

then fluent-plugin-yohoushi posts data to yohoshi similarly like

    $ curl -d number=1 http://yohoushi.local:4804/api/graphs/foobar/foo_count
    $ curl -d number=2 http://yohoushi.local:4804/api/graphs/foobar/bar_count

## Parameters

- base\_uri (semi-required)

    The base uri of yohoushi. `mapping1` or `base_uri` is required.

- mapping\[1-20\] (semi-required)

    This is an option for [multiforecast-client](https://github.com/yohoushi/multiforecast-client). `mapping1` or `base_uri` is required. 

    With this option, you can post graph data directly to multiple growthforecasts, not via yohoushi, which is more efficient.

    ex)

        mapping1 /foobar http://growthforecast1.local:5125
        mapping2 /       http://growthforecast2.local:5125

- key\[1-20\] (semi-required)

    A pair of a field name of the input record, and a graph path to be posted. `key1` or `key_pattern` is required.

    SECRET TRICK: You can use placeholders for the graph path. See Placeholders section.

- key\_pattern (semi-requierd)

    A pair of a regular expression to specify field names of the input record, and an expression to specify graph paths. `key1` or `key_pattern` is required. 

    For example, a configuration like

        key_pattern _count$ /foobar/${key}

    instead of key1, key2 in the above example gives the same effect. 

        $ curl -d number=1 http://yohoushi.local:4804/api/graphs/foobar/foo_count
        $ curl -d number=2 http://yohoushi.local:4804/api/graphs/foobar/bar_count

    See Placeholders section to know more about placeholders such as ${key}.

- enable\_float\_number

    Set to `true` if you are enabling `--enable_float_number` option of GrowthForecast. Default is `false`

- mode

    The graph mode (either of gauge, count, modified, or derive). Just same as mode of GrowthForecast POST parameter. Default is gauge.

### Placeholders

The keys of input json are available as placeholders. In the above example, 

* ${foo_count}
* ${bar_count}

shall be available. In addition, following placeholders are reserved: 

* ${hostname} hostname
* ${tag} input tag
* ${tags} input tag splitted by '.'
* ${time} time of the event
* ${key} the matched key value with `key_pattern` or `key1`, `key2`, ...

It is also possible to write a ruby code in placeholders, so you may write some codes as

* ${time.strftime('%Y-%m-%dT%H:%M:%S%z')}
* ${tags.last}  

## ChangeLog

See [CHANGELOG.md](CHANGELOG.md) for details.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new [Pull Request](../../pull/new/master)

## Copyright

Copyright (c) 2013 Naotoshi SEO. See [LICENSE](LICENSE) for details.

