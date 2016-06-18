# coding: utf-8
# frozen_string_literal: true

require 'optparse'
require_relative 'lib/sync.rb'

option = {}
option[:delete] = false
option[:checksum] = false
option[:verbose] = true
option[:dry_run] = false

opts = OptionParser.new
opts.banner = 'Usage: gdsync [options] SRC DEST'
opts.on('--delete', 'delete extraneous files from dest dirs') { |v| option[:delete] = true }
opts.on('-c', '--checksum', 'skip based on checksum, not mod-time & size') { |v| option[:checksum] = true }
opts.on('-v', '--verbose', 'increase verbosity') { |v| option[:verbose] = true }
opts.on('-n', '--dry-run', 'show what would have been transferred') { |v| option[:dry_run] = true }
opts.separator('')
opts.separator('SRC, DEST')
opts.separator('    Use \'googledrive://\' to specify directory on Google Drive.')
opts.separator('    Example:')
opts.separator('        gdsync ./sourcedir/ googledrive://destdir')
opts.separator('        gdsync googledrive://sourcedir/ ./destdir')
opts.separator('        gdsync googledrive://sourcedir googledrive://destdir')
args = opts.parse!(ARGV)

src = args[0]
dest = args[1]

option = GDSync::Option.new(option)
sync = GDSync::Sync.new(src, dest, option)
sync.run
