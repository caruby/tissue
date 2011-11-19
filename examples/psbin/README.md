PSBIN caRuby Tissue example
============================

Synopsis
--------
This directory contains the caRuby Tissue example for the **P**rostate **S**PORE **B**io**I**nformatics **N**etwork
(PSBIN) initiative.
The PSBIN initiative shares participant cancer center data in caTissue instances with common
data elements. The official PSBIN import utility is a Java program which operates on a
special-purpose input XML file and calls caRuby to create annotations. The example shown
here is a caRuby Tissue Migrator import which operates on CSV files.

The migration input files are in the `data` directory. The input maps to caTissue entities as follows:

* `patient` => `Participant`

* `biopsy` => prostate biopsy `SpecimenCollectionGroup`

* `surgery` => prostatectomy `SpecimenCollectionGroup`

* `t_stage` => the tumor stage as a lab annotation

* (`neo`)`adjuvant_hormone` => (neo)adjuvant hormone therapy annotation

* (`neo`)`adjuvant_radiation` => (neo)adjuvant radiation therapy annotation

Setup
-----
Configure caRuby and copy the PSBIN example as described in the Galena examples
[Setup](https://github.com/caruby/tissue/blob/master/examples/galena/README.md).

Create a simple `Prostate SPORE` caTissue collection protocol in a test database.

Migration
---------
Run the following commands in the copied example location:

    crtmigrate --target Participant --mapping conf/patient_fields.yaml --defaults conf/patient_defaults.yaml data/patient.csv
    crtmigrate --target SpecimenCollectionGroup --mapping conf/biopsy_fields.yaml --defaults conf/biopsy_defaults.yaml data/biopsy.csv --shims lib/psbin/migration/helpers/shims/biopsy.rb
    crtmigrate --target SpecimenCollectionGroup --mapping conf/surgery_fields.yaml --defaults conf/surgery_defaults.yaml data/surgery.csv --shims lib/psbin/migration/helpers/shims/surgery.rb
    crtmigrate --target Participant::Clinical::LabAnnotation --mapping conf/t_stage_fields.yaml --defaults conf/t_stage_defaults.yaml data/t_stage.csv
    crtmigrate --target Participant::Clinical::TreatmentAnnotation --mapping conf/therapy_fields.yaml --defaults conf/neoadjuvant_hormone_defaults.yaml data/neoadjuvant_hormone.csv
    crtmigrate --target Participant::Clinical::RadRXAnnotation --mapping conf/therapy_fields.yaml --defaults conf/neoadjuvant_radiation_defaults.yaml data/neoadjuvant_radiation.csv
    crtmigrate --target Participant::Clinical::TreatmentAnnotation --mapping conf/therapy_fields.yaml --defaults conf/adjuvant_hormone_defaults.yaml data/adjuvant_hormone.csv
    crtmigrate --target Participant::Clinical::RadRXAnnotation --mapping conf/therapy_fields.yaml --defaults conf/adjuvant_radiation_defaults.yaml data/adjuvant_radiation.csv
