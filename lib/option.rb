# coding: utf-8
# frozen_string_literal: true

module GDSync
  class Option
    def initialize(options)
      @verbose = options[:verbose] || true
      @delete = options[:delete] || false
      @checksum = options[:checksum] || false
      @dry_run = options[:dry_run] || false
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

    def should_update?(src_file, dest_file)
      if @checksum
        src_file.md5 != dest_file.md5
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
  end
end
