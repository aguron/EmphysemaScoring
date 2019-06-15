#!/bin/bash
# Script for partitioning LIDC-IDRI into CT data for training, validation, and testing
#
# script processing range selection; full range {1..20}
r_start=6
r_end=$r_start

for type in mAs # z
do
    bash shell_scripts/parallel_script_runs.sh $type $r_start $r_end
done
