class Fluent::YohoushiOutput < Fluent::Output
  Fluent::Plugin.register_output('yohoushi', self)

  def initialize
    super
    require 'net/http'
    require 'uri'
    require 'multiforecast-client'
    require 'yohoushi-client'
  end

  config_param :base_uri, :string, :default => nil
  config_param :mapping_from, :string, :default => ''
  config_param :mapping_to, :string, :default => nil
  config_param :keys, :string
  config_param :paths, :string, :default => nil
  config_param :enable_float_number, :bool, :default => false
  config_param :mode, :default => :gauge do |val|
    case val.downcase
    when 'gauge'
      :gauge
    when 'count'
      :count
    when 'modified'
      :modified
    else
      raise ConfigError, "stdout output output_type should be `gauge`, `count`, or `modified`"
    end
  end

  attr_accessor :client

  def configure(conf)
    super

    if @base_uri
      @client = Yohoushi::Client.new(@base_uri)
    else
      @mapping_from = @mapping_from.empty? ? [''] : @mapping_from.split(',')
      @mapping_to = @mapping_to.split(',') if @mapping_to
      if @mapping_from and @mapping_to and @mapping_from.size != @mapping_to.size
        raise Fluent::ConfigError, "sizes of mapping_from and mapping_to do not match"
      end
      mapping = Hash[*([@mapping_from, @mapping_to].transpose.flatten)]
      @client = MultiForecast::Client.new('mapping' => mapping)
    end

    @keys = @keys.split(',') if @keys
    @paths = @paths.split(',') if @paths
    if @keys and @paths and @keys.size != @paths.size
      raise Fluent::ConfigError, "sizes of keys and paths do not match"
    end
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
    es.each do |time, record|
      @keys.each_with_index do |key, i|
        if value = record[key]
          path = @paths ? @paths[i] : key
          post(path, value)
        end
      end
    end

    chain.next
  end
end
