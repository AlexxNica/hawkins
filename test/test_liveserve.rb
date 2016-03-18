require 'tmpdir'
require 'httpclient'

require_relative './spec_helper'

module Hawkins
  RSpec.describe "Hawkins" do
    context "when running in liveserve mode" do
      let!(:destination) do
        Dir.mktmpdir("jekyll-destination")
      end

      let(:client) do
        HTTPClient.new
      end

      let(:standard_opts) do
        {
          "port" => 4000,
          "host" => "localhost",
          "baseurl" => "",
          "detach" => false,
          "destination" => destination,
          "reload_port" => Commands::LiveServe.singleton_class::LIVERELOAD_PORT,
        }
      end

      before(:each) do
        site = instance_double(Jekyll::Site)
        simple_page = <<-HTML.gsub(/^\s*/, '')
        <!DOCTYPE HTML>
        <html lang="en-US">
        <head>
          <meta charset="UTF-8">
          <title>Hello World</title>
        </head>
        <body>
          <p>Hello!  I am a simple web page.</p>
        </body>
        </html>
        HTML

        File.open(File.join(destination, "hello.html"), 'w') do |f|
          f.write(simple_page)
        end
        allow(Jekyll::Site).to receive(:new).and_return(site)
      end

      after(:each) do
        capture_io do
          Commands::LiveServe.shutdown
        end

        while Commands::LiveServe.running?
          sleep(0.1)
        end

        File.delete(File.join(destination, "hello.html"))
        Dir.delete(destination)
      end

      def start_server(opts)
        @thread = Thread.new do
          Commands::LiveServe.start(opts)
        end

        while !Commands::LiveServe.running?
          sleep(0.1)
        end
      end

      def serve(opts)
        allow(Jekyll).to receive(:configuration).and_return(opts)
        allow(Jekyll::Commands::Build).to receive(:process)

        capture_io do
          start_server(opts)
        end

        opts
      end

      it "serves livereload.js over HTTP on the default LiveReload port" do
        opts = serve(standard_opts)
        content = client.get_content(
          "http://#{opts['host']}:#{opts['reload_port']}/livereload.js")
        expect(content).to include('LiveReload.on(')
      end

      it "serves nothing else over HTTP on the default LiveReload port" do
        opts = serve(standard_opts)
        res = client.get("http://#{opts['host']}:#{opts['reload_port']}/")
        expect(res.status_code).to eq(400)
        expect(res.content).to include('only serves livereload.js')
      end

      it "inserts the LiveReload script tags" do
        opts = serve(standard_opts)
        content = client.get_content(
          "http://#{opts['host']}:#{opts['port']}/#{opts['baseurl']}/hello.html")
        expect(content).to include("RACK_LIVERELOAD_PORT = #{opts['reload_port']}")
        expect(content).to include("I am a simple web page")
      end
    end
  end
end
