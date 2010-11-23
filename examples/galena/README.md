Galena caRuby Tissue example
============================

Synopsis
--------
This directory contains the caRuby Tissue example for the hypothetical Galena Cancer Center.
The example files are a useful template for building your own migrator.

The Galena example demonstrates how to load the content of a custom tissue bank into caTissue.
The use cases illustrate several common migration impediments:

* Different terminology than caTissue
* Different associations than caTissue
* Incomplete input for caTissue
* Denormalized input
* Inconsistent input
* Input data scrubbing
* Aliquot inference
* Pre-defined caTissue protocol

Setup
-----
1. Run the `crtexample --list` command to display the Galena example location.

2. Copy the example into a location of your choosing.

3. Configure a caTissue client to connect to a test caTissue instance, as described in the
   caTissue Technical Guide.

4. Define the caRuby Tissue access property file as described in
   [http://caruby.tenderapp.com/faqs/getting-started/tissue_config](FAQ).

Migration
---------
The example migration input data resides in the `data` directory.
Each CSV input file holds one row for each specimen.

Each example has a field mapping configuration in the `conf/migration` directory.
For example, the `simple.csv` input file is migrated into caTissue using the
`simple_migration.yaml` configuration file.

Migrate the Galena `simple` example as follows:

1. Open a console in the copied Galena example location.

2. Run the following:

      crtmigrate --file conf/migration/simple.yaml data/simple.yaml

3. Check the test database and verify that a there is a collection protocol
   named `Galena CP.
   
The other examples are run in a similar manner.
