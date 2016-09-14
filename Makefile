export SHELLOPTS:=errexit:pipefail
SHELL=/bin/bash  # required to make pipefail work
.SECONDARY:      # do not delete any intermediate files

LOG = perl -ne 'use POSIX qw(strftime); $$|=1; print strftime("%F %02H:%02M:%S ", localtime), $$ARGV[0], "$@: $$_";'

PROJECT_HOME=/mnt/projects/reza
REFGENOME=/mnt/projects/generic/data/broad/human_g1k_v37.fasta
DOCKER=docker run -i --rm --net=host -e DOCKER_UID=$$(id -u) -e DOCKER_UNAME=$$(id -un) -e DOCKER_GID=$$(id -g) -e DOCKER_GNAME=$$(id -gn) -e DOCKER_HOME=$$HOME \
       -v /home:/home \
       -v /data_synology:/data_synology \
       -v /home/cf/reza/results:$(PROJECT_HOME)/results \
       -v /data_synology/christian/reza/data/:$(PROJECT_HOME)/data:ro \
       -v /data_synology/christian/generic/data/current:/mnt/projects/generic/data:ro \
       -w $$(pwd)
PICARD=$(DOCKER) biowaste:5000/ccri/picard-2.2.2 java -XX:+UseParallelGC -XX:ParallelGCThreads=8 -Xmx2g -Djava.io.tmpdir=`pwd`/tmp -jar /usr/picard/picard.jar

all: fastqc bwa picard

#-----------	
# FASTQC
#-----------	

.PHONY: fastqc
fastqc: fastqc/NG-9746_1994_0053_5_lib126501_4653_3_1_fastqc.html \
		fastqc/NG-9746_1994_0053_5_lib126501_4653_3_2_fastqc.html \
		fastqc/NG-9746_1994_0053_5_lib127027_4668_2_1_fastqc.html \
		fastqc/NG-9746_1994_0053_5_lib127027_4668_2_2_fastqc.html \
		fastqc/NG-9746_1995_2120_Tu_lib130284_4668_3_1_fastqc.html \
		fastqc/NG-9746_1995_2120_Tu_lib130284_4668_3_2_fastqc.html \
		fastqc/NG-9746_1995_2120_Tu_lib131691_4668_4_1_fastqc.html \
		fastqc/NG-9746_1995_2120_Tu_lib131691_4668_4_2_fastqc.html

fastqc/%_fastqc.html: $(PROJECT_HOME)/data/fastq/%.fastq.gz
	mkdir -p fastqc/$*.part
	/data_synology/software/FastQC-0.11.2/fastqc -o fastqc/$*.part $^
	mv fastqc/$*.part/* fastqc
	rmdir fastqc/$*.part

#-----------	
# ALIGNMENT, SORTING, MARK DUPLICATES, INDEXING
#-----------

.PHONY: bwa
bwa: bwa/1994_0053_5.bwa.sorted.dupmarked.bam.bai bwa/1995_2120_Tu.bwa.sorted.dupmarked.bam.bai

bwa/1994_0053_5.bwa.bam: $(REFGENOME) \
					     $(PROJECT_HOME)/data/fastq/NG-9746_1994_0053_5_lib126501_4653_3_1.fastq.gz \
					     $(PROJECT_HOME)/data/fastq/NG-9746_1994_0053_5_lib126501_4653_3_2.fastq.gz \
					     $(PROJECT_HOME)/data/fastq/NG-9746_1994_0053_5_lib127027_4668_2_1.fastq.gz \
					     $(PROJECT_HOME)/data/fastq/NG-9746_1994_0053_5_lib127027_4668_2_2.fastq.gz	
	mkdir -p bwa
	flock -x .lock /data_synology/software/bwa-0.7.12/bwa mem \
		-t 50 \
		-R '@RG\tID:RG1\tPL:Illumina\tSM:1994_0053_5' \
		$(word 1,$^) <(zcat $(word 2,$^) $(word 4,$^)) <(zcat $(word 3,$^) $(word 5,$^)) | \
			/data_synology/software/samtools-0.1.19/samtools view -bhS - \
		2>&1 1>$@.part | $(LOG)
	mv $@.part $@

bwa/1995_2120_Tu.bwa.bam: $(REFGENOME) \
					      $(PROJECT_HOME)/data/fastq/NG-9746_1995_2120_Tu_lib130284_4668_3_1.fastq.gz \
					      $(PROJECT_HOME)/data/fastq/NG-9746_1995_2120_Tu_lib130284_4668_3_2.fastq.gz \
					      $(PROJECT_HOME)/data/fastq/NG-9746_1995_2120_Tu_lib131691_4668_4_1.fastq.gz \
					      $(PROJECT_HOME)/data/fastq/NG-9746_1995_2120_Tu_lib131691_4668_4_2.fastq.gz	
	mkdir -p bwa
	flock -x .lock /data_synology/software/bwa-0.7.12/bwa mem \
		-t 50 \
		-R '@RG\tID:RG1\tPL:Illumina\tSM:1995_2120_Tu' \
		$(word 1,$^) <(zcat $(word 2,$^) $(word 4,$^)) <(zcat $(word 3,$^) $(word 5,$^)) | \
			/data_synology/software/samtools-0.1.19/samtools view -bhS - \
		2>&1 1>$@.part | $(LOG)
	mv $@.part $@

bwa/%.bwa.sorted.bam: bwa/%.bwa.bam
	/data_synology/software/samtools-0.1.19/samtools sort -@ 5 -o $< $* 2>&1 1>$@.part | $(LOG)
	mv $@.part $@
	rm $<

bwa/%.bwa.sorted.dupmarked.bam: bwa/%.bwa.sorted.bam
	mkdir -p picard
	java -XX:+UseParallelGC -XX:ParallelGCThreads=8 -Xmx2g -Djava.io.tmpdir=`pwd`/tmp -jar /data_synology/software/picard-tools-1.114/MarkDuplicates.jar \
		INPUT=$< \
		OUTPUT=$@.part \
		METRICS_FILE=picard/$*.mark_duplicates_metrics \
		VALIDATION_STRINGENCY=LENIENT \
		2>&1 1>$@.part | $(LOG)
	mv $@.part $@
	rm $<

bwa/%.bwa.sorted.dupmarked.bam.bai: bwa/%.bwa.sorted.dupmarked.bam
	rm -f $@
	/data_synology/software/samtools-0.1.19/samtools index $^ $@.part 2>&1 | $(LOG)
	mv $@.part $@

#-----------	
# PICARD
#-----------

.PHONY: picard
picard: picard/1994_0053_5.multiplemetrics \
		picard/1995_2120_Tu.multiplemetrics \
		picard/1994_0053_5.wgsmetrics.txt \
		picard/1995_2120_Tu.wgsmetrics.txt

picard/%.multiplemetrics: bwa/%.bwa.sorted.dupmarked.bam bwa/%.bwa.sorted.dupmarked.bam.bai
	mkdir -p picard && rm -f $@
	$(PICARD) CollectMultipleMetrics \
		INPUT=$< \
		OUTPUT=picard/$* \
		VALIDATION_STRINGENCY=LENIENT \
		PROGRAM=CollectAlignmentSummaryMetrics \
		PROGRAM=CollectInsertSizeMetrics \
		PROGRAM=QualityScoreDistribution \
		PROGRAM=MeanQualityByCycle \
		2>&1 | $(LOG)
	touch $@
	
picard/%.wgsmetrics.txt: bwa/%.bwa.sorted.dupmarked.bam $(REFGENOME)
	mkdir -p picard
	$(PICARD) CollectWgsMetrics \
		INPUT=$< \
		OUTPUT=$@.part \
		REFERENCE_SEQUENCE=$(word 2, $^)
	mv $@.part $@
