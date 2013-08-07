# encoding: UTF-8
require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test)
Bundler.require(:default, :test)

require 'fluent/test'
require 'rspec'
require 'pry'
require 'multiforecast-client'
require 'webmock/rspec'
WebMock.allow_net_connect! if ENV['MOCK'] == 'off'

$TESTING=true
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'fluent/plugin/out_yohoushi'
