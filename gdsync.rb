# coding: utf-8
# frozen_string_literal: true

require 'optparse'
require_relative 'lib/sync.rb'

opt = []
parser = OptionParser.new
parser.banner = 'Usage: gdsync [options] SRC DEST'
parser.on('-v', '--verbose', 'increase verbosity') { opt << '--verbose' }
parser.on('-c', '--checksum', 'skip based on checksum, not mod-time & size') { opt << '--checksum' }
parser.on('-a', '--archive', 'archive mode; same as -rt') { opt << '--archive' }
parser.on('-r', '--recursive', 'recurse into directories') { opt << '--recursive' }
parser.on('-u', '--update', 'skip files that are newer on the receiver') { opt << '--update' }
parser.on('-d', '--dirs', 'transfer directories without recursing') { opt << '--dirs' }
parser.on('-t', '--times', 'preserve time') { opt << '--times' }
parser.on('-n', '--dry-run', 'show what would have been transferred') { opt << '--dry-run' }
parser.on('--existing', 'skip creating new files on receiver') { opt << '--existing' }
parser.on('--ignore-existing', 'skip updating files that exist on receiver') { opt << '--ignore-existing' }
parser.on('--remove-source-files', 'sender removes synchronized files (non-dir)') { opt << '--remove-source-files' }
parser.on('--delete', 'delete extraneous files from dest dirs') { opt << '--delete' }
parser.on('--max-size=SIZE', 'don\'t transfer any file larger than SIZE') { |v| opt << "--max-size=#{v}" }
parser.on('--min-size=SIZE', 'don\'t transfer any file smaller than SIZE') { |v| opt << "--min-size=#{v}" }
parser.on('-I', '--ignore-times', 'don\'t skip files that match size and time') { opt << '--ignore-times' }
parser.on('--size-only', 'skip files that match in size') { opt << '--size-only' }
parser.separator('')
parser.separator('SRC, DEST')
parser.separator('    Use \'googledrive://\' to specify directory on Google Drive.')
parser.separator('    Example:')
parser.separator('        gdsync -a ./sourcedir/ googledrive://destdir')
parser.separator('        gdsync -a googledrive://sourcedir/ ./destdir')
parser.separator('        gdsync -a googledrive://sourcedir googledrive://destdir')

args = parser.parse(ARGV)

raise 'Too few arguments' if args.size < 2
raise 'Too many arguments' if args.size > 2

src = args[0]
dest = args[1]

option = GDSync::Option.new(opt)
sync = GDSync::Sync.new([src], dest, option)
sync.run
