require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module OnlinePoker
  class Application < Rails::Application
    config.load_defaults 8.0
    config.autoload_lib(ignore: %w[assets tasks])
    config.time_zone = "Moscow"
    config.i18n.default_locale = :ru
    config.generators.system_tests = nil
  end
end
