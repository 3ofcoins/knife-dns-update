module KnifeDnsUpdate
  class Config
    class << self
      def option(name, default=nil)
        ivar = "@#{name}".to_sym
        define_method name do |*args|
          if args.length.zero?
            if instance_variable_defined?(ivar)
              instance_variable_get(ivar)
            else
              default
            end
          elsif block_given?
            instance_variable_set(ivar, yield(*args))
          elsif args.length == 1
            instance_variable_set(ivar, args[0])
          else
            instance_variable_set(ivar, args)
          end
        end
      end
    end

    option(:zone) { |domain| domain.gsub(/^\.*|\.*$/, '') }
    option :subdomain
    option :ttl, 3600
    attr_reader :entries

    def initialize(path=nil)
      @entries = {}
      instance_eval(File.read(path), path, 1) if path
    end

    def entry(name, opt={}, &block)
      raise "Entry #{name} without definition or block" unless opt||block_given?

      case opt
      when /^\d+\.\d+\.\d+\.\d+$/ then opt = { :a => opt }
      when /^[a-z0-9.-]+\.$/      then opt = { :cname => opt }
      when /^[a-z0-9.-]+$/        then opt = { :cname => [ opt, subdomain, zone ].compact.join('.') << '.' }
      when /^name:[a-z0-9.-]+$/   then opt = { :node => opt[5..-1] }
      when /:/                    then opt = { :query => opt }
      end

      opt[:block] = block if block_given?

      if opt[:q]
        opt[:query] = opt[:q]
        opt.delete(:q)
      end

      entries[name] ||= []
      entries[name] << opt
    end

    def record_for_node(node, is_root_record=false)
      case
      when block_given?
        yield node
      when !is_root_record && node['cloud'] && node['cloud']['public_hostname']
        [ :cname, node['cloud']['public_hostname'] ]
      when node['cloud'] && node['cloud']['public_ipv4']
        [ :a, node['cloud']['public_ipv4'] ]
      when !is_root_record && node['fqdn'] && node['fqdn'] !~ /#{Regexp.escape(zone)}$/
        [ :cname, node['fqdn'] ]
      when node['ipaddress']
        [ :a, node['ipaddress'] ]
      end
    end

    def personalization_token(node)
      node.name.gsub(/[^a-z0-9-]+/, '-')
    end
  end
end
