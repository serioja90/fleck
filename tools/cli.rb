$LOAD_PATH.unshift(File.dirname(__FILE__))

class Cli < Thor
  autoload :Utilities, "cli/utilities"
  autoload :Installation, "cli/installation"

  include Thor::Actions
  include Cli::Utilities

  desc "new APP_NAME", "Creates a new Fleck app"
  option :path, aliases: "-p", type: :string, desc: "Path where to create the new app"
  def new(app_name)
    path = options[:path] || Dir.pwd
    say "Creating new app at `#{path}/#{app_name}`"
    installation = Installation.new(app_name, path, File.dirname(__FILE__))
    installation.start
  rescue Interrupt
    cancel!
  end
end