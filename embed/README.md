embed - Java-caRuby Tissue integration
======================================

Synopsis
--------
This directory contains the source for building caRuby Tissue jar files.

Build
-----
Build embed as follows:

1. Install the caruby-* gems.

2. Install the following gems:
  * `buildr`
  * `buildr-gemjar`

6. Copy the caTissue client file `lib/commonpackage.jar` to the embed `lib` directory.

3. Fork this `caruby-tissue` git project.

4. cd to the `embed` subdirectory.

5. Run `bin/cat-embed-upd-gems`.

5. Run `buildr`.

Usage
-----
* Add the embed `target` jar files to your classpath.

* Add a `.catissue` file to your home directory as described in
  http://caruby.tenderapp.com/kb/tissue/how-do-i-configure-caruby-to-work-with-catissue

Bugs
----
* `buildr-gemjar` only operates on gems that are installed in the `target/gem_home` directory.
  This error occurs with the JRuby 1.6.0RC2 releases, and perhaps others.
  The error largely defeats the purpose of `buildr-gemjar`, but so it goes.
  The work-around is to manually update `target/gem_home` as described in the
  Build section above.
