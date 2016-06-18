# coding: utf-8
# frozen_string_literal: true

module GDSync
  # Abstract class that represents filesystem.
  class FileSystem
    class NotSupportedError < RuntimeError
    end

    class AbstractFile
      # Returns file name.
      # @return [String]
      def title
        raise 'abstract method "title" called'
      end

      # Path string (ex. "googledrive://Some/Directory/sample.txt")
      # @return [String]
      def path
        raise 'abstract method "path" called'
      end

      def is_dir?
        false
      end

      # File size in bytes.
      # @return [Integer]
      def size
        raise 'abstract method "size" called'
      end

      # Last modified time.
      # @return [DateTime]
      def mtime
        raise 'abstract method "mtime" called'
      end

      # Created time
      # @return [DateTime]
      def birthtime
        raise 'abstract method "birthtime" called'
      end

      # MD5 checksum.
      # @return [String]
      def md5
        raise 'abstract method "md5" called'
      end

      # A FileSystem object which manages this AbstractFile object.
      # @return [FileSystem]
      def fs
        raise 'abstract method "fs" called'
      end

      # Creates IO object to read the file.
      # @return [IO]
      # @raise NotSupportedError when 'create_read_io' operation is not supported by the filesystem.
      def create_read_io
        raise 'abstract method "create_read_io" called'
      end

      # Read this file and write to 'write_io' IO object.
      # @param write_io [IO]
      def write_to(write_io)
        raise 'abstract method "write_to" called'
      end

      # Read from @a read_io and write to this file.
      # @param read_io [IO]
      # @param mtime [DateTime] New last modified datetime of this file.
      # @return [AbstractFile]
      def update!(read_io, mtime)
        raise 'abstract method "update!" called'
      end

      # Copy file to 'dest_dir'. self and dest_dir must be same filesystem.
      # @param dest_dir [AbstractDir]
      # @pre self.fs == dest_dir.fs
      # @return  [AbstractFile]  AbstractFile object pointing to copied file.
      def copy_to(dest_dir)
        raise 'abstract method "copy_to" called'
      end

      # Delete file.
      def delete!
        raise 'abstract method "delete!" called'
      end
    end

    class AbstractDir
      # Name of directory
      # @return [String]
      def title
        raise 'abstract method "title" called'
      end

      def is_dir?
        true
      end

      # Enumerate contents of directory.
      def entries(&block)
        raise 'abstract method "entries" called'
      end

      # A FileSystem object which manages this AbstractDir object.
      # @return [FileSystem]
      def fs
        raise 'abstract method "fs" called'
      end

      # Create sub directory.
      # @param title [String]
      # @return [AbstractDir] AbstractDir object pointing to created directory.
      def create_dir!(title)
        raise 'abstract method "create_dir!" called'
      end

      # Upload a file with 'title' by reading 'io', and return AbstractFile derived object.
      # @param io [IO]
      # @param title [String]
      # @param mtime [DateTime]
      # @parma birthtime [DateTime]
      # @return  [AbstractFile] AbstractFile object pointing to created file.
      # @raise NotSupportedError when 'create_file' operation is not supported by the filesystem.
      def create_file_with_read_io!(io, title, mtime, birthtime)
        raise 'abstract method "create_file_with_read_io!" called'
      end

      # Create a file with 'title', and return IO object to write to it.
      # @raise NotSupportedError when 'create_file' operation is not supported by the filesystem.
      # @return [AbstractFile, IO]
      def create_write_io!(title)
        raise 'abstract method "create_write_io!" called'
      end

      # Delete directory recursively.
      def delete!
        raise 'abstract method "delete!" called'
      end

      # Path string (ex. "googledrive://Some/Directory")
      # @return [String]
      def path
        raise 'abstract method "path" called'
      end
    end

    # Return true if this filesystem can create [IO] objects for file read/write.
    # @return [Boolean]
    def can_create_io_stream?
      raise 'abstract method "can_create_read_io?" called'
    end
  end
end
