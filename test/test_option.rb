# coding: utf-8
# frozen_string_literal: true

require_relative 'test_helper.rb'
require 'test/unit'
require 'tmpdir'
require_relative '../lib/option.rb'

class TestOption < ::Test::Unit::TestCase
  def test_initialize
    options = [
      '--checksum',
      '--recursive',
      '--times',
      '--dry-run',
      '--existing',
      '--ignore-existing',
      '--delete',
      '--ignore-times',
      '--size-only',
    ]
    for num_options in (0..options.size) do
      options.combination(num_options).each { |opts|
        if opts.include?('--delete') && !opts.include?('--recursive')
          assert_raise_kind_of(RuntimeError) do
            GDSync::Option.new(opts)
          end
        else
          assert_nothing_raised do
            GDSync::Option.new(opts)
          end
        end
      }
    end
  end
end