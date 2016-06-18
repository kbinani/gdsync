# coding: utf-8
# frozen_string_literal: true

require 'google_drive'
require_relative 'file_system'
require_relative 'file_system/google_drive_file_system'
require_relative 'file_system/local_file_system'
require_relative 'option'

module GDSync
  class Sync
    GOOGLE_DRIVE_SCHEMA = 'googledrive://'

    def initialize(src_dir, dest_dir, option)
      if Gem.win_platform?
        # "OpenSSL::X509::DEFAULT_CERT_FILE" may point to invalid location,
        # typically depending on who build the RubyInstaller. (ex. "C:/Users/(someone)/Projects/knap-build/...")
        # So we have to set correct *.pem file path. Fortunately, 'google-api-client' provides valid 'cacerts.pem' file.
        cert_path = ::File.join(::Gem.loaded_specs['google-api-client'].full_gem_path, 'lib', 'cacerts.pem')
        ENV['SSL_CERT_FILE'] = cert_path
      end

      @session = ::GoogleDrive.saved_session('config.json')
      @googledrive_fs = GoogleDriveFileSystem.new(@session)
      @local_fs = LocalFileSystem.new

      @src = _lookup_dir(src_dir)
      @option = option

      if src_dir.end_with?('/')
        @dest = _lookup_dir(dest_dir, true)
      else
        @dest = _lookup_dir(::File.join(dest_dir, ::File.basename(src_dir)), true)
      end
    end

    def run
      _transfer_directory_contents_recursive(@src, @dest, @option)
    end

    private

    def _lookup_dir(dir, create_if_not_exists = false)
      if dir.start_with?(GOOGLE_DRIVE_SCHEMA)
        if dir === GOOGLE_DRIVE_SCHEMA
          return GoogleDriveFileSystem::Dir.new(@googledrive_fs, @session.root_collection, GOOGLE_DRIVE_SCHEMA)
        end

        path_elements = dir.split(GOOGLE_DRIVE_SCHEMA)[1].split('/')
        collection = @session.root_collection
        for path_element in path_elements do
          child = collection.subcollection_by_title(path_element)
          if child.explicitly_trashed
            child = nil
          end
          if child.nil?
            if create_if_not_exists
              child = collection.create_subcollection(path_element)
              if child.nil?
                raise "Error: cannot create '#{path_element}' directory"
              end
            else
              raise 'Error: cannot find destination'
            end
          end
          collection = child
        end

        return GoogleDriveFileSystem::Dir.new(@googledrive_fs, collection, dir)
      else
        if create_if_not_exists and !::File.exist?(dir)
          ::FileUtils.mkdir_p(dir)
        end
        unless ::File.directory?(dir)
          raise "'#{dir}' is not a directory"
        end
        LocalFileSystem::Dir.new(@local_fs, dir)
      end
    end

    # @param src [AbstractFile]
    # @param  dest_dir [AbstractDir]
    # @param option [Option]
    def _create_new_file(src, dest_dir, option)
      created = nil

      if dest_dir.fs.instance_of?(src.fs.class)
        # copy file between same filesystem.
        created = src.copy_to(dest_dir)
      elsif src.fs.can_create_io_stream?
        # typically Local to Remote copy.
        created = dest_dir.create_file_with_read_io!(src.create_read_io, src.title, src.mtime, src.birthtime)
      elsif dest_dir.fs.can_create_io_stream?
        # typically Remote to Local copy.
        created, io = dest_dir.create_write_io!(src.title)
        src.write_to(io)
      else
        option.error('filesystem does not provide any file copy function')
      end

      created
    end

    def _transfer_directory_contents_recursive(src_dir, dest_dir, option)
      # list existing dirs/files in the 'dest_dir'.
      existing_dirs = []
      existing_files = []
      dest_dir.entries { |entry|
        if entry.is_dir?
          existing_dirs << entry
        else
          existing_files << entry
        end
      }

      src_dir.entries { |src|
        if src.is_dir?
          # search dir in 'dest_dir' with same title.
          dir = existing_dirs.select { |_|
            _.title == src.title
          }.first

          if dir.nil?
            # dir not found.
            dir = dest_dir.create_dir!(src.title)
            if dir.nil?
              option.error("cannot create subdirectory '#{src.path}'")
            else
              option.log_created(dir)
            end
          else
            existing_dirs.delete_if { |_|
              _.title == src.title
            }
          end

          unless dir.nil?
            _transfer_directory_contents_recursive(src, dir, option)
          end
        else
          # search file in 'dest_dir' with same title.
          file = existing_files.select { |_|
            _.title == src.title
          }.first

          if file.nil?
            # file does not exist. so, create new file.
            created = _create_new_file(src, dest_dir, option)

            if created.nil?
              option.error("cannot create file '#{::File.join(dest_dir.path, src.title)}'")
            else
              option.log_created(created)
            end
          else
            # file already exists.
            updated = nil

            unless option.should_update?(src, file)
              option.log_skip(file)
              next
            end

            if src.fs.can_create_io_stream?
              updated = file.update!(src.create_read_io, src.mtime)
            else
              file.delete!
              updated = _create_new_file(src, dest_dir, option)
            end

            if updated.nil?
              option.error("cannot update file '#{file.path}'")
            else
              option.log_updated(updated)
            end
          end
        end
      }

      if option.delete?
        existing_dirs.each { |dir|
          dir.delete!
          option.log_deleted(dir)
        }
        existing_files.each { |file|
          file.delete!
          option.log_deleted(file)
        }
      else
        existing_dirs.each { |dir|
          option.log_extraneous(dir)
        }
        existing_files.each { |file|
          option.log_extraneous(file)
        }
      end
    end
  end
end
