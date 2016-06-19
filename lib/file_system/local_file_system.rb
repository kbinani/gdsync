# coding: utf-8
# frozen_string_literal: true

require 'digest/md5'

if Gem.win_platform?
  require 'win32/file/attributes'
end

module GDSync
  class LocalFileSystem < FileSystem
    class File < AbstractFile
      def initialize(fs, path)
        @fs = fs
        @path = path
        @md5 = nil
      end

      def title
        ::File.basename(@path)
      end

      def size
        ::File.size(@path)
      end

      def mtime
        ::File.mtime(@path).to_datetime
      end

      def md5
        if @md5.nil?
          @md5 = ::Digest::MD5.file(@path).to_s
        end

        @md5
      end

      def fs
        @fs
      end

      def create_read_io
        open(@path, 'rb')
      end

      def write_to(write_io)
        open(@path, 'rb') { |f|
          ::IO.copy_stream(f, write_io)
        }
      end

      def copy_to(_dest_dir, _birthtime, _mtime)
        file, io = _dest_dir.create_write_io!(title)
        write_to(io)
        io.close
        ::File.utime(_mtime.to_time, _mtime.to_time, file.path)

        file
      end

      def update!(read_io, _mtime)
        open(@path, 'wb') { |f|
          ::IO.copy_stream(read_io, f)
        }
        ::File.utime(_mtime.to_time, _mtime.to_time, @path)
      end

      def delete!
        ::File.delete(@path)
      end

      def path
        @path
      end

      def birthtime
        f = ::File.new(@path)
        begin
          f.birthtime.to_datetime
        rescue NotImplementedError => e
          f.mtime.to_datetime
        end
      end
    end

    class Dir < AbstractDir
      def initialize(fs, path)
        @fs = fs
        @path = path
      end

      def title
        ::File.basename(@path)
      end

      def entries(&block)
        entries = ::Dir.entries(@path, :encoding => ::Encoding::UTF_8)
        entries.select { |e|
          e != '.' and e != '..'
        }.each { |e|
          path = ::File.join(@path, e)

          next if ::Gem.win_platform? && ::File.hidden?(path)

          f = nil
          if ::File.directory?(path)
            f = Dir.new(@fs, path)
          else
            f = File.new(@fs, path)
          end
          block.call(f)
        }
      end

      def fs
        @fs
      end

      def create_dir!(_title)
        newpath = ::File.join(@path, _title)
        ::Dir.mkdir(newpath)
        Dir.new(@fs, newpath)
      end

      def create_file_with_read_io!(_io, _title, _mtime, _birthtime)
        newfile = ::File.join(@path, _title)
        open(newfile, 'wb') { |f|
          IO.copy_stream(_io, f)
        }
        ::File.utime(_mtime, _mtime, newfile)
        File.new(@fs, newfile)
      end

      def create_write_io!(_title)
        newfile = ::File.join(@path, _title)
        io = open(newfile, 'wb')
        file = File.new(@fs, newfile)
        return file, io
      end

      def delete!
        ::FileUtils.rm_r(@path)
      end

      def path
        @path
      end
    end

    def can_create_io_stream?
      true
    end

    def find(path)
      if ::File.exist?(path)
        if ::File.directory?(path)
          Dir.new(self, path)
        else
          File.new(self, path)
        end
      else
        nil
      end
    end
  end
end
