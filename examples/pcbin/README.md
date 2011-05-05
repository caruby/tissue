PCBIN caRuby Tissue example
============================

Synopsis
--------
This directory contains the caRuby Tissue example for the Prostate SPORE PCBIN initiative.
PCBIN shares participant cancer center data in caTissue instances with common data elements.

There are three migration input files, which map to +caTissue+ entities as follows:

* +patient+ => +Participant+

* +biopsy+ => prostate biopsy +SpecimenCollectionGroup+

* +surgery+ => prostatectomy +SpecimenCollectionGroup+


Setup
-----
Configure caRuby and copy the PCBIN example as described in the Galena examples
[Setup](https://github.com/caruby/tissue/blob/master/examples/galena/README.md).

Create a +Prostate SPORE+ caTissue collection protocol in a test database.

Migration
---------
Run the following commands in the copied example location:

    crtmigrate --target Participant --mapping conf/patient_fields.yaml --defaults conf/patient_defaults.yaml data/patient.csv
    crtmigrate --target Participant --mapping conf/t_stage_fields.yaml --defaults conf/t_stage_defaults.yaml data/t_stage.csv
    crtmigrate --target Participant --mapping conf/therapy_fields.yaml --defaults conf/neoadjuvant_hormone_defaults.yaml data/neoadjuvant_hormone.csv
    crtmigrate --target Participant --mapping conf/therapy_fields.yaml --defaults conf/neoadjuvant_radiation_defaults.yaml data/neoadjuvant_radiation.csv
    crtmigrate --target Participant --mapping conf/therapy_fields.yaml --defaults conf/adjuvant_hormone_defaults.yaml data/adjuvant_hormone.csv
    crtmigrate --target Participant --mapping conf/therapy_fields.yaml --defaults conf/adjuvant_radiation_defaults.yaml data/adjuvant_radiation.csv
    crtmigrate --target SpecimenCollectionGroup --mapping conf/biopsy_fields.yaml --defaults conf/biopsy_defaults.yaml data/biopsy.csv
    crtmigrate --target SpecimenCollectionGroup --mapping conf/surgery_fields.yaml --defaults conf/surgery_defaults.yaml data/surgery.csv
