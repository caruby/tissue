embed - Java-caRuby Tissue integration
======================================

Synopsis
--------
This directory contains the source for building caRuby Tissue jar files.

Build
-----
Build embed as follows:

1. Fork this caruby-tissue git project.

2. Install or build the caruby-* gems.

2. Install the following gems:
  * `buildr`
  * `buildr-gemjar`

3. Stage the gems as described in `staging/README.txt`.

4. Copy the caTissue client file `lib/commonpackage.jar` to the embed `lib` directory.

5. Run `buildr` in the `embed` directory.

Usage
-----
See the `doc/dist/README.md` file.
