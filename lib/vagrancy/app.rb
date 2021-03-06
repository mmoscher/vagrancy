require 'sinatra/base'

require 'vagrancy/filestore'
require 'vagrancy/filestore_configuration'
require 'vagrancy/upload_path_handler'
require 'vagrancy/box'
require 'vagrancy/provider_box'
require 'vagrancy/dummy_artifact'
require 'vagrancy/invalid_file_path'

module Vagrancy
  class App < Sinatra::Base
    set :logging, true
    set :show_exceptions, :after_handler

    error Vagrancy::InvalidFilePath do
      status 403
      env['sinatra.error'].message
    end


    get '/:username/:name' do
      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)

      status box.exists? ? 200 : 404
      content_type 'application/json'
      box.to_json if box.exists?
    end

    put '/:username/:name/:version/:provider' do
      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)
      provider_box = ProviderBox.new(params[:provider], params[:version], box, filestore, request)

      provider_box.write(request.body)
      status 201
    end

    get '/:username/:name/:version/:provider' do
      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)
      provider_box = ProviderBox.new(params[:provider], params[:version], box, filestore, request)

      send_file filestore.file_path(provider_box.file_path) if provider_box.exists?
      status provider_box.exists? ? 200 : 404
    end

    delete '/:username/:name/:version/:provider' do
      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)
      provider_box = ProviderBox.new(params[:provider], params[:version], box, filestore, request)

      status provider_box.exists? ? 200 : 404
      provider_box.delete
    end


    #Vagrant cloud api emulation
    get '/api/v1/box/:username/:name' do
      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)

      status box.exists? ? 200 : 404
      content_type 'application/json'
      box.to_json
    end

    post '/api/v1/box/:username/:name/versions' do
      request.body.rewind
      request_payload = JSON.parse request.body.read
      version = request_payload['version']['version']

      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)
      box_version = BoxVersion.new(version, box, filestore, request)

      status 200 #box_version.exists? ? 200 : 404
      content_type 'application/json'
      box_version.to_json #if box_version.exists?
    end

    post '/api/v1/box/:username/:name/version/:version/providers' do
      request.body.rewind
      request_payload = JSON.parse request.body.read
      provider = request_payload['provider']['name']

      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)
      provider_box = ProviderBox.new(provider, params[:version], box, filestore, request)

      status 200 #provider_box.exists? ? 200 : 404
      content_type 'application/json'
      provider_box.to_json #if box_version.exists?      
    end

    #Api commands that do stuff
    get '/api/v1/box/:username/:name/version/:version/provider/:provider/upload' do
      content_type 'application/json'
      body '{ 
        "upload_path": "http://%s:%s/api/v1/box/%s/%s/version/%s/provider/%s"
      }' % [ request.host, request.port, params[:username], params[:name], params[:version], params[:provider] ]
      status 200
    end

    put '/api/v1/box/:username/:name/version/:version/provider/:provider' do
      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)
      provider_box = ProviderBox.new(params[:provider], params[:version], box, filestore, request)

      provider_box.write(request.body)
      status 200
    end    

    delete '/api/v1/box/:username/:name/version/:version/provider/:provider' do
      box = Vagrancy::Box.new(params[:name], params[:username], filestore, request)
      provider_box = ProviderBox.new(params[:provider], params[:version], box, filestore, request)

      status provider_box.exists? ? 200 : 404
      provider_box.delete
    end

    put '/api/v1/box/:username/:name/version/:version/release' do
      status 200
    end

    # Atlas emulation, no authentication
    get '/api/v1/authenticate' do
      status 200
    end    

    post '/api/v1/artifacts/:username/:name/vagrant.box' do
      content_type 'application/json'
      UploadPathHandler.new(params[:name], params[:username], request, filestore).to_json
    end

    get '/api/v1/artifacts/:username/:name' do
      status 200
      content_type 'application/json'
      DummyArtifact.new(params).to_json
    end

    def filestore 
      path = FilestoreConfiguration.new.path
      Filestore.new(path)
    end

  end
end
