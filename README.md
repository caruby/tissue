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

4. Define the caRuby Tissue access property file as described in the configuration
   [FAQ](how-do-i-configure-caruby-to-work-with-catissue).

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

      bin/seed
   
   This command initializes the administrative objects in the Galena test database,
   including the Galena collection protocol, site, cancer center, tissue bank and coordinator.

3. Run the following:

      crtmigrate --target TissueSpecimen --mapping conf/migration/simple_fields.yaml data/simple.csv

   This command migrates the CSV record in the `simple.csv` input file into a caTissue
   `TissueSpecimen` based on the `simple_fields.yaml` mapping file.
   The command will take a couple of minutes to finish, since the less information
   you provide caRuby the more it works to fill in the missing bits. In the meantime,
   peruse the configuration and data files to see which data are migrated and
   where this data ends up in caTissue.
   
4. Open the caTissue application on the test server and verify the content of the
   Galena CP collection protocol.
   
The other examples are run in a similar manner. Each example demonstrates different
features of the caRuby Migration utility as follows:

* simple - a good starting point with limited input fields
* minimal - the fewest possible input fields without writing custom Ruby shim code
* general - lots of input fields, no custom Ruby code
* filter - a smattering of custom Ruby shim code to convert input values to caTissue values
* frozen - an example demonstrating how to import storage locations

Try running an example with the `--debug` flag and look at the `log/migration.log` file to see
what caRuby is up to behind the scenes (hint: a lot!).

Input data
----------
The sample Galena Tissue Bank CSV input files hold one row for each specimen.
Common fields are as follows:

* MRN - Patient Medical Record Number
* Initials - Patient name initials
* Frozen? - Flag indicating whether the specimen is frozen
* SPN - Surgical Pathology Number
* Collection Date - Date the specimen was acquired by the tissue bank
* Received Date - Date the specimen was donated by the participant
* Quantity - Amount collected
* Box - Tissue storage container
* X - the tissue box column
* Y - the tissue box row
