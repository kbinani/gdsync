# coding: utf-8
# frozen_string_literal: true

require 'optparse'
require_relative 'lib/sync.rb'

opt = {}
opt[:delete] = false
opt[:checksum] = false
opt[:verbose] = true
opt[:dry_run] = false
opt[:size_only] = false
opt[:recursive] = false
opt[:preserve_time] = false
opt[:archive] = false

parser = OptionParser.new
parser.banner = 'Usage: gdsync [options] SRC DEST'
parser.on('--delete', 'delete extraneous files from dest dirs') { |v| opt[:delete] = true }
parser.on('-c', '--checksum', 'skip based on checksum, not mod-time & size') { |v| opt[:checksum] = true }
parser.on('-v', '--verbose', 'increase verbosity') { |v| opt[:verbose] = true }
parser.on('-n', '--dry-run', 'show what would have been transferred') { |v| opt[:dry_run] = true }
parser.on('--size-only', 'skip files that match in size') { |v| opt[:size_only] = true }
parser.on('-r', '--recursive', 'recurse into directories') { |v| opt[:recursive] = true }
parser.on('-t', '--times', 'preserve time') { opt[:preserve_time] = true }
parser.on('-a', '--archive', 'archive mode; same as -rt') { opt[:archive] = true }
parser.separator('')
parser.separator('SRC, DEST')
parser.separator('    Use \'googledrive://\' to specify directory on Google Drive.')
parser.separator('    Example:')
parser.separator('        gdsync ./sourcedir/ googledrive://destdir')
parser.separator('        gdsync googledrive://sourcedir/ ./destdir')
parser.separator('        gdsync googledrive://sourcedir googledrive://destdir')
args = parser.parse!(ARGV)

raise "Too few arguments" if args.size < 2
raise "Too many arguments" if args.size > 2

src = args[0]
dest = args[1]

option = GDSync::Option.new(opt)
sync = GDSync::Sync.new([src], dest, option)
sync.run
