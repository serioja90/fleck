#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler'
Bundler.require
require 'pathname'

require "#{File.expand_path(__dir__)}/config/version.rb"
require "#{File.expand_path(__dir__)}/config/config.rb"
require "#{File.expand_path(__dir__)}/config/options.rb"

load_paths = ['lib', 'config', 'app/models', 'app/controllers', 'app/jobs', 'app/replicators', 'app']

def require_recursive(path = File.expand_path(__dir__), pattern = '*.rb')
  # First load recursively files from directories with ascending ordering
  Dir.glob(File.join(path, '*/')).sort.each do |directory|
    require_recursive(directory, pattern)
  end

  # Then load the files with ascending ordering
  Dir.glob(File.join(path, pattern)).sort.each { |file| require file }
end

# Recursively require ruby files from folders specified in `load_paths`
load_paths.each do |path|
  next unless File.exist?(path)

  require_recursive(File.join(__dir__, path), '*.rb')
end

if Config.interactive
  require 'pry'
  require 'pry-reload'
  nil.pry
else
  Lounger.idle
end
