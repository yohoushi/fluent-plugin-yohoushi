module Fluent
  class YohoushiOutput < Output
    Plugin.register_output('yohoushi', self)

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
        raise ConfigError, "stdout output output_type should be `gauge`, `count`, `modified`, or `derive`"
      end
    end
    config_param :enable_ruby, :bool, :default => true # true for lower version compatibility
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
          raise ConfigError, "mapping#{i} does not contain 2 parameters" unless to
          @mapping[from] = to
        end
        @client = MultiForecast::Client.new('mapping' => @mapping) unless @mapping.empty?
        @client.clients.each { |c|
          c.connect_timeout = 5.0
          c.send_timeout = 5.0
          c.receive_timeout = 5.0
        }
      end
      raise ConfigError, "Either of `base_uri` or `mapping1` must be specified" unless @client

      if @key_pattern
        key_pattern, @key_pattern_path = @key_pattern.split(/ +/, 2)
        raise ConfigError, "key_pattern does not contain 2 parameters" unless @key_pattern_path
        @key_pattern = Regexp.compile(key_pattern)
      else
        @keys = {}
        (1..KEY_MAX_NUM).each do |i|
          next unless conf["key#{i}"] 
          key, path = conf["key#{i}"].split(/ +/, 2)
          raise ConfigError, "key#{i} does not contain 2 parameters" unless path
          @keys[key] = path
        end
      end
      raise ConfigError, "Either of `key_pattern` or `key1` must be specified" if (@key_pattern.nil? and @keys.empty?)

      @placeholder_expander =
        if @enable_ruby
          # require utilities which would be used in ruby placeholders
          require 'pathname'
          require 'uri'
          require 'cgi'
          RubyPlaceholderExpander.new
        else
          PlaceholderExpander.new
        end

      @hostname = Socket.gethostname
    rescue => e
      raise ConfigError, "#{e.class} #{e.message} #{e.backtrace.first}"
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
      $log.warn "out_yohoushi: #{e.class} #{e.message} #{path} #{e.backtrace.first}"
    end

    def emit(tag, es, chain)
      tag_parts = tag.split('.')
      tag_prefix = tag_prefix(tag_parts)
      tag_suffix = tag_suffix(tag_parts)
      placeholders = {
        'tag' => tag,
        'tags' => tag_parts, # for lower compatibility
        'tag_parts' => tag_parts,
        'tag_prefix' => tag_prefix,
        'tag_suffix' => tag_suffix,
        'hostname' => @hostname,
      }
      if @key_pattern
        es.each do |time, record|
          record.each do |key, value|
            next unless key =~ @key_pattern
            placeholders['key'] = key
            path = expand_placeholder(@key_pattern_path, time, record, placeholders)
            post(path, value)
          end
        end
      else # keys
        es.each do |time, record|
          @keys.each do |key, path|
            next unless value = record[key]
            placeholders['key'] = key
            path = expand_placeholder(path, time, record, placeholders)
            post(path, value)
          end
        end
      end

      chain.next
    rescue => e
      $log.warn "out_yohoushi: #{e.class} #{e.message} #{e.backtrace.first}"
    end

    def expand_placeholder(value, time, record, opts)
      @placeholder_expander.prepare_placeholders(time, record, opts)
      @placeholder_expander.expand(value)
    end

    def tag_prefix(tag_parts)
      return [] if tag_parts.empty?
      tag_prefix = [tag_parts.first]
      1.upto(tag_parts.size-1).each do |i|
        tag_prefix[i] = "#{tag_prefix[i-1]}.#{tag_parts[i]}"
      end
      tag_prefix
    end

    def tag_suffix(tag_parts)
      return [] if tag_parts.empty?
      rev_tag_parts = tag_parts.reverse
      rev_tag_suffix = [rev_tag_parts.first]
      1.upto(tag_parts.size-1).each do |i|
        rev_tag_suffix[i] = "#{rev_tag_parts[i]}.#{rev_tag_suffix[i-1]}"
      end
      rev_tag_suffix.reverse
    end

    class PlaceholderExpander
      attr_reader :placeholders

      def prepare_placeholders(time, record, opts)
        placeholders = { '${time}' => Time.at(time).to_s }
        record.each {|key, value| placeholders.store("${#{key}}", value) }

        opts.each do |key, value|
          if value.kind_of?(Array) # tag_parts, etc
            size = value.size
            value.each_with_index { |v, idx|
              placeholders.store("${#{key}[#{idx}]}", v)
              placeholders.store("${#{key}[#{idx-size}]}", v) # support [-1]
            }
          else # string, interger, float, and others?
            placeholders.store("${#{key}}", value)
          end
        end

        @placeholders = placeholders
      end

      def expand(str)
        str.gsub(/(\${[a-z_]+(\[-?[0-9]+\])?}|__[A-Z_]+__)/) {
          $log.warn "record_reformer: unknown placeholder `#{$1}` found" unless @placeholders.include?($1)
          @placeholders[$1]
        }
      end
    end

    class RubyPlaceholderExpander
      attr_reader :placeholders

      # Get placeholders as a struct
      #
      # @param [Time]   time        the time
      # @param [Hash]   record      the record
      # @param [Hash]   opts        others
      def prepare_placeholders(time, record, opts)
        struct = UndefOpenStruct.new(record)
        struct.time = Time.at(time)
        opts.each {|key, value| struct.__send__("#{key}=", value) }
        @placeholders = struct
      end

      # Replace placeholders in a string
      #
      # @param [String] str         the string to be replaced
      def expand(str)
        str = str.gsub(/\$\{([^}]+)\}/, '#{\1}') # ${..} => #{..}
        eval "\"#{str}\"", @placeholders.instance_eval { binding }
      end

      class UndefOpenStruct < OpenStruct
        (Object.instance_methods).each do |m|
          undef_method m unless m.to_s =~ /^__|respond_to_missing\?|object_id|public_methods|instance_eval|method_missing|define_singleton_method|respond_to\?|new_ostruct_member/
        end
      end
    end
  end
end
