# coding: utf-8
# frozen_string_literal: true

require 'simplecov'
require 'coveralls'

SimpleCov.start do
  add_filter '/test'
end

Coveralls.wear! if ENV['TRAVIS'] == 'true'
