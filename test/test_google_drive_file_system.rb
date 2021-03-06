# coding: utf-8
# frozen_string_literal: true

require_relative 'test_helper.rb'
require 'test/unit'
require_relative '../lib/file_system.rb'
require_relative '../lib/file_system/google_drive_file_system.rb'

# Remote files are prepared for Google account "gdsync.github@gmail.com".
class TestGoogleDriveFileSystem < ::Test::Unit::TestCase
  def setup
    config_path = ::File.join(::File.dirname(__FILE__), '..', 'config.json')
    @fs = GDSync::GoogleDriveFileSystem.new(config_path)
  end

  def test_find
    found_dir = @fs.find('googledrive://gdsync/test/google_drive_file_system_test')
    assert_not_nil(found_dir)
    assert_equal('googledrive://gdsync/test/google_drive_file_system_test', found_dir.path)
    assert_equal('google_drive_file_system_test', found_dir.title)
    assert_true(found_dir.is_a?(GDSync::GoogleDriveFileSystem::Dir))

    found_file = @fs.find('googledrive://gdsync/test/google_drive_file_system_test/a.txt')
    assert_not_nil(found_file)
    assert_equal('googledrive://gdsync/test/google_drive_file_system_test/a.txt', found_file.path)
    assert_equal('a.txt', found_file.title)
    assert_true(found_file.is_a?(GDSync::GoogleDriveFileSystem::File))
    assert_equal(DateTime.parse('2016-06-21T03:48:58+00:00').to_time.to_i, found_file.mtime.to_time.to_i)
    assert_equal(DateTime.parse('2016-06-21T03:48:58+00:00').to_time.to_i, found_file.birthtime.to_time.to_i)
    assert_equal('e707077c501af6da965b1e23ab13cf07', found_file.md5)

    assert_nil(@fs.find('/gdsync/test/google_drive_file_system_test'))
    assert_nil(@fs.find('googledrive://gdsync/test/this_file_does_not_exist.txt'))
    assert_nil(@fs.find('googledrive://gdsync/this_directory_does_not_exist'))

    found_root = @fs.find('googledrive://')
    assert_not_nil(found_root)

    found_dir_trailing_slash = @fs.find('googledrive://gdsync/test/google_drive_file_system_test/')
    assert_not_nil(found_dir_trailing_slash)
    assert_equal('googledrive://gdsync/test/google_drive_file_system_test/', found_dir_trailing_slash.path)
    assert_equal('google_drive_file_system_test', found_dir_trailing_slash.title)
  end

  def test_can_create_io_stream
    assert_false(@fs.can_create_io_stream?)
  end

  sub_test_case 'Dir' do
    def setup
      config_path = ::File.join(::File.dirname(__FILE__), '..', 'config.json')
      @fs = GDSync::GoogleDriveFileSystem.new(config_path)
      @dir = @fs.find('googledrive://gdsync/test').create_dir!('temporary')
      @test_dir = 'googledrive://gdsync/test/temporary'
      @dir = @fs.find(@test_dir)
      @work = @dir.create_dir!('tmp')
    end

    def teardown
      @dir.delete!
    end

    def test_title
      assert_equal('tmp', @work.title)
    end

    def test_path
      assert_equal(::File.join(@test_dir, 'tmp'), @work.path)
    end

    def test_create_and_delete_dir
      created = @work.create_dir!('foo')
      assert_not_nil(created)

      can_be_found = @fs.find(::File.join(@test_dir, 'tmp', 'foo'))
      assert_not_nil(can_be_found)

      created.delete!
      cannot_be_found = @fs.find(::File.join(@test_dir, 'tmp', 'foo'))
      assert_nil(cannot_be_found)
    end

    def test_id
      id = @dir.id
      assert_not_nil(id)
      assert_true(id.is_a?(String))
      assert_false(id.empty?)
    end

    def test_create_write_io
      assert_raise_kind_of(::GDSync::FileSystem::NotSupportedError) do
        @dir.create_write_io!('filename.txt')
      end
    end

    def test_entries
      dir = @fs.find('googledrive://gdsync/test/google_drive_file_system_test')
      entries = []
      dir.entries do |e|
        entries << e
      end
      assert_equal(4, entries.size)

      assert_true(entries[0].is_a?(::GDSync::GoogleDriveFileSystem::Dir))
      assert_equal('aaa', entries[0].title)

      assert_true(entries[1].is_a?(::GDSync::GoogleDriveFileSystem::Dir))
      assert_equal('sub', entries[1].title)

      assert_true(entries[2].is_a?(::GDSync::GoogleDriveFileSystem::File))
      assert_equal('a.txt', entries[2].title)

      assert_true(entries[3].is_a?(::GDSync::GoogleDriveFileSystem::File))
      assert_equal('b.txt', entries[3].title)
    end

    def test_create_file_with_read_io
      mtime = DateTime.now
      birthtime = mtime - 1
      created = nil
      open('test/test_google_drive_file_system.rb', 'rb') do |f|
        created = @work.create_file_with_read_io!(f, 'foo.rb', mtime, birthtime)
      end

      assert_not_nil(created)
      assert_equal(mtime.to_time.to_i, created.mtime.to_time.to_i)
      assert_equal(birthtime.to_time.to_i, created.birthtime.to_time.to_i)
      assert_equal('foo.rb', created.title)
      assert_equal(::File.join(@work.path, 'foo.rb'), created.path)

      expected_md5 = ::Digest::MD5.file('test/test_google_drive_file_system.rb').to_s
      assert_equal(expected_md5, created.md5)
    end

    def test_fs
      assert_equal(@fs.object_id, @dir.fs.object_id)
    end
  end

  sub_test_case 'File' do
    def setup
      config_path = ::File.join(::File.dirname(__FILE__), '..', 'config.json')
      @fs = GDSync::GoogleDriveFileSystem.new(config_path)
      @dir = @fs.find('googledrive://gdsync/test').create_dir!('temporary')
      @test_dir = 'googledrive://gdsync/test/temporary'
      @dir = @fs.find(@test_dir)
      @work = @dir.create_dir!('tmp')
      @a_txt = @fs.find('googledrive://gdsync/test/google_drive_file_system_test/a.txt')
    end

    def teardown
      @dir.delete!
    end

    def test_properties
      assert_equal('a.txt', @a_txt.title)
      assert_equal(44, @a_txt.size)
      assert_equal('e707077c501af6da965b1e23ab13cf07', @a_txt.md5)
      assert_equal(1_466_480_938, @a_txt.mtime.to_time.to_i)
      assert_equal(1_466_480_938, @a_txt.birthtime.to_time.to_i)
      assert_equal(@fs.object_id, @a_txt.fs.object_id)
      assert_equal('googledrive://gdsync/test/google_drive_file_system_test/a.txt', @a_txt.path)
    end

    def test_create_read_io
      assert_raise_kind_of(::GDSync::FileSystem::NotSupportedError) do
        @a_txt.create_read_io
      end
    end

    def test_write_to
      Dir.mktmpdir do |workdir|
        downloaded = File.join(workdir, 'downloaded.txt')
        open(downloaded, 'wb') do |file|
          @a_txt.write_to(file)
        end
        assert_true(File.exist?(downloaded))
        assert_equal(@a_txt.md5, Digest::MD5.file(downloaded).to_s)
      end
    end

    def test_copy_to
      mtime = DateTime.now - 1
      birthtime = DateTime.now - 2
      copied = @a_txt.copy_to(@work, birthtime, mtime)
      assert_not_nil(copied)
      assert_equal(@a_txt.title, copied.title)
      assert_equal(mtime.to_time.to_i, copied.mtime.to_time.to_i)

      # `birthtime' is automatically set by Google Drive.
      # We cannot specify them.
    end

    def test_create_update_delete
      Dir.mktmpdir do |workdir|
        # prepare a file to upload.
        upload_file = File.join(workdir, 'upload.txt')
        open(upload_file, 'wb') do |file|
          r = Random.new(DateTime.now.to_time.to_i)
          file.write(r.bytes(49))
        end
        upload_file_md5 = Digest::MD5.file(upload_file).to_s

        # create temporary update/delete target file.
        created = @a_txt.copy_to(@work, DateTime.now, DateTime.now)

        # update target file by uploading.
        before_md5 = created.md5
        assert_equal(@a_txt.md5, created.md5)
        mtime = DateTime.now - 1
        after_updated = nil
        open(upload_file, 'rb') do |file|
          after_updated = created.update!(file, mtime)
        end

        assert_not_nil(after_updated)
        assert_not_equal(before_md5, after_updated.md5)
        assert_equal(upload_file_md5, after_updated.md5)
        assert_equal(Digest::MD5.file(upload_file).to_s, after_updated.md5)
        assert_equal(mtime.to_time.to_i, after_updated.mtime.to_time.to_i)

        # delete
        path = created.path
        created.delete!
        not_found = @fs.find(path)
        assert_nil(not_found)
      end
    end
  end
end
