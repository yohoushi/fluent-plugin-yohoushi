class Fluent::YohoushiOutput < Fluent::Output
  Fluent::Plugin.register_output('yohoushi', self)

  MAPPING_MAX_NUM = 20
  KEY_MAX_NUM = 20

  def initialize
    super
    require 'socket'
    require 'multiforecast-client'
    require 'yohoushi-client'
  end

  config_param :base_uri, :string, :default => nil
  (1..MAPPING_MAX_NUM).each {|i| config_param "mapping#{i}".to_sym, :string, :default => nil }
  config_param :key_pattern, :string, :default => nil
  (1..KEY_MAX_NUM).each {|i| config_param "key#{i}".to_sym, :string, :default => nil }
  config_param :enable_float_number, :bool, :default => false
  config_param :mode, :default => :gauge do |val|
    case val.downcase
    when 'gauge'
      :gauge
    when 'count'
      :count
    when 'modified'
      :modified
    when 'derive'
      :derive
    else
      raise Fluent::ConfigError, "stdout output output_type should be `gauge`, `count`, `modified`, or `derive`"
    end
  end

  # for test
  attr_reader :client
  attr_reader :mapping
  attr_reader :keys
  attr_reader :key_pattern
  attr_reader :key_pattern_path

  def configure(conf)
    super

    if @base_uri
      @client = Yohoushi::Client.new(@base_uri)
    else
      @mapping = {}
      (1..MAPPING_MAX_NUM).each do |i|
        next unless conf["mapping#{i}"]
        from, to = conf["mapping#{i}"].split(/ +/, 2)
        raise Fluent::ConfigError, "mapping#{i} does not contain 2 parameters" unless to
        @mapping[from] = to
      end
      @client = MultiForecast::Client.new('mapping' => @mapping) unless @mapping.empty?
    end
    raise Fluent::ConfigError, "Either of `base_uri` or `mapping1` must be specified" unless @client

    if @key_pattern
      key_pattern, @key_pattern_path = @key_pattern.split(/ +/, 2)
      raise Fluent::ConfigError, "key_pattern does not contain 2 parameters" unless @key_pattern_path
      @key_pattern = Regexp.compile(key_pattern)
    else
      @keys = {}
      (1..KEY_MAX_NUM).each do |i|
        next unless conf["key#{i}"] 
        key, path = conf["key#{i}"].split(/ +/, 2)
        raise Fluent::ConfigError, "key#{i} does not contain 2 parameters" unless path
        @keys[key] = path
      end
    end
    raise Fluent::ConfigError, "Either of `key_pattern` or `key1` must be specified" if (@key_pattern.nil? and @keys.empty?)

    @hostname = Socket.gethostname
  rescue => e
    raise Fluent::ConfigError, "#{e.class} #{e.message} #{e.backtrace.first}"
  end

  def start
    super
  end

  def shutdown
    super
  end

  def post(path, number)
    if @enable_float_number
      @client.post_graph(path, { 'number' => number.to_f, 'mode' => @mode.to_s })
    else
      @client.post_graph(path, { 'number' => number.to_i, 'mode' => @mode.to_s })
    end
  rescue => e
    $log.warn "out_yohoushi: #{e.class} #{e.message} #{e.backtrace.first}"
  end

  def emit(tag, es, chain)
    tags = tag.split('.')
    if @key_pattern
      es.each do |time, record|
        record.each do |key, value|
          next unless key =~ @key_pattern
          path = expand_placeholder(@key_pattern_path, record, tag, tags, time, key)
          post(path, value)
        end
      end
    else # keys
      es.each do |time, record|
        @keys.each do |key, path|
          next unless value = record[key]
          path = expand_placeholder(path, record, tag, tags, time, key)
          post(path, value)
        end
      end
    end

    chain.next
  rescue => e
    $log.warn "out_yohoushi: #{e.class} #{e.message} #{e.backtrace.first}"
  end

  private

  def expand_placeholder(str, record, tag, tags, time, key)
    struct = UndefOpenStruct.new(record)
    struct.tag  = tag
    struct.tags = tags
    struct.time = time
    struct.key  = key
    struct.hostname = @hostname
    str = str.gsub(/\$\{([^}]+)\}/, '#{\1}') # ${..} => #{..}
    eval "\"#{str}\"", struct.instance_eval { binding }
  end

  class UndefOpenStruct < OpenStruct
    (Object.instance_methods).each do |m|
      undef_method m unless m.to_s =~ /^__|respond_to_missing\?|object_id|public_methods|instance_eval|method_missing|define_singleton_method|respond_to\?|new_ostruct_member/
    end
  end
end
