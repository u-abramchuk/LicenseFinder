require 'thor'

module LicenseFinder
  class Options

    def initialize(cli_options = {})
      @cli_options = cli_options
    end

    def project_path
      @project_path ||= Pathname(@cli_options.fetch(:project_path, Pathname.pwd)).expand_path
    end

    def valid_project_path?
      return project_path.exist?
    end

    def gradle_command
      get(:gradle_command)
    end

    def go_full_version
      get(:go_full_version)
    end

    def gradle_include_groups
      get(:gradle_include_groups)
    end

    def maven_include_groups
      get(:maven_include_groups)
    end

    def maven_options
      get(:maven_options)
    end

    def pip_requirements_path
      get(:pip_requirements_path)
    end

    def rebar_command
      get(:rebar_command)
    end

    def mix_command
      get(:mix_command) || 'mix'
    end

    def rebar_deps_dir
      path = get(:rebar_deps_dir) || 'deps'
      @project_path.join(path).expand_path
    end

    def mix_deps_dir
      path = get(:mix_deps_dir) || 'deps'
      @project_path.join(path).expand_path
    end

    def decisions_file_path
      path = get(:decisions_file) || 'doc/dependency_decisions.yml'
      @project_path.join(path).expand_path
    end

    def prepare
      get(:prepare)
    end

    private
    attr_reader :saved_config
    def saved_config
      return @saved_config unless @saved_config.nil?
      config_file =  project_path.join('config', 'license_finder.yml')
      @saved_config ||= config_file.exist? ? YAML.safe_load(config_file.read) : {}
    end

    def determined_option(key)
      @cli_options[key.to_sym] || saved_config[key.to_s]
    end

  end
end


module LicenseFinder
  module CLI
    class Base < Thor
      class_option :project_path,
                   desc: 'Path to the project. Defaults to current working directory.'
      class_option :decisions_file,
                   desc: 'Where decisions are saved. Defaults to doc/dependency_decisions.yml.'

      no_commands do
        def decisions
          license_finder.decisions
        end
      end

      private

      def license_finder
        @lf ||= LicenseFinder::Core.new(license_finder_config)
        fail "Project path '#{@lf.config.project_path}' does not exist!" unless @lf.config.valid_project_path?
        @lf
      end

      def fail(message)
        say(message) && exit(1)
      end

      def license_finder_config
        extract_options(
          :project_path,
          :decisions_file,
          :go_full_version,
          :gradle_command,
          :gradle_include_groups,
          :maven_include_groups,
          :maven_options,
          :pip_requirements_path,
          :rebar_command,
          :rebar_deps_dir,
          :mix_command,
          :mix_deps_dir,
          :save,
          :prepare
        ).merge(
          logger: logger_config
        )
      end

      def logger_config
        quiet = LicenseFinder::Logger::MODE_QUIET
        debug = LicenseFinder::Logger::MODE_DEBUG
        info = LicenseFinder::Logger::MODE_INFO
        mode = extract_options(quiet, debug)
        if mode[quiet]
          { mode: quiet }
        elsif mode[debug]
          { mode: debug }
        else
          { mode: info }
        end
      end

      def say_each(coll)
        if coll.any?
          coll.each do |item|
            say(block_given? ? yield(item) : item)
          end
        else
          say '(none)'
        end
      end

      def assert_some(things)
        raise ArgumentError, 'wrong number of arguments (0 for 1+)', caller unless things.any?
      end

      def extract_options(*keys)
        result = {}
        keys.each do |key|
          result[key.to_sym] = options[key.to_s] if options.key? key.to_s
        end
        result
      end
    end
  end
end
