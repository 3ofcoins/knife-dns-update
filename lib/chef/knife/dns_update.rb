require 'chef/config'
require 'chef/knife'

module KnifeDnsUpdate
  class DnsUpdate < Chef::Knife
    banner "knife dns update"

    deps do
      require 'set'
      require 'chef/node'
      require 'chef/api_client'
      require 'chef/search/query'
      require 'fog'
      require 'knife-dns-update'
    end

    option :dry_run,
      :short => "-n",
      :long => "--dry-run",
      :description => "Don't execute updates",
      :boolean => false

    option :aws_access_key_id,
      :short => "-A ID",
      :long => "--aws-access-key-id KEY",
      :description => "Your AWS Access Key ID",
      :proc => Proc.new { |key| Chef::Config[:knife][:aws_access_key_id] = key }

    option :aws_secret_access_key,
      :short => "-K SECRET",
      :long => "--aws-secret-access-key SECRET",
      :description => "Your AWS API Secret Access Key",
      :proc => Proc.new { |key| Chef::Config[:knife][:aws_secret_access_key] = key }

    attr_reader :entries, :cfg

    def entry(name, type, data)
      @entries ||= {}

      name = nil if name == '@'
      fqdn = [name, cfg.subdomain, cfg.zone].compact.join('.') + '.'
      type = type.to_s.upcase

      if entries.key?([fqdn, type])
        ui.warn("Redefining #{fqdn} IN #{type} #{entries[[name,type]]} --> #{data}")
      elsif config[:verbosity] >= 2
        ui.info("Defining: #{fqdn} IN #{type} #{data}")
      end
      entries[[fqdn, type]] = data
    end

    def run
      @cfg = Config.new('config/dns.rb')

      Chef::Node.list.keys.sort.map(&Chef::Node.method(:load)).each do |node|
        entry(node.name.gsub(/[^a-z0-9-]+/, '-'), *cfg.record_for_node(node))
      end

      cfg.entries.each do |name, optses|
        optses.each do |opts|
          entry(name, opts[:type], opts[:data]) if opts[:type] && opts[:data]
          entry(name, :a, opts[:a]) if opts[:a]
          entry(name, :cname, opts[:cname]) if opts[:cname]

          if opts[:block] && !(opts[:node] || opts[:query])
            # Bare block
            entry(name, *opts[:block].call)
          end

          is_root_record = (name == '@')

          if opts[:node]
            entry(name, *cfg.record_for_node(
              Chef::Node.load(opts[:node]), is_root_record, &opts[:block]))
          end

          if opts[:query]
            q = Chef::Search::Query.new
            q.search(:node, opts[:query]).first.each do |node|
              entry( name.sub('*', cfg.personalization_token(node)),
                     *cfg.record_for_node(node, is_root_record, &opts[:block]))
            end
          end
        end
      end

      dns_config = Chef::Config[:dns].dup
      dns_config[:provider] ||= 'AWS'
      if dns_config[:provider] == 'AWS'
        dns_config[:aws_access_key_id] ||= config[:aws_access_key_id]
        dns_config[:aws_secret_access_key] ||= config[:aws_secret_access_key]
      end
      dns = Fog::DNS.new(dns_config)
      zone = dns.zones.find { |z| z.domain =~ /#{Regexp.quote(cfg.zone)}\.?$/ }
      raise "No zone found for #{cfg.zone}; available zones: #{dns.zones.map(&:domain).join(', ')}" unless zone

      managed = Set.new

      zone.records.all!.each do |rec|
        next if %w(NS SOA).include? rec.type
        ui.info("Looking at: #{rec.name} IN #{rec.type} #{rec.value}") if config[:verbosity] >= 3

        if cfg.subdomain && rec.name !~ /#{Regexp.quote(cfg.subdomain)}\.#{Regexp.quote(cfg.zone)}\.?$/
          ui.info("Not in subdomain, skipping: #{rec.name} IN #{rec.type} #{rec.value}") if config[:verbosity] >= 1
          next
        end

        value = rec.value.respond_to?(:first) ? rec.value.first : rec.value
        if entries[[rec.name, rec.type]] == value
          # Record exists on server and has the same value. We leave it be.
          ui.info("= #{rec.name} IN #{rec.type} #{value}") if config[:verbosity] >= 1
          managed.add([rec.name, rec.type])
        else
          ui.info "- #{rec.name} IN #{rec.type} #{value}"
          rec.destroy unless config[:dry_run]
        end

        # FIXME next if cfg.subdomain && rec.name !~ /#{Regex.quote(cfg.subdomain).
      end

      entries.each do |resource, value|
        next if managed.include?(resource)
        name, type = resource
        ui.info "+ #{name} IN #{type} #{value}"
        zone.records.create(:name => name, :type => type, :value => value, :ttl => cfg.ttl) unless config[:dry_run]
      end
    end
  end
end

class Chef::Config
  default :dns, {}
end
