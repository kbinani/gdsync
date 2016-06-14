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
          @md5 = Digest::MD5.file(@path).to_s
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

      def copy_to(dest_dir)
        file, io = dest_dir.create_write_io!(title)
        write_to(io)
        io.close

        file
      end

      def delete!
        ::File.delete(@path)
      end

      def path
        @path
      end

      def birthtime
        f = ::File.new(@path)
        f.birthtime.to_datetime
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
        entries = ::Dir.entries(@path)
        entries.select { |e|
          e != '.' and e != '..'
        }.map { |e|
          e.encode(Encoding::UTF_8)
        }.each { |e|
          path = ::File.join(@path, e)

          if ::Gem.win_platform? and ::File.hidden?(path)
            next
          end

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

      def create_dir!(title)
        newpath = ::File.join(@path, title)
        ::Dir.mkdir(newpath)
        Dir.new(@fs, newpath)
      end

      def create_file_with_read_io!(io, title, mtime, birthtime)
        newfile = ::File.join(@path, title)
        open(newfile, 'wb') { |f|
          IO.copy_stream(io, f)
        }
        ::File.utime(mtime, mtime, newfile)
        File.new(@fs, newfile)
      end

      def create_write_io!(title)
        newfile = ::File.join(@path, title)
        io = open(newfile, 'wb')
        file = File.new(@fs, newfile)
        return file, io
      end

      def delete!
        FileUtils.rm_r(@path)
      end

      def path
        @path
      end
    end

    def can_create_io_stream?
      true
    end
  end
end
