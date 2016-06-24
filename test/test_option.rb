# coding: utf-8
# frozen_string_literal: true

require_relative 'test_helper.rb'
require 'test/unit'
require 'tmpdir'
require_relative '../lib/option.rb'

class TestOption < ::Test::Unit::TestCase
  def test_validate
    options = GDSync::Option::SUPPORTED_OPTIONS

    (0..options.size).each do |num_options|
      options.combination(num_options).each do |opts|
        if opts.include?('--delete') && !(opts.include?('--recursive') || opts.include?('--dirs'))
          assert_raise_kind_of(RuntimeError) do
            GDSync::Option.new(opts)
          end
        else
          assert_nothing_raised do
            GDSync::Option.new(opts)
          end
        end
      end
    end
  end

  def test_recursive_overrides_dirs
    o = GDSync::Option.new(['--dirs'])
    assert_true(o.dirs?)

    o = GDSync::Option.new(['--dirs', '--recursive'])
    assert_false(o.dirs?)

    o = GDSync::Option.new(['--recursive'])
    assert_false(o.dirs?)
  end

  def test_minmax_size
    o = GDSync::Option.new(['--max-size=1.5mb-1'])
    assert_equal(1_499_999, o.max_size)

    o = GDSync::Option.new(['--min-size=2g+1'])
    assert_equal(2_147_483_649, o.min_size)

    o = GDSync::Option.new(['--max-size=+1'])
    assert_equal(1, o.max_size)

    assert_raise_kind_of(RuntimeError) do
      GDSync::Option.new(['--max-size=0'])
    end

    assert_raise_kind_of(RuntimeError) do
      GDSync::Option.new(['--max-size=-1'])
    end

    assert_raise_kind_of(RuntimeError) do
      GDSync::Option.new(['--max-size=1kb+2'])
    end

    assert_raise_kind_of(RuntimeError) do
      GDSync::Option.new(['--min-size=kb'])
    end

    assert_raise_kind_of(RuntimeError) do
      GDSync::Option.new(['--min-size=0x01kb'])
    end

    assert_raise_kind_of(RuntimeError) do
      GDSync::Option.new(['--min-size=1.00.1'])
    end

    assert_raise_kind_of(RuntimeError) do
      GDSync::Option.new(['--max-sizee=1'])
    end
  end
end
