# coding: utf-8
# frozen_string_literal: true

require_relative 'test_helper.rb'
require 'test/unit'
require_relative '../lib/file_system.rb'

class TestFileSystem < ::Test::Unit::TestCase
  class FileSystemStub < ::GDSync::FileSystem
    class File < ::GDSync::FileSystem::AbstractFile
    end

    class Dir < ::GDSync::FileSystem::AbstractDir
    end
  end

  def setup
    @fs = FileSystemStub.new
    @file = FileSystemStub::File.new
    @dir = FileSystemStub::Dir.new
  end

  def test_can_create_io_stream?
    assert_raise_kind_of(RuntimeError) do
      @fs.can_create_io_stream?
    end
  end

  def test_find
    assert_raise_kind_of(RuntimeError) do
      @fs.find('path_to_somewhere')
    end
  end

  def test_file
    assert_raise_kind_of(RuntimeError) do
      @file.title
    end

    assert_raise_kind_of(RuntimeError) do
      @file.path
    end

    assert_false(@file.dir?)

    assert_raise_kind_of(RuntimeError) do
      @file.size
    end

    assert_raise_kind_of(RuntimeError) do
      @file.mtime
    end

    assert_raise_kind_of(RuntimeError) do
      @file.birthtime
    end

    assert_raise_kind_of(RuntimeError) do
      @file.md5
    end

    assert_raise_kind_of(RuntimeError) do
      @file.fs
    end

    assert_raise_kind_of(RuntimeError) do
      @file.create_read_io
    end

    assert_raise_kind_of(RuntimeError) do
      @file.write_to(nil)
    end

    assert_raise_kind_of(RuntimeError) do
      @file.update!(nil, nil)
    end

    assert_raise_kind_of(RuntimeError) do
      @file.copy_to(nil, nil, nil)
    end

    assert_raise_kind_of(RuntimeError) do
      @file.delete!
    end
  end

  def test_dir
    assert_raise_kind_of(RuntimeError) do
      @dir.title
    end

    assert_true(@dir.dir?)

    assert_raise_kind_of(RuntimeError) do
      @dir.entries do
      end
    end

    assert_raise_kind_of(RuntimeError) do
      @dir.fs
    end

    assert_raise_kind_of(RuntimeError) do
      @dir.create_dir!(nil)
    end

    assert_raise_kind_of(RuntimeError) do
      @dir.create_file_with_read_io!(nil, nil, nil, nil)
    end

    assert_raise_kind_of(RuntimeError) do
      @dir.create_write_io!(nil)
    end

    assert_raise_kind_of(RuntimeError) do
      @dir.delete!
    end

    assert_raise_kind_of(RuntimeError) do
      @dir.path
    end
  end
end
