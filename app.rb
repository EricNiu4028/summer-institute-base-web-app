# frozen_string_literal: true

require 'sinatra/base'
require 'logger'

# App is the main application where all your logic & routing will go
class App < Sinatra::Base
  set :erb, escape_html: true
  enable :session
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

  def accounts
    Process.groups.map do |gid|
      Etc.getgrgid(gid).name
    end.select do |grname|
      grname.start_with? 'P'
    end
  end

  def blend_files
    Dir.glob("#{__dir__}/blend_files/*.blend").map do |file|
    File.basename(file)
    end
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
    @project_name = @directory.basename.to_s.gsub('_', ' ').capitalize
    @flash = session.delete(:flash)

    image_list = Dir.glob("#{@directory}/*.png")
    @images = image_list unless image_list.empty?
    
    video_path = "#{@directory}/video.mp4"
    @video = video_path if File.exist?(video_path)

    if params[:name] == 'new'
      erb(:new_project)
    elsif @directory.directory? && @directory.readable?
      erb(:show_project)
    else
      @flash = {danger: "The project '#{params[:name]}' does not exist"}
      redirect(url('/'))
    end


  end

  post '/render/frames' do
    logger.info("rendering frames with #{params.inspect}")

    blend_file = "#{__dir__}/blend_files/#{params[:blend_file]}"
    walltime = format('%02d:00:00', params[:walltime])
    dir = params[:project_directory]

    args = ['-J', "blender-#{params[:blend_file]}", '--parsable', '-A', params[:account]]
    args.concat ['--export', "BLEND_FILE_PATH=#{blend_file},OUTPUT_DIR=#{dir},FRAME_RANGE=#{params[:frame_range]}"]
    args.concat ['-n', params[:num_cpus], '-N', '1', '-t', walltime, '-M', 'cardinal']
    args.concat ['--output', "#{dir}/%j.out"]

    output = `/bin/sbatch #{args.join(' ')}  #{__dir__}/scripts/render_frames.sh 2>&1`
    job_id = output.strip.split(';').first

    session[:flash] = { info: "submitted job #{job_id}" }
    redirect(url("/projects/#{dir.split('/').last}"))
  end

  post '/render/video' do
    logger.info("Trying to render video with: #{params.inspect}")

    walltime = format('%02d:00:00', params[:walltime])
    frames_per_second = params[:frames_per_second]
    dir = params[:project_directory]

    args = ['-J', 'blender-video', '--parsable', '-A', params[:account]]
    args.concat ['--export', "OUTPUT_DIR=#{dir},FRAMES_PER_SEC=#{frames_per_second}"]
    args.concat ['-n', params[:num_cpus], '-N', '1', '-t', walltime, '-M', 'ascend']
    args.concat ['--output', "#{dir}/%j.out"]

    output = `/bin/sbatch #{args.join(' ')}  #{__dir__}/scripts/render_video.sh 2>&1`

    job_id = output.strip.split(';').first

    session[:flash] = { info: "submitted with params #{params}" }
    redirect(url("/projects/#{dir.split('/').last}"))
    

  end

  post '/delete' do
    directory = Pathname.new("#{params[:project_directory]}")

    Pathname.new(directory).rmtree
    logger.info("Trying to delete directory: #{directory}")

    session[:flash] = { info: "Deleted #{directory}" }
    redirect(url('/'))
  end

  private

  def projects_root
    "#{__dir__}/projects"
  end
end
