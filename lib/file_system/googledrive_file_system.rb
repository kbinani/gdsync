# coding: utf-8
# frozen_string_literal: true

module GDSync
  class GoogleDriveFileSystem < FileSystem
    class File < AbstractFile
      # @param  {GoogleDriveFileSystem}  fs
      # @param  {GoogleDrive::File} gd_file
      def initialize(fs, gd_file, path)
        @fs = fs
        @file = gd_file
        @path = path
      end

      def title
        @file.title
      end

      def size
        @file.size.to_i
      end

      def mtime
        @file.modified_time
      end

      def md5
        @file.api_file.md5_checksum
      end

      def fs
        @fs
      end

      def create_read_io
        raise NotSupportedError.new
      end

      def write_to(write_io)
        @file.download_to_io(write_io)
      end

      def copy_to(dest_dir)
        request_object = {
          name: title,
          parents: [dest_dir.id],
          created_time: birthtime.rfc3339,
          modified_time: mtime.rfc3339,
        }
        params = {
        }
        api_file = @fs.session.drive.copy_file(@file.id, request_object, params)
        file = @fs.session.wrap_api_file(api_file)
        if file.nil?
          nil
        else
          File.new(@fs, file, ::File.join(dest_dir.path, title))
        end
      end

      def delete!
        @file.delete
      end

      def path
        @path
      end

      def birthtime
        @file.created_time
      end
    end

    class Dir < AbstractDir
      def initialize(fs, gd_collection, path)
        @fs = fs
        @collection = gd_collection
        @path = path
      end

      def title
        @collection.title
      end

      def entries(&block)
        @collection.files { |file|
          unless file.explicitly_trashed
            if file.is_a?(GoogleDrive::Collection)
              d = Dir.new(@fs, file, ::File.join(@path, file.title))
              block.call(d)
            else
              f = File.new(@fs, file, ::File.join(@path, file.title))
              block.call(f)
            end
          end
        }
      end

      def fs
        @fs
      end

      def create_dir!(title)
        created = @collection.create_subcollection(title)
        if created.nil?
          nil
        else
          Dir.new(@fs, created, ::File.join(@path, title))
        end
      end

      def create_file_with_read_io!(io, title, mtime, birthtime)
        params = {
          upload_source: io,
          content_type: 'application/octet-stream',
          fields: '*',
        }
        request_object = {
          name: title,
          parents: [@collection.id],
          modified_time: mtime.rfc3339,
          created_time: birthtime.rfc3339,
        }

        dest_file = nil

        begin
          api_file = @fs.session.drive.create_file(request_object, params)
          dest_file = @fs.session.wrap_api_file(api_file)
        rescue => e
          return nil
        end

        File.new(@fs, dest_file, ::File.join(@path, title))
      end

      def create_write_io!(title)
        raise NotSupportedError.new
      end

      def delete!
        @collection.delete
      end

      def path
        @path
      end

      def id
        @collection.id
      end
    end

    def initialize(gd_session)
      @session = gd_session
    end

    def can_create_io_stream?
      false
    end

    def session
      @session
    end
  end
end
