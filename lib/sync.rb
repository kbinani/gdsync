# coding: utf-8
# frozen_string_literal: true

require 'google_drive'
require_relative 'file_system'
require_relative 'file_system/google_drive_file_system'
require_relative 'file_system/local_file_system'
require_relative 'file_system/dry_run'
require_relative 'option'

module GDSync
  class Sync
    # @param src [Array]
    # @param dest [String]
    # @param option [Option]
    def initialize(src, dest_dir, option)
      @googledrive_session = nil
      @googledrive_fs = nil
      @local_fs = nil

      @src = src
      @dest = dest_dir
      @option = option
    end

    def local_fs
      if @local_fs.nil?
        @local_fs = LocalFileSystem.new
      end
      @local_fs
    end

    def dryrun_fs
      if @dryrun_fs.nil?
        @dryrun_fs = DryRunFileSystem.new
      end
      @dryrun_fs
    end

    def googledrive_fs
      if @googledrive_fs.nil?
        @googledrive_fs = GoogleDriveFileSystem.new(googledrive_session)
      end
      @googledrive_fs
    end

    def googledrive_session
      if @googledrive_session.nil?
        if Gem.win_platform?
          # "OpenSSL::X509::DEFAULT_CERT_FILE" may point to invalid location,
          # typically depending on who build the RubyInstaller. (ex. "C:/Users/(someone)/Projects/knap-build/...")
          # So we have to set correct *.pem file path. Fortunately, 'google-api-client' provides valid 'cacerts.pem' file.
          cert_path = ::File.join(::Gem.loaded_specs['google-api-client'].full_gem_path, 'lib', 'cacerts.pem')
          ENV['SSL_CERT_FILE'] = cert_path
        end
        @googledrive_session = ::GoogleDrive.saved_session('config.json')
      end
      @googledrive_session
    end

    def run
      @src.each { |_|
        src = _lookup_file_or_dir(_)

        if src.nil?
          raise "file or directory '#{_}' not found"
        else
          if src.is_dir?
            if @option.recursive? || @option.dirs?
              dest = _lookup_dir(@dest)
              
              if !dest.nil? && !src.path.end_with?('/')
                sub = _lookup_dir(::File.join(@dest, src.title))
                if sub.nil? && !@option.existing?
                  sub = _create_new_dir(src.title, dest)
                  raise "cannot create directory '#{::File.join(@dest, src.title)}'" if sub.nil?
                end
                dest = sub
              end

              if dest.nil?
                raise "cannot find dest directory" unless @option.existing?
              else
                _transfer_directory_contents_recursive(src, dest) unless @option.dirs? && !src.path.end_with?('/')
              end
            else
              @option.log_skip(src)
            end
          else
            dest = _lookup_dir(@dest)
            if dest.nil?
              raise "cannot find dest directory"
            else
              dest_existing_file = dest.fs.find(::File.join(dest.path, src.title))
              _transfer_file(src, dest, dest_existing_file) 
            end
          end
        end
      }
    end

    private

    def _lookup_file_or_dir(path)
      if path.start_with?(GoogleDriveFileSystem::URL_SCHEMA)
        googledrive_fs.find(path)
      else
        local_fs.find(path)
      end
    end

    # @param dir [String]
    def _lookup_dir(dir)
      d = _lookup_file_or_dir(dir)
      return nil if d.nil?
      return nil unless d.is_dir?
      d
    end

    # @param src [AbstractFile]
    # @param  dest_dir [AbstractDir]
    # @return [AbstractFile]
    def _create_new_file(src, dest_dir)
      created = nil
      now = DateTime.now
      mtime = @option.preserve_time? ? src.mtime : now
      birthtime = @option.preserve_time? ? src.birthtime : now

      if @option.dry_run?
        created = DryRunFileSystem::File.new(dryrun_fs, ::File.join(dest_dir.path, src.title))
      elsif dest_dir.fs.instance_of?(src.fs.class)
        # copy file between same filesystem.
        created = src.copy_to(dest_dir, birthtime, mtime)
      elsif src.fs.can_create_io_stream?
        # typically Local to Remote copy.
        created = dest_dir.create_file_with_read_io!(src.create_read_io, src.title, mtime, birthtime)
      elsif dest_dir.fs.can_create_io_stream?
        # typically Remote to Local copy.
        created, io = dest_dir.create_write_io!(src.title)
        src.write_to(io)
      else
        @option.error('filesystem does not provide any file copy function')
      end

      created
    end

    # @param title [String]
    # @param dest_dir [AbstractDir]
    # @return [AbstractDir]
    def _create_new_dir(title, dest_dir)
      dir = nil

      if @option.dry_run?
        dir = DryRunFileSystem::Dir.new(dryrun_fs, ::File.join(dest_dir.path, title))
      else
        dir = dest_dir.create_dir!(title)
      end

      if dir.nil?
        @option.error("cannot create subdirectory '#{::File.join(dest_dir.path, title)}'")
      else
        @option.log_created(dir)
      end

      dir
    end

    def _transfer_file(src_file, dest_dir, dest_existing_file)
      mtime = @option.preserve_time? ? src_file.mtime : DateTime.now

      size = src_file.size
      return if size > @option.max_size
      return if size < @option.min_size

      if dest_existing_file.nil?
        unless @option.existing?
          # file does not exist. so, create new file.
          created = _create_new_file(src_file, dest_dir)

          if created.nil?
            @option.error("cannot create file '#{::File.join(dest_dir.path, src_file.title)}'")
          else
            @option.log_created(created)
          end
        end
      else
        unless @option.ignore_existing?
          # file already exists.
          updated = nil

          unless @option.should_update?(src_file, dest_existing_file)
            @option.log_skip(dest_existing_file)
            return
          end

          if @option.dry_run?
            updated = DryRunFileSystem::File.new(dryrun_fs, dest_existing_file.path)
          elsif src_file.fs.can_create_io_stream?
            updated = dest_existing_file.update!(src_file.create_read_io, mtime)
          else
            dest_existing_file.delete!
            updated = _create_new_file(src_file, dest_dir)
          end

          if updated.nil?
            @option.error("cannot update file '#{dest_existing_file.path}'")
          else
            @option.log_updated(updated)
          end
        end
      end
    end

    def _transfer_directory_contents_recursive(src_dir, dest_dir)
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

          existing_dirs.delete_if { |_| _.title == src.title }

          if !@option.recursive? && !@option.dirs?
            @option.log_skip(src)
            next
          end

          if dir.nil? && !@option.existing?
            dir = _create_new_dir(src.title, dest_dir)
          end

          if !dir.nil? && !@option.dirs?
            _transfer_directory_contents_recursive(src, dir)
          end
        else
          # search file in 'dest_dir' with same title.
          file = existing_files.select { |_|
            _.title == src.title
          }.first

          existing_files.delete_if { |_| _.title == src.title }

          _transfer_file(src, dest_dir, file)

          if @option.remove_source_files? && !@option.existing?
            src.delete! unless @option.dry_run?
            @option.log_deleted(src)
          end
        end
      }

      if @option.delete?
        existing_dirs.each { |dir|
          dir.delete! unless @option.dry_run?
          @option.log_deleted(dir)
        }
        existing_files.each { |file|
          file.delete! unless @option.dry_run?
          @option.log_deleted(file)
        }
      else
        existing_dirs.each { |dir|
          @option.log_extraneous(dir)
        }
        existing_files.each { |file|
          @option.log_extraneous(file)
        }
      end
    end
  end
end
