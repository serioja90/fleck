$LOAD_PATH.unshift(File.dirname(__FILE__))

autoload :FileUtils, 'fileutils'
autoload :ERB, 'erb'

class Cli < Thor
  include Thor::Actions
  autoload "Installation", "cli/installation"

  desc "new APP_NAME", "Creates a new Fleck app"
  option :path, aliases: "-p", type: :string, desc: "Path where to create the new app"
  def new(app_name)
    path = options[:path] || Dir.pwd
    say "Creating new app at `#{path}/#{app_name}`"
    installation = Installation.new(app_name, path, File.dirname(__FILE__))
    installation.start
  rescue Interrupt
    canceled!
  end

  private

  def canceled!
    say "[Canceled]", :red
    exit 0
  end
end