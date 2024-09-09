#!/bin/bash

source intronRet.config

## usage:
## $1 : `release` for latest nextflow/git release; `checkout` for git clone followed by git checkout of a tag ; `clone` for latest repo commit
## $2 : profile

set -e

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/'
}

wait_for(){
    PID=$(echo "$1" | cut -d ":" -f 1 )
    PRO=$(echo "$1" | cut -d ":" -f 2 )
    echo "$(date '+%Y-%m-%d %H:%M:%S'): waiting for ${PRO}"
    wait $PID
    CODE=$?
    
    if [[ "$CODE" != "0" ]] ; 
        then
            echo "$PRO failed"
            echo "$CODE"
            failed=true
            #exit $CODE
    fi
}

failed=false

PROFILE=$2
LOGS="work"
PARAMS="params.json"

mkdir -p ${LOGS}

if [[ "$1" == "release" ]] ; 
  then

    ORIGIN="mpg-age-bioinformatics/"
    
    FASTQC_RELEASE=$(get_latest_release ${ORIGIN}nf-fastqc)
    echo "${ORIGIN}nf-fastqc:${FASTQC_RELEASE}" >> ${LOGS}/software.txt
    FASTQC_RELEASE="-r ${FASTQC_RELEASE}"

    KALLISTO_RELEASE=$(get_latest_release ${ORIGIN}nf-kallisto)
    echo "${ORIGIN}nf-kallisto:${KALLISTO_RELEASE}" >> ${LOGS}/software.txt
    KALLISTO_RELEASE="-r ${KALLISTO_RELEASE}"

    HISAT2_RELEASE=$(get_latest_release ${ORIGIN}nf-hisat2)
    echo "${ORIGIN}nf-hisat2:${HISAT2_RELEASE}" >> ${LOGS}/software.txt
    HISAT2_RELEASE="-r ${HISAT2_RELEASE}"
    
    FEATURECOUNTS_RELEASE=$(get_latest_release ${ORIGIN}nf-featurecounts)
    echo "${ORIGIN}nf-featurecounts:${FEATURECOUNTS_RELEASE}" >> ${LOGS}/software.txt
    FEATURECOUNTS_RELEASE="-r ${FEATURECOUNTS_RELEASE}"
    
    MULTIQC_RELEASE=$(get_latest_release ${ORIGIN}nf-multiqc)
    echo "${ORIGIN}nf-multiqc:${MULTIQC_RELEASE}" >> ${LOGS}/software.txt
    MULTIQC_RELEASE="-r ${MULTIQC_RELEASE}"

    IBB_RELEASE=$(get_latest_release ${ORIGIN}nf-ibb)
    echo "${ORIGIN}nf-ibb:${IBB_RELEASE}" >> ${LOGS}/software.txt
    IBB_RELEASE="-r ${IBB_RELEASE}"

    uniq ${LOGS}/software.txt ${LOGS}/software.txt_
    mv ${LOGS}/software.txt_ ${LOGS}/software.txt
    
else

  for repo in nf-fastqc nf-kallisto nf-hisat2 nf-featurecounts nf-multiqc nf-ibb ; 
    do

      if [[ ! -e ${repo} ]] ;
        then
          git clone git@github.com:mpg-age-bioinformatics/${repo}.git
      fi

      if [[ "$1" == "checkout" ]] ;
        then
          cd ${repo}
          git pull
          RELEASE=$(get_latest_release ${ORIGIN}${repo})
          git checkout ${RELEASE}
          cd ../
          echo "${ORIGIN}${repo}:${RELEASE}" >> ${LOGS}/software.txt
      else
        cd ${repo}
        COMMIT=$(git rev-parse --short HEAD)
        cd ../
        echo "${ORIGIN}${repo}:${COMMIT}" >> ${LOGS}/software.txt
      fi

  done

  uniq ${LOGS}/software.txt >> ${LOGS}/software.txt_ 
  mv ${LOGS}/software.txt_ ${LOGS}/software.txt

fi

get_images() {
  echo "- downloading images"
  nextflow run ${ORIGIN}nf-fastqc ${FASTQC_RELEASE} -params-file ${PARAMS} -entry images -profile ${PROFILE} >> ${LOGS}/get_images.log 2>&1 && \
  nextflow run ${ORIGIN}nf-kallisto ${KALLISTO_RELEASE} -params-file ${PARAMS} -entry images -profile ${PROFILE} >> ${LOGS}/get_images.log 2>&1 && \
  nextflow run ${ORIGIN}nf-hisat2 ${HISAT2_RELEASE} -params-file ${PARAMS} -entry images -profile ${PROFILE} >> ${LOGS}/get_images.log 2>&1 && \
  nextflow run ${ORIGIN}nf-featurecounts ${FEATURECOUNTS_RELEASE} -params-file ${PARAMS} -entry images -profile ${PROFILE} >> ${LOGS}/get_images.log 2>&1 && \
  nextflow run ${ORIGIN}nf-multiqc ${MULTIQC_RELEASE} -params-file ${PARAMS} -entry images -profile ${PROFILE} >> ${LOGS}/get_images.log 2>&1 && \
  nextflow run ${ORIGIN}nf-ibb ${IBB_RELEASE} -params-file ${PARAMS} -entry images -profile ${PROFILE} >> ${LOGS}/get_images.log 2>&1
}

run_fastqc() {
  echo "- running fastqc"
  nextflow run ${ORIGIN}nf-fastqc ${FASTQC_RELEASE} -params-file ${PARAMS} -profile ${PROFILE} >> ${LOGS}/nf-fastqc.log 2>&1 && \
  nextflow run ${ORIGIN}nf-fastqc ${FASTQC_RELEASE} -params-file ${PARAMS} -entry upload -profile ${PROFILE} >> ${LOGS}/nf-fastqc.log 2>&1
}

run_kallisto() {
  echo "- running kallisto"
  nextflow run ${ORIGIN}nf-kallisto ${KALLISTO_RELEASE} -params-file ${PARAMS} -entry get_genome -profile ${PROFILE} >> ${LOGS}/kallisto.log 2>&1 && \
  nextflow run ${ORIGIN}nf-kallisto ${KALLISTO_RELEASE} -params-file ${PARAMS} -entry write_cdna -profile ${PROFILE} >> ${LOGS}/kallisto.log 2>&1 && \
  nextflow run ${ORIGIN}nf-kallisto ${KALLISTO_RELEASE} -params-file ${PARAMS} -entry index -profile ${PROFILE} >> ${LOGS}/kallisto.log 2>&1 && \
  nextflow run ${ORIGIN}nf-kallisto ${KALLISTO_RELEASE} -params-file ${PARAMS} -entry check_strand -profile ${PROFILE} >> ${LOGS}/kallisto.log 2>&1
}


####### EDIT
# run_hisat2() {
#   echo "- mapping raw data"
#   nextflow run ${ORIGIN}nf-bwa ${BWA_RELEASE} -params-file ${PARAMS} -entry index -profile ${PROFILE} >> ${LOGS}/bwa.log 2>&1 && \
#   nextflow run ${ORIGIN}nf-bwa ${BWA_RELEASE} -params-file ${PARAMS} -entry map_reads -profile ${PROFILE} >> ${LOGS}/bwa.log 2>&1
# }



# run_featureCounts() {
#   echo "- feature counts"
#   nextflow run ${ORIGIN}nf-featurecounts ${FEATURECOUNTS_RELEASE} -params-file ${PARAMS} -entry exomeGTF -profile ${PROFILE} >> ${LOGS}/featureCounts.log 2>&1 && \
#   nextflow run ${ORIGIN}nf-featurecounts ${FEATURECOUNTS_RELEASE} -params-file ${PARAMS} -profile ${PROFILE} >> ${LOGS}/featureCounts.log 2>&1
# }

# run_multiqc() {
#   echo "- multiqc"
#   nextflow run ${ORIGIN}nf-multiqc ${MULTIQC_RELEASE} -params-file ${PARAMS} -profile ${PROFILE} >> ${LOGS}/multiqc.log 2>&1 && \
#   nextflow run ${ORIGIN}nf-multiqc ${MULTIQC_RELEASE} -params-file ${PARAMS} -entry upload -profile ${PROFILE} >> ${LOGS}/multiqc.log 2>&1
# }



# get_images & IMAGES_PID=$!
# wait_for "${IMAGES_PID}:IMAGES"

# run_fastqc & FASTQC_PID=$!
# run_kallisto_get_genome & KALLISTO_PID=$!

# wait_for "${KALLISTO_PID}:KALLISTO"

# run_bwa & BWA_PID=$!
# wait_for "${BWA_PID}:BWA"

# run_deepVariant & DEEPVARIANT_PID=$!
# wait_for "${DEEPVARIANT_PID}:DEEPVARIANT"

# run_featureCounts & FEATURECOUNTS_PID=$!
# wait_for "${FEATURECOUNTS_PID}:FEATURECOUNTS"

# run_vep & VEP_PID=$!
# sleep 1

# run_multiqc & MULTIQC_PID=$!
# sleep 1

# for PID in "${MULTIQC_PID}:MULTIQC" "${VEP_PID}:VEP"
#   do
#     wait_for $PID
# done

# rm -rf ${project_folder}/upload.txt
# cat $(find ${project_folder}/ -name upload.txt) > ${project_folder}/upload.txt
# sort -u ${LOGS}/software.txt > ${LOGS}/software.txt_
# mv ${LOGS}/software.txt_ ${LOGS}/software.txt
# cp ${LOGS}/software.txt ${project_folder}/software.txt
# cp README_variantCalling.md ${project_folder}/README_variantCalling.md
# echo "main $(readlink -f ${project_folder}/software.txt)" >> ${project_folder}/upload.txt
# echo "main $(readlink -f ${project_folder}/README_variantCalling.md)" >> ${project_folder}/upload.txt
# cp ${project_folder}/upload.txt ${upload_list}
# echo "- done" && sleep 1

# exit