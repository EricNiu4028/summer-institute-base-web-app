# frozen_string_literal: true

require 'sinatra/base'
require 'logger'

# App is the main application where all your logic & routing will go
class App < Sinatra::Base
  set :erb, escape_html: true
  enable :sessions
  set :host_authorization, { permitted_hosts: ['ondemand.osc.edu'] }

  attr_reader :logger

  def initialize
    super
    @logger = Logger.new('log/app.log')
  end

  def title
    'Summer Institute Starter App'
  end

  def project_dirs
    Dir.children(projects_root).select do |path|
      Pathname.new("#{projects_root}/#{path}").directory?
    end.sort_by(&:to_s)
  end

  get '/examples' do
    erb(:examples)
  end

  get '/' do
    logger.info('requsting the index')
    erb(:index)
  end

  get '/projects/new' do
    erb(:new_project)
  end

  post '/projects/new' do
    logger.info("Trying to create a project with: #{params.inspect}")
    @flash = { info: "Trying to create a project with: #{params.inspect}" }
    
    dirname = params[:name].tr(' ', '_').downcase
    "#{projects_root}/#{dirname}".tap { |d| FileUtils.mkdir_p(d) }

    redirect(url("/projects/#{dirname}"))
  end

  get '/projects/:name' do
    @directory = Pathname.new("#{projects_root}/#{params[:name]}")

    if params[:name] == 'new'
      erb(:new_project)
    elsif @directory.directory? && @directory.readable?
      erb(:show_project)
    else
      @flash = {danger: "The project '#{params[:name]}' does not exist"}
      redirect(url('/'))
    end
  end

  private

  def projects_root
    "#{__dir__}/projects"
  end
end
