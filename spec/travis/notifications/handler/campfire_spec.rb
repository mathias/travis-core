require 'spec_helper'
require 'support/active_record'

describe Travis::Notifications::Handler::Campfire do
  include Support::ActiveRecord

  let(:campfire) { Travis::Notifications::Handler::Campfire.new }
  let(:http)     { Faraday::Adapter::Test::Stubs.new }
  let(:client)   { Faraday.new { |f| f.request :url_encoded; f.adapter :test, http } }
  let(:build)    { Factory(:build, :config => { 'notifications' => { 'campfire' => 'evome:apitoken@42' } }) }
  let(:io)       { StringIO.new }

  before do
    Travis.logger = Logger.new(io)
    Travis.config.notifications = [:campfire]
    campfire.stubs(:http_client).returns(client)
  end

  it "only is set up to accept build:finished notifications" do
    Travis::Notifications::Handler::Campfire::EVENTS.should === 'build:finished'
    Travis::Notifications::Handler::Campfire::EVENTS.should_not === 'build:started'
  end

  it "sends campfire notifications to the room given as a string" do
    target = 'evome:apitoken@42'
    build.config[:notifications][:campfire] = target
    verify_targets(build, target)
  end

  it "sends campfire notifications to the rooms given as an array" do
    targets = ['evome:apitoken@42', 'rails:sometoken@69']
    build.config[:notifications][:campfire] = targets
    verify_targets(build, *targets)
  end

  it "sends no campfire notification if the given url is blank" do
    build.config[:notifications][:campfire] = ''
    # No need to assert anything here as Faraday would complain about a request not being stubbed <3
    verify_targets(build)
  end


  def verify_targets(build, *schemes)
    schemes.each do |scheme|
      config = Travis::Notifications::Handler::Campfire.campfire_config(scheme)
      url    = Travis::Notifications::Handler::Campfire.campfire_url(config)

      uri = URI.parse(url)

      message = Travis::Notifications::Handler::Campfire.build_message(build)

      message.each do |line|
        http.post(uri.path) do |env|
          env[:url].host.should == uri.host
          env[:url].path.should == uri.path

          auth = Base64.encode64("#{config[:token]}:X").gsub("\n", "")
          env[:request_headers]['authorization'].should == "Basic #{auth}"

          env[:body].should == MultiJson.encode({ :message => { :body => line } })
        end
      end
    end

    campfire.notify('build:finished', build)

    http.verify_stubbed_calls
  end
end
