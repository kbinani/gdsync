# coding: utf-8
# frozen_string_literal: true

require_relative 'test_helper.rb'
require 'test/unit'
require 'tmpdir'
require_relative '../lib/sync.rb'
require_relative '../lib/option.rb'

class TestSync < ::Test::Unit::TestCase
  OPTIONS = GDSync::Option::SUPPORTED_OPTIONS

  data do
    options = {}
    for num_options in (0..OPTIONS.size) do
      OPTIONS.combination(num_options).each { |rsync_options|
        key = rsync_options.join(' ')
        options[key] = rsync_options
      }
    end
    options
  end
  def test_run(data)
    rsync_options = data
    _run(rsync_options)
  end

  private

  VERBOSE = false

  def _run(rsync_options)
    Dir.mktmpdir { |workdir|
      _case(rsync_options, workdir, false)
    }
    Dir.mktmpdir { |workdir|
      _case(rsync_options, workdir, true)
    }
  end

  def _case(rsync_options, workdir, with_trailing_slash)
    # GDSync::Sync#run should have same behavior to rsync(1).
    # So, at first, prepare *expected* directory using rsync(1),
    # then run GDSync::Sync#run to create *actual* directory, and compare them.

    opt = nil
    begin
      opt = GDSync::Option.new(rsync_options)
    rescue
      # Do not run test if rsync_options is not valid.
      return
    end

    _separator("=") if VERBOSE

    assert_mtime = rsync_options.include?('--times')
    assert_checksum = rsync_options.include?('--checksum')

    # Create copy of 'test/fixtures' directory.
    # The contents in it will be edited for testing purpouse (this is the reason why we create a copy of it).
    fixtures = File.join(workdir, "fixtures#{with_trailing_slash ? '/' : ''}")
    _rsync('test/fixtures', workdir, ['-a'])

    # Run rsync(1) to create *expected* directory structure.
    expected = File.join(workdir, 'expected')
    Dir.mkdir(expected)
    _rsync(fixtures, expected, rsync_options)

    # Create target directory.
    dest = File.join(workdir, 'dest')
    Dir.mkdir(dest)

    # Print what options are being tested.
    prefix = "#{workdir}/"
    cmd = "rsync #{rsync_options.join(' ')} #{fixtures.split(prefix)[1]} #{dest.split(prefix)[1]}"
    puts cmd if VERBOSE

    # Run GDSync::Sync#run
    assert_nothing_raised do
      sync = GDSync::Sync.new([fixtures], dest, opt)
      sync.run

      if VERBOSE
        _separator
        puts "FIXTURE(after#1):"
        _tree(File.join(workdir, 'fixtures'))
        puts "EXPECTED(after#1):"
        _tree(File.join(workdir, 'expected'))
        puts "ACTUAL(after#1):"
        _tree(File.join(workdir, 'dest'))
      end
    end

    # Compare directory structure between 'sync.run'ed dir and 'rsync'ed dir.
    _assert_dir_tree_equals(expected, dest, assert_mtime, assert_checksum)

    # Modify 'fixtures'.
    FileUtils.rm_r(File.join(workdir, 'fixtures', 'delete_local'))
    FileUtils.remove(File.join(workdir, 'fixtures', 'delete_local_file.txt'))

    edited_local_file = File.join(workdir, 'fixtures', 'sub', 'edited_local_file.txt')
    open(edited_local_file, 'wb') { |f|
      f << 'a'
    }

    edited_but_same_mtime_local_file = File.join(workdir, 'fixtures', 'sub', 'edited_but_same_mtime_local_file.txt')
    mtime = File.mtime(edited_but_same_mtime_local_file)
    open(edited_but_same_mtime_local_file, 'wb') { |f|
      f << 'c'
    }
    File.utime(mtime, mtime, edited_but_same_mtime_local_file)

    edited_but_same_mtime_and_same_size_local_file = File.join(workdir, 'fixtures', 'sub', 'edited_but_same_mtime_and_same_size_local_file.txt')
    mtime = File.mtime(edited_but_same_mtime_and_same_size_local_file)
    open(edited_but_same_mtime_local_file, 'wb') { |f|
      f.write('A')
    }
    File.utime(mtime, mtime, edited_but_same_mtime_and_same_size_local_file)

    # Modify 'dest' and 'expected'
    mid = with_trailing_slash ? '' : '/fixtures'
    [expected, dest].each { |d|
      FileUtils.rm_rf(File.join("#{d}#{mid}", 'delete_remote'))
      FileUtils.rm_rf(File.join("#{d}#{mid}", 'delete_remote_file.txt'))

      edited_remote_file = File.join("#{d}#{mid}", 'sub', 'edited_remote_file.txt')
      if File.exist?(edited_remote_file)
        open(edited_remote_file, 'wb') { |f|
          f << 'b'
        }
      end

      edited_but_same_mtime_remote_file = File.join("#{d}#{mid}", 'sub', 'edited_but_same_mtime_remote_file.txt')
      if File.exist?(edited_but_same_mtime_remote_file)
        mtime = File.mtime(edited_but_same_mtime_remote_file)
        open(edited_but_same_mtime_remote_file, 'wb') { |f|
          f << 'd'
        }
        File.utime(mtime, mtime, edited_but_same_mtime_remote_file)
      end

      edited_but_same_mtime_and_same_size_remote_file = File.join("#{d}#{mid}", 'sub', 'edited_but_same_mtime_and_same_size_remote_file.txt')
      if File.exist?(edited_but_same_mtime_and_same_size_remote_file)
        mtime = File.mtime(edited_but_same_mtime_and_same_size_remote_file)
        open(edited_but_same_mtime_and_same_size_remote_file, 'wb') { |f|
          f.write('A')
        }
        File.utime(mtime, mtime, edited_but_same_mtime_and_same_size_remote_file)
      end
    }

    # Second run rsync
    _rsync(fixtures, expected, rsync_options)

    # Second run GDSync::Sync#run
    assert_nothing_raised do
      sync = GDSync::Sync.new([fixtures], dest, opt)
      sync.run

      if VERBOSE
        _separator
        puts "FIXTURE(after#2):"
        _tree(File.join(workdir, 'fixtures'))
        puts "EXPECTED(after#2):"
        _tree(File.join(workdir, 'expected'))
        puts "ACTUAL(after#2):"
        _tree(File.join(workdir, 'dest'))
      end
    end

    # Second compare
    _assert_dir_tree_equals(expected, dest, assert_mtime, assert_checksum)
  end

  def _assert_dir_tree_equals(expected, actual, assert_mtime, assert_checksum)
    e = Dir.entries(expected).select { |_| _ != '.' && _ != '..' }.sort
    a = Dir.entries(actual).select { |_| _ != '.' && _ != '..' }.sort
    assert_equal(e, a)

    for i in (0...e.size) do
      epath = File.join(expected, e[i])
      apath = File.join(actual, a[i])

      assert_equal(e[i], a[i])
      if File.directory?(epath)
        assert_true(File.directory?(apath))
        _assert_dir_tree_equals(epath, apath, assert_mtime, assert_checksum)
      else
        assert_false(File.directory?(apath))
        assert_equal(File.mtime(epath), File.mtime(apath)) if assert_mtime
        assert_equal(::Digest::MD5.file(epath).to_s, ::Digest::MD5.file(apath).to_s) if assert_checksum
      end
    end
  end

  def _rsync(src, dest, options)
    cmd = "rsync #{options.join(' ')} #{src} #{dest}"
    raise "#{cmd} failed" unless `#{cmd}`
  end

  def _tree(dir)
    lines = `tree #{dir}`.lines
    lines = lines.slice(1, lines.size - 3)
    lines.each { |line|
      puts line
    }
  end

  def _separator(char = "-")
    puts char * 83
  end
end
