# coding: utf-8
# frozen_string_literal: true

module GDSync
  class FileSystem
    class NotSupportedError < RuntimeError
    end

    class AbstractFile
      def title
        raise 'abstract method "title" called'
      end

      def is_dir?
        false
      end

      def size
        raise 'abstract method "size" called'
      end

      def mtime
        raise 'abstract method "mtime" called'
      end

      def md5
        raise 'abstract method "md5" called'
      end

      def fs
        raise 'abstract method "fs" called'
      end

      # Creates IO object to read the file.
      # @raise NotSupportedError when 'create_read_io' operation is not supported by the filesystem.
      def create_read_io
        raise 'abstract method "create_read_io" called'
      end

      # Read this file and write to 'write_io' IO object.
      def write_to(write_io)
        raise 'abstract method "write_to" called'
      end

      # Copy file to 'dest_dir'. self and dest_dir must be same filesystem.
      # @pre self.fs == dest_dir.fs
      # @return  {AbstractFile}  AbstractFile object pointing to copied file.
      def copy_to(dest_dir)
        raise 'abstract method "copy_to" called'
      end

      def delete!
        raise 'abstract method "delete!" called'
      end

      def path
        raise 'abstract method "path" called'
      end

      def birthtime
        raise 'abstract method "birthtime" called'
      end
    end

    class AbstractDir
      def title
        raise 'abstract method "title" called'
      end

      def is_dir?
        true
      end

      def entries(&block)
        raise 'abstract method "entries" called'
      end

      def fs
        raise 'abstract method "fs" called'
      end

      # Create sub directory.
      # @param {String} title 
      # @return {AbstractDir} AbstractDir object pointing to created directory.
      def create_dir!(title)
        raise 'abstract method "create_dir!" called'
      end

      # Upload a file with 'title' by reading 'io', and return AbstractFile derived object.
      # @param {IO} io
      # @param {String} title
      # @param {DateTime} mtime
      # @parma {DateTime} birthtime
      # @return  {AbstractFile} AbstractFile object pointing to created file.
      # @raise NotSupportedError when 'create_file' operation is not supported by the filesystem.
      def create_file_with_read_io!(io, title, mtime, birthtime)
        raise 'abstract method "create_file_with_read_io!" called'
      end

      # Create a file with 'title', and return IO object to write to it.
      # @raise NotSupportedError when 'create_file' operation is not supported by the filesystem.
      # @return {Tuple} tuple of (AbstractFile, IO)
      def create_write_io!(title)
        raise 'abstract method "create_write_io!" called'
      end

      def delete!
        raise 'abstract method "delete!" called'
      end

      def path
        raise 'abstract method "path" called'
      end
    end

    def can_create_io_stream?
      raise 'abstract method "can_create_read_io?" called'
    end
  end
end
