# encoding: UTF-8
require_relative 'spec_helper'

shared_context "stub_post_graph" do |path|
  before do
    stub_request(:post, "#{growthforecast_base_uri}/api/#{path}").
    to_return(:status => 200, :body => { "error" => 0, "data" => "blahblah" }.to_json)
  end
end

describe Fluent::YohoushiOutput do
  before { Fluent::Test.setup }
  let(:yohoushi_base_uri) { 'http://localhost:4804' }
  let(:growthforecast_base_uri) { 'http://localhost:5125' }
  let(:tag) { 'test' }
  let(:driver) { Fluent::Test::OutputTestDriver.new(Fluent::YohoushiOutput, tag).configure(config) }
  let(:emit) { driver.run { messages.each {|message| driver.emit(message, time) } } }

  describe 'test configure' do
    context "check empty" do
      let(:config) { '' } 
      it { expect { driver }.to raise_error(Fluent::ConfigError) }
    end

    context "check least" do
      subject { driver.instance }
      let(:config) {%[
        mapping_to #{growthforecast_base_uri}
        keys foo
      ]}
      its(:mapping_from) { should == [''] }
    end
  end

  describe 'test emit' do
    let(:time) { Time.now.to_i }
    let(:messages) do
      [
        { 'field1' => "1", 'field2' => "1" },
        { 'field1' => "2", 'field2' => "2" },
      ]
    end

    context 'typical' do
      let(:config) {%[
        mapping_from
        mapping_to #{growthforecast_base_uri}
        keys field1,field2
        paths /path/to/field1,/path/to/field2
      ]}
      let(:messages) do
        [
          { 'field1' => "1", 'field2' => "1" },
          { 'field1' => "2", 'field2' => "2" },
        ]
      end

      include_context "stub_post_graph", "path/to/field1" unless ENV["MOCK"] == "off"
      include_context "stub_post_graph", "path/to/field2" unless ENV["MOCK"] == "off"
      before { Fluent::Engine.stub(:now).and_return(time) }
      it { emit }
    end

    context 'no path' do
      let(:config) {%[
        mapping_from
        mapping_to #{growthforecast_base_uri}
        keys path/to/field1,path/to/field2
      ]}
      let(:messages) do
        [
          { 'field1' => "1", 'field2' => "1" },
          { 'field1' => "2", 'field2' => "2" },
        ]
      end

      include_context "stub_post_graph", "path/to/field1" unless ENV["MOCK"] == "off"
      include_context "stub_post_graph", "path/to/field2" unless ENV["MOCK"] == "off"
      before { Fluent::Engine.stub(:now).and_return(time) }
      it { emit }
    end

    context 'mapping' do
      let(:config) {%[
        mapping_from app1/,app2
        mapping_to http://localhost:5125,http://localhost:5000
        keys field1,field2
        paths /app1/to/field1,/app2/to/field2
      ]}
      before do
        stub_request(:post, "http://localhost:5125/api/app1/to/field1").
        to_return(:status => 200, :body => { "error" => 0, "data" => "blahblah" }.to_json)
        stub_request(:post, "http://localhost:5000/api/app2/to/field2").
        to_return(:status => 200, :body => { "error" => 0, "data" => "blahblah" }.to_json)
      end
      before { Fluent::Engine.stub(:now).and_return(time) }
      it { emit }
    end

    context 'base_uri' do
      let(:config) {%[
        base_uri #{yohoushi_base_uri}
        keys field1
        paths /app1/to/field1,
      ]}
      before do
        # should post via yohoushi client
        stub_request(:post, "#{yohoushi_base_uri}/api/graphs/app1/to/field1").
        to_return(:status => 200, :body => { "error" => 0, "data" => "blahblah" }.to_json)
      end
      before { Fluent::Engine.stub(:now).and_return(time) }
      it { emit }
    end
  end
end
