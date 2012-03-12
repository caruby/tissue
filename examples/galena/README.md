Galena caRuby Tissue example
============================

Synopsis
--------
This directory contains the caRuby Tissue example for the hypothetical Galena Cancer Center.
The example files are a useful starting point for configuring your own migration.

The Galena example demonstrates how to load the content of a source tissue bank into caTissue.
The use cases illustrate several common migration impediments:

* Different terminology than caTissue
* Different associations than caTissue
* Incomplete input for caTissue
* Denormalized input
* Inconsistent input
* Input data scrubbing
* Specimen annotations
* Aliquot inference

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

Each example has a field mapping configuration in the `conf/` directory.
For example, the `simple.csv` input file is migrated into caTissue using the
`simple/migration.yaml` configuration file.

Migrate the Galena `simple` example as follows:

1. Open a console in the copied Galena example location.

2. Run the following:

   `bin/seed`
   
   This command initializes the administrative objects in the Galena test database,
   including the Galena collection protocol, site, cancer center, tissue bank and coordinator.

3. Run the following:

   `crtmigrate --target TissueSpecimen --mapping conf/simple/fields.yaml data/simple.csv`

   This command migrates the CSV record in the `simple.csv` input file into a caTissue
   `TissueSpecimen` based on the `simple/fields.yaml` mapping file.
   Peruse the configuration and data files to see which data are migrated and
   where this data ends up in caTissue.
   
4. Open the caTissue application on the test server and verify the content of the
   Galena CP collection protocol.
   
The other examples are run in a similar manner. Each example demonstrates different
features of the caRuby Migration utility as follows:

* <tt>registration</tt> - registers participants in a collection protocol

  `crtmigrate --target CollectionProtocolRegistration --mapping conf/registration/fields.yaml --defaults conf/defaults.yaml data/registration.csv`

* <tt>simple</tt> - migrates one specimen with limited input fields

  `crtmigrate --target TissueSpecimen --mapping conf/simple/fields.yaml --defaults conf/defaults.yaml data/simple.csv`

* <tt>general</tt> - migrates specimens with lots of input fields and a minimal configuration

  `crtmigrate --target TissueSpecimen --mapping conf/general/fields.yaml data/general.csv`

* <tt>filter</tt> - applies a value filter and shim code to convert input values to caTissue values and reject an incomplete migration

  `crtmigrate --target TissueSpecimen --mapping conf/filter/fields.yaml  --defaults conf/defaults.yaml --filters conf/filter/values.yaml --shims lib/galena/filter.rb --bad bad.csv data/filter.csv`

* <tt>frozen</tt> - adds a custom default and places specimens in storage locations

  `crtmigrate --target TissueSpecimen --mapping conf/frozen/fields.yaml --defaults conf/defaults.yaml,conf/frozen/defaults.yaml --shims lib/galena/frozen.rb data/frozen.csv`

* <tt>annotation</tt> - annotates the specimens with Dynamic Extensions

  `crtmigrate --target SpecimenCollectionGroup::Pathology::RadicalProstatectomyPathologyAnnotation --mapping conf/annotation/fields.yaml --defaults conf/defaults.yaml,conf/annotation/defaults.yaml data/annotation.csv`

Try running an example with the `--debug` flag and look at the `log/migration.log` file to see
what caRuby is up to behind the scenes (hint: a lot!).

Input data
----------
The sample Galena Tissue Bank CSV input files hold one row for each specimen.
The following input fields are included in the examples:

* <tt>Protocol</tt> - Collection Protocol title
* <tt>MRN</tt> - Patient Medical Record Number
* <tt>Initials</tt> - Patient name initials
* <tt>Frozen?</tt> - Flag indicating whether the specimen is frozen
* <tt>SPN</tt> - Surgical Pathology Number
* <tt>Collection Date</tt> - Date the specimen was acquired by the tissue bank
* <tt>Received Date</tt> - Date the specimen was donated by the participant
* <tt>Quantity</tt> - Amount collected
* <tt>Box</tt> - Tissue storage container
* <tt>X</tt> - the tissue box column
* <tt>Y</tt> - the tissue box row
* <tt>Gleason</tt>: Specimen primary gleason score
* <tt>Grade</tt>: Specimen histologic WHO grade

