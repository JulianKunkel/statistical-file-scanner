# LZBench Plugin

This plugin uses lzbench to measure characteristics of compression schemes.
Additionally, file and the cdo tool is used to determine file types and investigate compression behavior on the file types.

You may want to adjust run.sh to define which compressors to utilize .

# Notes

Note that some compression schemes are memory bound while others are compute bound.
Thus, the resulting performance will not completely represent the scenario if you run the compressor on all threads at the same time.
Performance is virtually higher as some threads will spend time in reading the file and some are computing and less dependend on memory.

Consequently:
If you run many threads with only memory bound compressors, you will observe less throughput as the memory limits the throughput.
If you mix compute and memory bound compressors, both, the compute bound compressors and the memory compressors will not suffer too much as statistically many threads will currently process the compute bound threads.

The memcpy performance is an indicator of how much pressure on memory you observe.
