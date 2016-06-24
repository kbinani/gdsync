# coding: utf-8
# frozen_string_literal: true

require_relative 'test_helper.rb'
require 'test/unit'
require 'tmpdir'
require 'pathname'
require_relative '../lib/sync.rb'
require_relative '../lib/option.rb'

class TestSync < ::Test::Unit::TestCase
  OPTIONS = GDSync::Option::SUPPORTED_OPTIONS

  def setup
    temp_dir_root = Dir.tmpdir
    if Gem.win_platform?
      cwd = Dir.pwd
      unless cwd[0] == temp_dir_root[0] # cwd and tmpdir are located on different drives.
        # Use custom temporary directory.
        # Reasons:
        # 1. MSYS's rsync does not support directory with drive letter (ex. C:\Path\To\Somewhere).
        # 2. If Dir.pwd and Dir.tmpdir are in same drive, drive letter issue can be prevented by using relative paths.
        # 3. If Dir.pwd and Dir.tmpdir are NOT in same drive, we can apply 'relative path' workaround
        #    by using custom tmpdir on the same drive to Dir.pwd,
        temp_dir_root = File.join(cwd, 'tmp')
        Dir.mkdir(temp_dir_root) unless File.directory?(temp_dir_root)
      end
    end
    @temp_dir = File.join(temp_dir_root, 'gdsync_sync_test')
    Dir.mkdir(@temp_dir) unless File.directory?(@temp_dir)
  end

  def teardown
    _rm_rf(@temp_dir)
  end

  data do
    options = if Gem.win_platform?
                GDSync::Option::SUPPORTED_OPTIONS.select do |option|
                  # MSYS's rsync frequently reports 'Permission Denied(13)' errors when '--remove-source-files' option is set.
                  option != '--remove-source-files'
                end
              else
                GDSync::Option::SUPPORTED_OPTIONS
              end

    data_list = {}
    (0..options.size).each do |num_options|
      options.combination(num_options).each do |rsync_options|
        key = rsync_options.join(' ')
        data_list[key] = rsync_options
      end
    end
    data_list
  end
  def test_run(data)
    rsync_options = data
    _run(rsync_options)
  end

  private

  VERBOSE = false

  def _run(rsync_options)
    workdir = Dir.mktmpdir('d', @temp_dir)
    _case(rsync_options, workdir, false)
    _rm_rf(workdir)

    workdir = Dir.mktmpdir('d', @temp_dir)
    _case(rsync_options, workdir, true)
    _rm_rf(workdir)
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

    _separator('=') if VERBOSE

    assert_mtime = rsync_options.include?('--times')
    assert_checksum = rsync_options.include?('--checksum')

    # Create copy of 'test/fixtures' directory.
    # The contents in it will be edited for testing purpouse (this is the reason why we create a copy of it).
    rsync_fixtures = File.join(workdir, 'rsync_fixtures', "fixtures#{with_trailing_slash ? '/' : ''}")
    FileUtils.mkdir_p(rsync_fixtures)
    _rsync('test/fixtures/', rsync_fixtures, ['-a'])
    _remove_readonly_attribute(rsync_fixtures)

    gdsync_fixtures = File.join(workdir, 'gdsync_fixtures', "fixtures#{with_trailing_slash ? '/' : ''}")
    FileUtils.mkdir_p(gdsync_fixtures)
    _rsync('test/fixtures/', gdsync_fixtures, ['-a'])
    _remove_readonly_attribute(gdsync_fixtures)

    # Run rsync(1) to create *expected* directory structure.
    rsync_dest = File.join(workdir, 'rsync_dest')
    Dir.mkdir(rsync_dest)
    _rsync(rsync_fixtures, rsync_dest, rsync_options)
    _remove_readonly_attribute(rsync_fixtures)
    _remove_readonly_attribute(rsync_dest)

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
    end

    if VERBOSE
      _separator
      puts 'RSYNC_SRC(after#1):'
      _tree(rsync_fixtures)
      puts 'GDSYNC_SRC(after#1):'
      _tree(gdsync_fixtures)
      puts 'RSYNC_DEST(after#1):'
      _tree(rsync_dest)
      puts 'GDSYNC_DEST(after#1):'
      _tree(gdsync_dest)
    end

    # Compare directory structure between 'sync.run'ed dir and 'rsync'ed dir.
    _assert_dir_tree_equals(rsync_dest, gdsync_dest, assert_mtime, assert_checksum, 1.0)
    _assert_dir_tree_equals(rsync_fixtures, gdsync_fixtures, assert_mtime, assert_checksum, 1.0)

    # Modify 'fixtures'.
    updating_src_start_datetime = DateTime.now
    [rsync_fixtures, gdsync_fixtures].each do |d|
      _rm_rf(File.join(d, 'delete_local'))
      _rm_rf(File.join(d, 'delete_local_file.txt'))

      edited_local_file = File.join(d, 'sub', 'edited_local_file.txt')
      if File.exist?(edited_local_file)
        open(edited_local_file, 'wb') do |f|
          f << 'a'
        end
      end

      edited_but_same_mtime_local_file = File.join(d, 'sub', 'edited_but_same_mtime_local_file.txt')
      if File.exist?(edited_but_same_mtime_local_file)
        mtime = File.mtime(edited_but_same_mtime_local_file)
        open(edited_but_same_mtime_local_file, 'wb') do |f|
          f << 'c'
        end
        _utime(mtime, edited_but_same_mtime_local_file)
      end

      edited_but_same_mtime_and_same_size_local_file = File.join(d, 'sub', 'edited_but_same_mtime_and_same_size_local_file.txt')
      if File.exist?(edited_but_same_mtime_and_same_size_local_file)
        mtime = File.mtime(edited_but_same_mtime_and_same_size_local_file)
        open(edited_but_same_mtime_local_file, 'wb') do |f|
          f.write('A')
        end
        _utime(mtime, edited_but_same_mtime_and_same_size_local_file)
      end
    end
    elapsed_seconds_updating_src = (DateTime.now - updating_src_start_datetime).to_f * 24 * 60 * 60

    # Modify 'dest' and 'expected'
    mid = with_trailing_slash ? '' : '/fixtures'
    updating_dest_start_datetime = DateTime.now
    [rsync_dest, gdsync_dest].each do |d|
      _rm_rf(File.join("#{d}#{mid}", 'delete_remote'))
      _rm_rf(File.join("#{d}#{mid}", 'delete_remote_file.txt'))

      edited_remote_file = File.join("#{d}#{mid}", 'sub', 'edited_remote_file.txt')
      if File.exist?(edited_remote_file)
        open(edited_remote_file, 'wb') do |f|
          f << 'b'
        end
      end

      edited_but_same_mtime_remote_file = File.join("#{d}#{mid}", 'sub', 'edited_but_same_mtime_remote_file.txt')
      if File.exist?(edited_but_same_mtime_remote_file)
        mtime = File.mtime(edited_but_same_mtime_remote_file)
        open(edited_but_same_mtime_remote_file, 'wb') do |f|
          f << 'd'
        end
        _utime(mtime, edited_but_same_mtime_remote_file)
      end

      edited_but_same_mtime_and_same_size_remote_file = File.join("#{d}#{mid}", 'sub', 'edited_but_same_mtime_and_same_size_remote_file.txt')
      if File.exist?(edited_but_same_mtime_and_same_size_remote_file)
        mtime = File.mtime(edited_but_same_mtime_and_same_size_remote_file)
        open(edited_but_same_mtime_and_same_size_remote_file, 'wb') do |f|
          f.write('A')
        end
        _utime(mtime, edited_but_same_mtime_and_same_size_remote_file)
      end
    end
    elapsed_seconds_updating_dest = (DateTime.now - updating_dest_start_datetime).to_f * 24 * 60 * 60

    # Second run rsync
    _rsync(rsync_fixtures, rsync_dest, rsync_options)
    _remove_readonly_attribute(rsync_fixtures)
    _remove_readonly_attribute(rsync_dest)

    # Second run GDSync::Sync#run
    assert_nothing_raised do
      sync = GDSync::Sync.new([gdsync_fixtures], gdsync_dest, opt)
      sync.run
    end

    if VERBOSE
      _separator
      puts 'RSYNC_SRC(after#2):'
      _tree(rsync_fixtures)
      puts 'GDSYNC_SRC(after#2):'
      _tree(gdsync_fixtures)
      puts 'RSYNC_DEST(after#2):'
      _tree(rsync_dest)
      puts 'GDSYNC_DEST(after#2):'
      _tree(gdsync_dest)
    end

    # Second compare
    _assert_dir_tree_equals(rsync_dest, gdsync_dest, assert_mtime, assert_checksum, (elapsed_seconds_updating_dest + 1).ceil)
    _assert_dir_tree_equals(rsync_fixtures, gdsync_fixtures, assert_mtime, assert_checksum, (elapsed_seconds_updating_src + 1).ceil)
  end

  def _assert_dir_tree_equals(expected, actual, assert_mtime, assert_checksum, mtime_tolerance_second)
    e = Dir.entries(expected, encoding: Encoding::UTF_8).select { |name| name != '.' && name != '..' }.sort
    a = Dir.entries(actual, encoding: Encoding::UTF_8).select { |name| name != '.' && name != '..' }.sort
    assert_equal(e, a)

    (0...e.size).each do |i|
      epath = File.join(expected, e[i])
      apath = File.join(actual, a[i])

      assert_equal(e[i], a[i])
      if File.directory?(epath)
        assert_true(File.directory?(apath))
        _assert_dir_tree_equals(epath, apath, assert_mtime, assert_checksum, mtime_tolerance_second)
      else
        assert_false(File.directory?(apath))
        assert_true((File.mtime(epath).to_i - File.mtime(apath).to_i).abs <= mtime_tolerance_second, "expected #{File.mtime(epath)} (#{epath}) for #{File.mtime(apath)} (#{apath})") if assert_mtime

        if assert_checksum
          expected_checksum = ::Digest::MD5.file(epath).to_s
          actual_checksum = ::Digest::MD5.file(apath).to_s
          assert_equal(expected_checksum, actual_checksum, "expected #{expected_checksum} (#{epath}) for #{actual_checksum} (#{apath})")
        end
      end
    end
  end

  def _rsync(src, dest, options)
    cwd = Dir.pwd

    # GDSync::Sync.#run behaves as if '--inplace' option is set.
    # And, if --inplace is not set, MSYS's rsync sometimes report permission errors like:
    #   sync: rename "/c/Users/name/AppData/Local/Temp/gdsync_sync_test/d20160623-1104-vut8fo/rsync_dest/fixtures/sub/.edited_remote_file.txt.014356" -> "fixtures/sub/edited_remote_file.txt": Permission denied (13)
    options << '--inplace'

    relative_dest_path = Pathname.new(File.absolute_path(dest)).relative_path_from(Pathname.new(cwd))
    relative_src_path = Pathname.new(File.absolute_path(src)).relative_path_from(Pathname.new(cwd))

    relative_src_path = "#{relative_src_path}/" if src.end_with?('/')

    nul_device = Gem.win_platform? ? 'nul' : '/dev/null'

    cmd = "rsync #{options.join(' ')} \"#{relative_src_path}\" \"#{relative_dest_path}\" > #{nul_device}"
    raise "#{cmd} failed" unless system(cmd)
  end

  def _tree(dir)
    opt = Gem.win_platform? ? '/F' : ''
    lines = `tree #{opt} #{dir}`.lines
    lines = if Gem.win_platform?
              lines.slice(3, lines.size)
            else
              lines.slice(1, lines.size - 3)
            end
    lines.each do |line|
      puts line
    end
  end

  def _separator(char = '-')
    puts char * 83
  end

  def _rm_rf(path)
    # Retry till the path did actually disappear:
    # this is a workaround on Windows environment.
    while File.exist?(path)
      begin
        FileUtils.remove_entry_secure(path)
      rescue
        next
      end
    end
  end

  # Recursively remove 'readonly' attribute.
  def _remove_readonly_attribute(path)
    return unless Gem.win_platform?

    # Readonly attributes will be set by rsync.
    # This will cause permission errors when editing fixture files.
    # So we have to remove them after running rsync.

    if File.directory?(path)
      File.chmod(0755, path)

      wide_path = path.wincode
      attributes = ::Windows::File::Functions::GetFileAttributesW(wide_path)
      attributes &= ~::Windows::File::Constants::FILE_ATTRIBUTE_READONLY
      raise 'Error' unless ::Windows::File::Functions::SetFileAttributesW(wide_path, attributes)

      Dir.entries(path, encoding: Encoding::UTF_8)
         .select { |e| e != '.' && e != '..' }
         .each do |e|
           p = File.join(path, e)
           _remove_readonly_attribute(p)
         end
    else
      f = File.new(path)
      f.readonly = false
      File.chmod(0644, path)
    end
  end

  def _utime(mtime, path)
    loop do
      begin
        File.utime(mtime, mtime, path)
        break
      rescue
        next
      end
    end
  end
end
