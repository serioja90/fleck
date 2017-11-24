class Cli::Installation < Thor::Group
  include Cli::Utilities

  def initialize(app_name, path, base)
    @base = base
    @name = app_name
    @path = path
    @app_dir = "#{path}/#{app_name}"
    @use_db = true
    @db_type = nil
    @fleck_version = Fleck::VERSION
    @templates = "#{@base}/templates"
  end

  def start
    setup_app_dir
    setup_db_dir
    generate_gemfile
    bundle_install
    init_git
  end

  private

  # Setup app dir and all the dirs used by application
  def setup_app_dir
    if File.exists?(@app_dir)
      say "A file/directory at #{@app_dir} already exists!", :yellow
      if yes?("Do you want to re-install the app? All the contents at #{@app_dir} will be lost! [No/yes] ", :yellow)
        rm_rf @app_dir
      else
        cancel!
      end
    end

    mkdir_p @app_dir
    cp "#{@base}/templates/gitignore", "#{@app_dir}/.gitignore"

    make_empty_dir "#{@app_dir}/app/models"
    make_empty_dir "#{@app_dir}/app/controllers"
    make_empty_dir "#{@app_dir}/lib"
    make_empty_dir "#{@app_dir}/log"
    make_empty_dir "#{@app_dir}/tmp"
  end


  # setup db dir
  def setup_db_dir
    @use_db = true

    if no? "Will your app use database? [Yes/no]"
      @use_db = false
    end

    if @use_db
      make_empty_dir "#{@app_dir}/db/migrations"
    end
  end


  # Generate the Gemfile for the new application
  def generate_gemfile
    if @use_db
      @db_type = ask "Which kind of database would you like to use?", limited_to: ["postgres", "mysql", "sqlite"]
      say "You choosed: #{@db_type.inspect}"
    end

    template = ERB.new(IO.read("#{@base}/templates/Gemfile.erb"))
    IO.write("#{@app_dir}/Gemfile", template.result(binding))
  end


  # Install gems listed in Gemfile
  def bundle_install
    run "bundle install", wd: @app_dir
  end


  # Initialize a Git repository within the app directory
  def init_git
    run "git init .", wd: @app_dir
  end


  # Make a new empty directory
  def make_empty_dir(path)
    mkdir_p path
    touch "#{path}/.gitkeep"
  end
end