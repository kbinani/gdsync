# coding: utf-8
# frozen_string_literal: true

module GDSync
  class DryRunFileSystem < FileSystem
    class File < AbstractFile
      attr_reader :fs, :path

      def initialize(_fs, _path)
        @fs = _fs
        @path = _path
      end

      def title
        ::File.basename(path)
      end

      def size
        0
      end

      def mtime
        ::DateTime.now
      end

      def birthtime
        ::DateTime.now
      end

      def md5
        ::Digest::MD5.hexdigest('')
      end

      def create_read_io
        raise NotSupportedError.new
      end

      def write_to(_write_io)
      end

      def update!(_read_io, _mtime)
        self
      end

      def copy_to(_dest_dir)
        File.new(::File.join(_dest_dir.path, title))
      end

      def delete!
      end
    end

    class Dir < AbstractDir
      attr_reader :fs
      attr_reader :path

      def initialize(_fs, _path)
        @fs = _fs
        @path = _path
      end

      def title
        ::File.basename(path)
      end

      def entries(&block)
      end

      def create_dir!(_title)
        Dir.new(fs, ::File.join(path, _title))
      end

      def create_file_with_read_io!(_io, _title, _mtime, _birthtime)
        File.new(fs, ::File.join(path, _title))
      end

      def create_write_io!(_title)
        raise NotSupportedError.new
      end

      def delete!
      end
    end

    def can_create_io_stream?
      false
    end
  end
end
