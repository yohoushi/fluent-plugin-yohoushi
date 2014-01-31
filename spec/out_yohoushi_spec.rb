# encoding: UTF-8
require_relative 'spec_helper'
require 'fluent/test/async_output_test'

shared_context "stub_yohoushi_post_graph" do |path|
  before do
    stub_request(:post, "#{yohoushi_base_uri}/api/graphs/#{path}").
    to_return(:status => 200, :body => { "error" => 0, "data" => "blahblah" }.to_json)
  end
end
shared_context "stub_growthforecast_post_graph" do |path|
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
  let(:driver) { Fluent::Test::MyAsyncOutputTestDriver.new(Fluent::YohoushiOutput, tag).configure(config) }
  let(:instance) { driver.instance }

  describe 'test configure' do
    context "empty" do
      let(:config) { '' } 
      it { expect { driver }.to raise_error(Fluent::ConfigError) }
    end

    context "no uri" do
      let(:config) { %[key1 foo_count /foobar/foo_count] }
      it { expect { driver }.to raise_error(Fluent::ConfigError) }
    end

    context "no keys" do
      let(:config) { %[base_uri #{yohoushi_base_uri}] }
      it { expect { driver }.to raise_error(Fluent::ConfigError) }
    end

    context "base_uri" do
      subject { driver.instance }
      let(:config) {%[
        base_uri #{yohoushi_base_uri}
        key1 foo_count /foobar/foo_count
      ]}
      it { subject.client.class == Yohoushi::Client }
    end

    context "mapping" do
      subject { driver.instance }
      let(:config) {%[
        mapping1 / #{growthforecast_base_uri}
        key1 foo_count /foobar/foo_count
      ]}
      it { subject.client.class == GrowthForecast::Client }
    end

    context "keys" do
      subject { driver.instance }
      let(:config) {%[
        base_uri #{yohoushi_base_uri}
        key1 foo_count /foobar/foo_count
        key2 bar_count /foobar/bar_count
      ]}
      it { subject.keys["foo_count"].should == "/foobar/foo_count" }
      it { subject.keys["bar_count"].should == "/foobar/bar_count" }
    end

    context "key_pattern" do
      subject { driver.instance }
      let(:config) {%[
        base_uri #{yohoushi_base_uri}
        key_pattern _count$ /foobar/${key}
      ]}
      it { subject.key_pattern.should == Regexp.compile("_count$") }
      it { subject.key_pattern_path.should == "/foobar/${key}" }
    end
  end

  describe 'test emit' do
    let(:emit) { d = driver; messages.each {|message| d.emit(message, time) }; d.run; }
    let(:time) { Time.now.to_i }
    let(:messages) do
      [
        { 'foo_count' => "1", 'bar_count' => "1" },
        { 'foo_count' => "2", 'bar_count' => "2" },
      ]
    end

    context 'base_uri and keys' do
      let(:config) {%[
        base_uri #{yohoushi_base_uri}
        key1 foo_count /path/to/foo_count
        key2 bar_count /path/to/bar_count
      ]}

      include_context "stub_yohoushi_post_graph", "path/to/foo_count" unless ENV["MOCK"] == "off"
      include_context "stub_yohoushi_post_graph", "path/to/bar_count" unless ENV["MOCK"] == "off"
      before { Fluent::Engine.stub(:now).and_return(time) }
      it { emit }
    end

    context 'base_uri and key_pattern' do
      let(:config) {%[
        base_uri #{yohoushi_base_uri}
        key_pattern _count$ /path/to/${key}
      ]}

      include_context "stub_yohoushi_post_graph", "path/to/foo_count" unless ENV["MOCK"] == "off"
      include_context "stub_yohoushi_post_graph", "path/to/bar_count" unless ENV["MOCK"] == "off"
      before { Fluent::Engine.stub(:now).and_return(time) }
      it { emit }
    end

    context 'mapping and keys' do
      let(:config) {%[
        mapping1 / #{growthforecast_base_uri}
        key1 foo_count /path/to/${key}
        key2 bar_count /path/to/${key}
      ]}

      include_context "stub_growthforecast_post_graph", "path/to/foo_count" unless ENV["MOCK"] == "off"
      include_context "stub_growthforecast_post_graph", "path/to/bar_count" unless ENV["MOCK"] == "off"
      before { Fluent::Engine.stub(:now).and_return(time) }
      it { emit }
    end

    context 'maping and key_pattern' do
      let(:config) {%[
        mapping1 / #{growthforecast_base_uri}
        key_pattern _count$ /path/to/${key}
      ]}

      include_context "stub_growthforecast_post_graph", "path/to/foo_count" unless ENV["MOCK"] == "off"
      include_context "stub_growthforecast_post_graph", "path/to/bar_count" unless ENV["MOCK"] == "off"
      before { Fluent::Engine.stub(:now).and_return(time) }
      it { emit }
    end
  end

  describe 'expand_placeholder with enable_ruby true' do
    let(:config) { %[mapping1 / http://foo] }
    let(:tag) { 'fluent.error' }
    let(:time) { Time.now.to_i }
    let(:record) { { 'foo_count' => "1" } }
    let(:emit) { d = driver; d.emit(record, time); d.run; }
    let(:expected_path)  { "/fluent/error/fluent.error/1/foo_count/#{Time.at(time)}" }
    let(:expected_value) { '1' }
    before { driver.instance.should_receive(:post).with(expected_path, expected_value) }

    context 'keyN' do
      let(:config) {%[
        mapping1 / http://foobar
        key1 foo_count /${tags.first}/${tag_parts.last}/${tag_prefix[1]}/${foo_count}/${CGI.unescape(key)}/${time}
        enable_ruby true
      ]}
      it { emit }
    end

    context 'key_pattern' do
      let(:config) {%[
        mapping1 / http://foobar
        key_pattern _count$ /${tags.first}/${tag_parts.last}/${tag_prefix[1]}/${foo_count}/${URI.unescape(key)}/${time.to_s}
        enable_ruby true
      ]}
      it { emit }
    end
  end

  describe 'expand_placeholder with enable_ruby false' do
    let(:config) { %[mapping1 / http://foo] }
    let(:tag) { 'fluent.error' }
    let(:time) { Time.now.to_i }
    let(:record) { { 'foo_count' => "1" } }
    let(:emit) { d = driver; d.emit(record, time); d.run; }
    let(:expected_path)  { "/fluent/error/fluent.error/1/foo_count/#{Time.at(time)}" }
    let(:expected_value) { '1' }
    before { driver.instance.should_receive(:post).with(expected_path, expected_value) }

    context 'keyN' do
      let(:config) {%[
        mapping1 / http://foobar
        key1 foo_count /${tags[0]}/${tag_parts[-1]}/${tag_prefix[1]}/${foo_count}/${key}/${time}
        enable_ruby false
      ]}
      it { emit }
    end

    context 'key_pattern' do
      let(:config) {%[
        mapping1 / http://foobar
        key_pattern _count$ /${tags[0]}/${tag_parts[-1]}/${tag_prefix[1]}/${foo_count}/${key}/${time}
        enable_ruby false
      ]}
      it { emit }
    end
  end
end
