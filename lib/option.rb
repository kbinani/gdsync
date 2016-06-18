# coding: utf-8
# frozen_string_literal: true

module GDSync
  class Option
    SUPPORTED_OPTIONS = [
      '--checksum',
      '--recursive',
      '--times',
      '--dry-run',
      '--existing',
      '--ignore-existing',
      '--delete',
      '--ignore-times',
      '--size-only',
      '--update',
      '--dirs',
      '--remove-source-files',
    ].freeze

    def initialize(options)
      @verbose = options.include?('--verbose')
      @delete = options.include?('--delete')
      @checksum = options.include?('--checksum')
      @dry_run = options.include?('--dry-run')
      @size_only = options.include?('--size-only')
      @recursive = options.include?('--recursive')
      @preserve_time = options.include?('--times')
      @ignore_times = options.include?('--ignore-times')
      @existing = options.include?('--existing')
      @ignore_existing = options.include?('--ignore-existing')
      @update = options.include?('--update')
      @dirs = options.include?('--dirs')
      @remove_source_files = options.include?('--remove-source-files')

      archive = options.include?('--archive')
      if archive
        @recursive = true
        @preserve_time = true
      end

      _validate
    end

    def delete?
      @delete
    end

    def verbose?
      @verbose
    end

    def dry_run?
      @dry_run
    end

    def recursive?
      @recursive
    end

    def preserve_time?
      @preserve_time
    end

    def existing?
      @existing
    end

    def ignore_existing?
      @ignore_existing
    end

    def dirs?
      if @recursive
        false
      else
        @dirs
      end
    end

    def remove_source_files?
      @remove_source_files
    end

    def should_update?(src_file, dest_file)
      return false if @update && dest_file.mtime > src_file.mtime

      if @checksum
        src_file.md5 != dest_file.md5
      elsif @size_only
        src_file.size != dest_file.size
      elsif @ignore_times
        true
      else
        src_file.size != dest_file.size or dest_file.mtime < src_file.mtime
      end
    end

    def error(msg)
      puts "Error: #{msg}"
    end

    def log_updated(file)
      puts "#{file.path}#{file.is_dir? ? '/' : ''} (updated)" if @verbose
    end

    def log_created(file)
      puts "#{file.path}#{file.is_dir? ? '/' : ''} (created)" if @verbose
    end

    def log_deleted(file)
      puts "#{file.path}#{file.is_dir? ? '/' : ''} (deleted)" if @verbose
    end

    def log_extraneous(file)
      puts "#{file.path}#{file.is_dir? ? '/' : ''} (extraneous)" if @verbose
    end

    def log_skip(file)
      puts "#{file.path}#{file.is_dir? ? '/' : ''} (skip)" if @verbose
    end

    private

    def _validate
      # --delete does not work without -r or -d.
      raise '--delete does not work without -r.' if @delete && !@recursive
    end
  end
end
