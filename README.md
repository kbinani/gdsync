# gdsync - `rsync` like file sync tool

[![Build Status](https://travis-ci.org/kbinani/gdsync.svg?branch=master)](https://travis-ci.org/kbinani/gdsync)
[![Build Status](https://ci.appveyor.com/api/projects/status/b1ky64n0wtdqie3f/branch/master?svg=true)](https://ci.appveyor.com/project/kbinani/gdsync/branch/master)
[![Coverage Status](https://coveralls.io/repos/github/kbinani/gdsync/badge.svg?branch=master)](https://coveralls.io/github/kbinani/gdsync?branch=master)
[![license](https://img.shields.io/github/license/mashape/apistatus.svg?maxAge=2592000)]()

# Installation

```
git clone https://github.com/kbinani/gdsync.git
cd gdsync
bundle install
```

# Authentication

The first time you upload to/download from Google Drive, gdsync will prompt authentication message like this:

```
1. Open this page:
https://accounts.google.com/o/oauth2/auth?access_type=offline&client_id=788008427451-1h3lt65qc87afhcm1fvh1h3gliut5ivq.apps.googleusercontent.com&redirect_uri=urn:ietf:wg:oauth:2.0:oob&response_type=code&scope=https://www.googleapis.com/auth/drive%20https://spreadsheets.google.com/feeds/

2. Enter the authorization code shown in the page:
```

You have to open the web page and follow the instruction by Google. Then paste authentication code. The autentication code will be stored to `config.json` under the project root directory.

# Usage

`gdsync` has a subset of `rsync(1)` options. Supported `rsync` options are:

```
 -v, --verbose                    increase verbosity
 -c, --checksum                   skip based on checksum, not mod-time & size
 -a, --archive                    archive mode; same as -rt
 -r, --recursive                  recurse into directories
 -u, --update                     skip files that are newer on the receiver
 -d, --dirs                       transfer directories without recursing
 -t, --times                      preserve time
 -n, --dry-run                    show what would have been transferred
     --existing                   skip creating new files on receiver
     --ignore-existing            skip updating files that exist on receiver
     --remove-source-files        sender removes synchronized files (non-dir)
     --delete                     delete extraneous files from dest dirs
     --max-size=SIZE              don't transfer any file larger than SIZE
     --min-size=SIZE              don't transfer any file smaller than SIZE
 -I, --ignore-times               don't skip files that match size and time
     --size-only                  skip files that match in size
```

## Local to Google Drive sync

```
ruby gdsync.rb --archive /path/to/source/dir/ googledrive://path/to/destination/dir
```

## Google Drive to Local sync

```
ruby gdsync.rb --archive googledrive://path/to/source/dir/ /path/to/destination/dir
```

## Google Drive to Google Drive sync

```
ruby gdsync.rb --archive googledrive://path/to/soruce/dir/ googledrive://path/to/destination/dir
```

## Local to Local sync

It is possible to sync between local directories with gdsync, but rsync is better choice in this case.

# License

The MIT License

# Author

@kbinani

# Notice

`gdsync` comes with ABSOLUTELY NO WARRANTY.
