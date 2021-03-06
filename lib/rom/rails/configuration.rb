module ROM
  module Rails
    class Configuration
      attr_reader :config, :setup, :env

      def self.build(app)
        root = app.config.root
        db_config = app.config.database_configuration[::Rails.env].symbolize_keys

        config = rewrite_config(root, db_config)

        new(config)
      end

      def self.rewrite_config(root, config)
        adapter = config[:adapter]
        database = config[:database]
        password = config[:password]
        username = config[:username]
        hostname = config.fetch(:hostname) { 'localhost' }

        adapter = 'sqlite' if adapter == 'sqlite3'

        # FIXME: config parsing should be sent through adapters
        #        rom-rails shouldn't refer directly to any adapter constants
        if defined?(ROM::SQL) && ROM::SQL::Adapter.schemes.include?(adapter.to_sym)
          adapter.prepend('jdbc:') if RUBY_ENGINE == 'jruby'
        end

        path =
          if adapter.include?('sqlite')
            "#{root}/#{database}"
          else
            db_path = [hostname, database].join('/')

            if username && password
              [[username, password].join(':'), db_path].join('@')
            else
              db_path
            end
          end

        { default: "#{adapter}://#{path}" }
      end

      def initialize(config)
        @config = config.symbolize_keys
      end

      def setup!
        @setup = ROM.setup(@config.symbolize_keys)
      end

      def load!
        Railtie.load_all
      end

      def finalize!
        # rescuing fixes the chicken-egg problem where we have a relation
        # defined but the table doesn't exist yet
        @env = ROM.finalize.env
      rescue Registry::ElementNotFoundError => e
        warn "Skipping ROM setup => #{e.message}"
      end
    end
  end
end
