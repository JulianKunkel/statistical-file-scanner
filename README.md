# Statistical-File-Scanner for Data Centers (SFS)

The statistical-file-scanner utilizes statistics to compute the estimated value for a data characteristics of large data sets
without actually requiring to scan the full data set.

The characteristics to determine is computed based on the occupied size (file size) of the data.
For example, one may want to estimate the percentage (proportion) a given file type has on the overall data, or how well data compresses,
i.e., what will be the compression ratio if I compress the 10 Petabyte of data with compression scheme X.

It works in different phases, 
1) First the complete list of files is determined together with their file sizes (!), yes this is costly but far less than compressing the full data.
2) A file list ist created for individual threads.
4) The scanner is started, it uses a database to remember which files it has scanned and, thus, can be stopped.
5) The output is loaded into a DB (it can also be loaded while the scanning process is ongoing).
6) Evaluation scripts can create arbitrary reports.

## Modes

SFS supports full and partial scanning mode.
In full mode, a file is assumed to be scanned completely by a plugin but it shall be prevented to rescan the same file.
In partial mode, a chunk of a file is scanned (e.g., randomly) and shall be rescanned every time.

## Plugins
The particular scanning activity is outsourced into plugins in that folder.

  * lzbench: This scans the file type using "file", the CDO file type (which is more accurate for scientific data) using "cdo"
    It also uses lzbench to determine characteristics for compression such as compression ratio and rate.

## Requirements
  * python
  * python-scipy
  * sqlite3

## Example execution
 
  * See example-run-lzbench.sh for an example to run the provided scripts.
