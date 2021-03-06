require 'spec_helper'
require 'support/active_record'

describe Travis::Notifications::Handler::Worker::Payload do
  include Support::ActiveRecord

  Payload = Travis::Notifications::Handler::Worker::Payload

  let(:repository) { Repository.new(:owner_name => 'travis-ci', :name => 'travis-ci') }
  let(:commit)     { Factory(:commit, :repository => repository) }

  let(:configure)  { Factory(:configure, :commit => commit) }
  let(:test)       { Factory(:test) }

  describe 'for returns the payload required for worker jobs' do
    it 'Job::Configure' do
      Payload.for(configure).keys.should == [:type, :build, :repository, :queue]
    end

    it 'Job::Test' do
      Payload.for(test).keys.should == [:type, :build, :repository, :config, :queue]
    end
  end
end
