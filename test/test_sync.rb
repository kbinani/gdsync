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
    rsync_fixtures = File.join(workdir, 'rsync_fixtures', "fixtures#{with_trailing_slash ? '/' : ''}")
    FileUtils.mkdir_p(rsync_fixtures)
    _rsync('test/fixtures/', rsync_fixtures, ['-a'])

    gdsync_fixtures = File.join(workdir, 'gdsync_fixtures', "fixtures#{with_trailing_slash ? '/' : ''}")
    FileUtils.mkdir_p(gdsync_fixtures)
    _rsync('test/fixtures/', gdsync_fixtures, ['-a'])

    # Run rsync(1) to create *expected* directory structure.
    rsync_dest = File.join(workdir, 'rsync_dest')
    Dir.mkdir(rsync_dest)
    _rsync(rsync_fixtures, rsync_dest, rsync_options)

    # Create target directory.
    gdsync_dest = File.join(workdir, 'gdsync_dest')
    Dir.mkdir(gdsync_dest)

    # Print what options are being tested.
    prefix = "#{workdir}/"
    cmd = "rsync #{rsync_options.join(' ')} #{gdsync_fixtures.split(prefix)[1]} #{gdsync_dest.split(prefix)[1]}"
    puts cmd if VERBOSE

    # Run GDSync::Sync#run
    assert_nothing_raised do
      sync = GDSync::Sync.new([gdsync_fixtures], gdsync_dest, opt)
      sync.run

      if VERBOSE
        _separator
        puts "RSYNC_SRC(after#1):"
        _tree(rsync_fixtures)
        puts "RSYNC_DEST(after#1):"
        _tree(rsync_dest)
        puts "GDSYNC_SRC(after#1):"
        _tree(gdsync_fixtures)
        puts "GDSYNC_DEST(after#1):"
        _tree(gdsync_dest)
      end
    end

    # Compare directory structure between 'sync.run'ed dir and 'rsync'ed dir.
    _assert_dir_tree_equals(rsync_dest, gdsync_dest, assert_mtime, assert_checksum)
    _assert_dir_tree_equals(rsync_fixtures, gdsync_fixtures, assert_mtime, assert_checksum)

    # Modify 'fixtures'.
    [rsync_fixtures, gdsync_fixtures].each { |d|
      FileUtils.rm_rf(File.join(d, 'delete_local'))
      FileUtils.rm_rf(File.join(d, 'delete_local_file.txt'))

      edited_local_file = File.join(d, 'sub', 'edited_local_file.txt')
      if File.exist?(edited_local_file)
        open(edited_local_file, 'wb') { |f|
          f << 'a'
        }
      end

      edited_but_same_mtime_local_file = File.join(d, 'sub', 'edited_but_same_mtime_local_file.txt')
      if File.exist?(edited_but_same_mtime_local_file)
        mtime = File.mtime(edited_but_same_mtime_local_file)
        open(edited_but_same_mtime_local_file, 'wb') { |f|
          f << 'c'
        }
        File.utime(mtime, mtime, edited_but_same_mtime_local_file)
      end

      edited_but_same_mtime_and_same_size_local_file = File.join(d, 'sub', 'edited_but_same_mtime_and_same_size_local_file.txt')
      if File.exist?(edited_but_same_mtime_and_same_size_local_file)
        mtime = File.mtime(edited_but_same_mtime_and_same_size_local_file)
        open(edited_but_same_mtime_local_file, 'wb') { |f|
          f.write('A')
        }
        File.utime(mtime, mtime, edited_but_same_mtime_and_same_size_local_file)
      end
    }

    # Modify 'dest' and 'expected'
    mid = with_trailing_slash ? '' : '/fixtures'
    [rsync_dest, gdsync_dest].each { |d|
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
    _rsync(rsync_fixtures, rsync_dest, rsync_options)

    # Second run GDSync::Sync#run
    assert_nothing_raised do
      sync = GDSync::Sync.new([gdsync_fixtures], gdsync_dest, opt)
      sync.run

      if VERBOSE
        _separator
        puts "RSYNC_SRC(after#2):"
        _tree(rsync_fixtures)
        puts "RSYNC_DEST(after#2):"
        _tree(rsync_dest)
        puts "GDSYNC_SRC(after#2):"
        _tree(gdsync_fixtures)
        puts "GDSYNC_DEST(after#2):"
        _tree(gdsync_dest)
      end
    end

    # Second compare
    _assert_dir_tree_equals(rsync_dest, gdsync_dest, assert_mtime, assert_checksum)
    _assert_dir_tree_equals(rsync_fixtures, gdsync_fixtures, assert_mtime, assert_checksum)
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
        assert_true((File.mtime(epath).to_i - File.mtime(apath).to_i).abs <= 1) if assert_mtime

        if assert_checksum
          expected_checksum = ::Digest::MD5.file(epath).to_s
          actual_checksum = ::Digest::MD5.file(apath).to_s
          assert_equal(expected_checksum, actual_checksum, "expected #{expected_checksum} (#{epath}) for #{actual_checksum} (#{apath})")
        end
      end
    end
  end

  def _rsync(src, dest, options)
    cmd = "rsync #{options.join(' ')} #{src} #{dest} >/dev/null"
    raise "#{cmd} failed" unless system(cmd)
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
