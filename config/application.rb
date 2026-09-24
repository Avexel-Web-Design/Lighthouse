require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Lighthouse
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Use structure.sql instead of schema.rb so PostgreSQL-specific objects
    # (materialized views, custom indexes, etc.) are preserved across db:setup/reset.
    config.active_record.schema_format = :sql

    # Active Storage defaults to the :vips variant processor, but the engine
    # requires image_processing/vips at boot. image_processing 2.x re-raises a
    # missing native libvips as a generic LoadError (no "libvips" in the message),
    # which bypasses Rails' graceful fallback and crashes boot. This app only
    # attaches photos (no variants), so fall back to :disabled when libvips is
    # absent. CI/Dockerfile install libvips and keep using :vips.
    begin
      require "vips"
    rescue LoadError
      config.active_storage.variant_processor = :disabled
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
