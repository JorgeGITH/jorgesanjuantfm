#!/bin/bash
#$ -S /bin/bash
###########################################################################
##                                                                        #
##                The HMM-based Speech Synthesis Systems                  #
##                Centre for Speech Technology Research                   #
##                     University of Edinburgh, UK                        #
##                      Copyright (c) 2007-2011                           #
##                        All Rights Reserved.                            #
##                                                                        #
##  THE UNIVERSITY OF EDINBURGH AND THE CONTRIBUTORS TO THIS WORK         #
##  DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING       #
##  ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT    #
##  SHALL THE UNIVERSITY OF EDINBURGH NOR THE CONTRIBUTORS BE LIABLE      #
##  FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES     #
##  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN    #
##  AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,           #
##  ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF        #
##  THIS SOFTWARE.                                                        #
###########################################################################
##                         Author: Junichi Yamagishi                      #
##                         Date:   31 November 2012                       #
##                         Contact: jyamagis@inf.ed.ac.uk                 #
###########################################################################

# Check Number of Args
if (( "$#" < "1" )); then
   echo "Usage:"
   echo "$0 config_file"
   exit 1
fi

# Load configure file
echo "...Load configure file..."
CONFIG_FILE=$1
. ${CONFIG_FILE}
if (( $?>0 ));then echo "Error; exiting."; exit 1; fi

# Make temporary directory
echo "...Make temporary directory..."
rm -rf ${TMP_DIR}
mkdir -p ${TMP_DIR}
mkdir -p $INTER_OUTPUT_ENGINE
mkdir -p $INTER_OUTPUT_ENGINE/clusters
mkdir -p $INTER_OUTPUT_ALIGN 

# Make file list
for AVM in ${AVMS[@]}
do
    echo "...Speaker adaptation from $AVM ..."
    mkdir -p ${TMP_DIR}/$AVM/
    mkdir -p ${TMP_DIR}/$AVM/xform
    mkdir -p ${TMP_DIR}/$AVM/xform/cmp
    mkdir -p ${TMP_DIR}/$AVM/xform/dur
    mkdir -p ${TMP_DIR}/$AVM/map/0/
    mkdir -p ${TMP_DIR}/$AVM/trash

    echo "...Make file lists..."
    rm -f ${TMP_DIR}/$AVM/hled.scp
    rm -f ${TMP_DIR}/$AVM/herest.scp
    for cmp in `find -L ${INTER_INPUT_FEATURE} -name \*.cmp`
    do

        base=`basename $cmp .cmp`
        if  test -s ${INTER_INPUT_FLABEL}/${base}.lab
        then

            echo $cmp >> ${TMP_DIR}/$AVM/herest.scp
            echo ${INTER_INPUT_FLABEL}/${base}.lab >> ${TMP_DIR}/$AVM/hled.scp
	    echo "${INTER_INPUT_FLABEL}/${base}.lab >> ${TMP_DIR}/$AVM/hled.scp"
        fi
    done

    # Make model list
    echo "...Make model list..."
    rm -f ${TMP_DIR}/$AVM/null.hed
    touch ${TMP_DIR}/$AVM/null.hed
    ${VC_PATH}/HLEd \
        -A \
        -D \
        -T 1 \
        -V \
        -l '*' \
        -n ${TMP_DIR}/$AVM/adp.context.list \
        -i ${TMP_DIR}/$AVM/hled.mlf \
        -S ${TMP_DIR}/$AVM/hled.scp \
        ${TMP_DIR}/$AVM/null.hed \
        > ${TMP_DIR}/$AVM/hled.log

    cat ${TMP_DIR}/$AVM/adp.context.list \
        ${MODEL_DIR}/$AVM/hmm/context.full.list \
        | sort -u \
        > ${TMP_DIR}/$AVM/adp.context.full.list
    rm -f ${TMP_DIR}/$AVM/null.hed

    # Make HED file for unseen models
    echo "...Make HED file for unseen models..."
    rm -f ${TMP_DIR}/$AVM/hhed.mku.cmp.hed
    echo "LT ${MODEL_DIR}/$AVM/hmm/tree.mcep.inf" >> ${TMP_DIR}/$AVM/hhed.mku.cmp.hed
    echo "LT ${MODEL_DIR}/$AVM/hmm/tree.logF0.inf" >> ${TMP_DIR}/$AVM/hhed.mku.cmp.hed
    echo "LT ${MODEL_DIR}/$AVM/hmm/tree.bndap.inf" >> ${TMP_DIR}/$AVM/hhed.mku.cmp.hed
    echo "AU ${TMP_DIR}/$AVM/adp.context.full.list" >> ${TMP_DIR}/$AVM/hhed.mku.cmp.hed
    rm -f ${TMP_DIR}/$AVM/hhed.mku.dur.hed
    echo "LT ${MODEL_DIR}/$AVM/hmm/tree.dur.inf" >> ${TMP_DIR}/$AVM/hhed.mku.dur.hed
    echo "AU ${TMP_DIR}/$AVM/adp.context.full.list" >> ${TMP_DIR}/$AVM/hhed.mku.dur.hed

    # Prepare unseen models
    echo "...Prepare unseen models..."
    ${VC_PATH}/HHEd \
        -A \
        -B \
        -C ${MODEL_DIR}/$AVM/config/general.conf \
        -T 1 \
        -D \
        -V \
        -i \
        -p \
        -H ${MODEL_DIR}/$AVM/hmm/clustered.cmp.mmf \
        -w ${TMP_DIR}/$AVM/adp.clustered.cmp.mmf \
        ${TMP_DIR}/$AVM/hhed.mku.cmp.hed \
        ${MODEL_DIR}/$AVM/hmm/context.cmp.list \
        > ${TMP_DIR}/$AVM/hhed.mku.cmp.log &
    ${VC_PATH}/HHEd \
        -A \
        -B \
        -C ${MODEL_DIR}/$AVM/config/general.conf \
        -T 1 \
        -D \
        -V \
        -i \
        -p \
        -H ${MODEL_DIR}/$AVM/hmm/clustered.dur.mmf \
        -w ${TMP_DIR}/$AVM/adp.clustered.dur.mmf \
        ${TMP_DIR}/$AVM/hhed.mku.dur.hed \
        ${MODEL_DIR}/$AVM/hmm/context.dur.list \
        > ${TMP_DIR}/$AVM/hhed.mku.dur.log &
    wait
    
    # Make stats file for regression class trees
    echo "...Make stats file for regression class trees..."
    perl ${SCRIPT_DIR}/make_stats.pl \
        ${MODEL_DIR}/$AVM/hmm/context.full.list \
        ${TMP_DIR}/$AVM/adp.context.full.list \
        ${TMP_DIR}/$AVM/cmp.stats \
        ${TMP_DIR}/$AVM/dur.stats

    # Make HED file for regression class trees
    echo "...Make HED file for regression class trees..."
    rm -f ${TMP_DIR}/$AVM/hhed.reg.cmp.hed
    echo "LS \"${TMP_DIR}/$AVM/cmp.stats\"" >> ${TMP_DIR}/$AVM/hhed.reg.cmp.hed
    echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.mcep.inf\"" >> ${TMP_DIR}/$AVM/hhed.reg.cmp.hed
    echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.logF0.inf\"" >> ${TMP_DIR}/$AVM/hhed.reg.cmp.hed
    echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.bndap.inf\"" >> ${TMP_DIR}/$AVM/hhed.reg.cmp.hed
    echo "DR \"dectree_cmp\"" >> ${TMP_DIR}/$AVM/hhed.reg.cmp.hed
    #echo "RC 256 \"dectree_cmp\" " >> ${TMP_DIR}/$AVM/hhed.reg.cmp.hed
    rm -f ${TMP_DIR}/$AVM/hhed.reg.dur.hed
    echo "LS \"${TMP_DIR}/$AVM/dur.stats\"" >> ${TMP_DIR}/$AVM/hhed.reg.dur.hed
    echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.dur.inf\"" >> ${TMP_DIR}/$AVM/hhed.reg.dur.hed
    echo "DR \"dectree_dur\"" >> ${TMP_DIR}/$AVM/hhed.reg.dur.hed
    #echo "RC 256 \"dectree_dur\"" >> ${TMP_DIR}/$AVM/hhed.reg.dur.hed
    # Make configure file for regression class trees
    # Shrink regression class tree for efficiency 
    echo "SHRINKOCCTHRESH=\"Vector 5 ${treeprune} ${treeprune} ${treeprune} ${treeprune} ${treeprune}\"" > ${TMP_DIR}/$AVM/hhed.conf

    # Make regression class trees
    echo "...Make regression class trees..."
    ${VC_PATH}/HHEd \
        -A \
        -B \
        -C ${MODEL_DIR}/$AVM/config/general.conf \
        -C ${TMP_DIR}/$AVM/hhed.conf \
        -T 1 \
        -D \
        -V \
        -i \
        -p \
        -H ${TMP_DIR}/$AVM/adp.clustered.cmp.mmf \
        -M ${TMP_DIR}/$AVM \
        ${TMP_DIR}/$AVM/hhed.reg.cmp.hed \
        ${TMP_DIR}/$AVM/adp.context.full.list \
        > ${TMP_DIR}/$AVM/hhed.reg.cmp.log &
    ${VC_PATH}/HHEd \
        -A \
        -B \
        -C ${MODEL_DIR}/$AVM/config/general.conf \
        -C ${TMP_DIR}/$AVM/hhed.conf \
        -T 1 \
        -D \
        -V \
        -i \
        -p \
        -H ${TMP_DIR}/$AVM/adp.clustered.dur.mmf \
        -M ${TMP_DIR}/$AVM \
        ${TMP_DIR}/$AVM/hhed.reg.dur.hed \
        ${TMP_DIR}/$AVM/adp.context.full.list \
        > ${TMP_DIR}/$AVM/hhed.reg.dur.log &
    wait

    # Make configure file for speaker adapatation
    echo "...Make configure file for speaker adaptation..."
    rm -f ${TMP_DIR}/$AVM/herest.conf
    echo "MAXSTDDEVCOEF=3" >> ${TMP_DIR}/$AVM/herest.conf
    echo "ADAPTKIND=TREE" >> ${TMP_DIR}/$AVM/herest.conf
    echo "DURADAPTKIND=TREE" >> ${TMP_DIR}/$AVM/herest.conf
    echo "REGTREE=dectree_cmp.tree" >> ${TMP_DIR}/$AVM/herest.conf
    echo "DURREGTREE=dectree_dur.tree" >> ${TMP_DIR}/$AVM/herest.conf
    echo "USEBIAS=T" >> ${TMP_DIR}/$AVM/herest.conf
    echo "DURUSEBIAS=T" >> ${TMP_DIR}/$AVM/herest.conf
    echo "MLLRDIAGCOV=F" >> ${TMP_DIR}/$AVM/herest.conf
    case $linear in 
        "MLLR") 
            echo "TRANSKIND=MLLRMEAN" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "DURTRANSKIND=MLLRMEAN" >> ${TMP_DIR}/$AVM/herest.conf
            echo "USESTRUCTURALPRIOR=F" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "USEMAPLR=F" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "USEVBLR=F" >> ${TMP_DIR}/$AVM/herest.conf ;;
        "SMAPLR") 
            echo "TRANSKIND=MLLRMEAN" >> ${TMP_DIR}/$AVM/herest.conf;
            echo "DURTRANSKIND=MLLRMEAN" >> ${TMP_DIR}/$AVM/herest.conf
            echo "USEMAPLR=T" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "USEVBLR=F" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "USESTRUCTURALPRIOR=T" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "PRIORSCALE=${FLAG_SMAPSIGMA}" >> ${TMP_DIR}/$AVM/herest.conf ;;
        "SVBLR") 
            echo "TRANSKIND=MLLRMEAN" >> ${TMP_DIR}/$AVM/herest.conf;
            echo "DURTRANSKIND=MLLRMEAN" >> ${TMP_DIR}/$AVM/herest.conf
            echo "USEMAPLR=F" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "USEVBLR=T" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "USESTRUCTURALPRIOR=T" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "PRIORSCALE=${FLAG_SMAPSIGMA}" >> ${TMP_DIR}/$AVM/herest.conf ;;
        "CMLLR") 
            echo "TRANSKIND=CMLLR" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "DURTRANSKIND=CMLLR" >> ${TMP_DIR}/$AVM/herest.conf
            echo "USESTRUCTURALPRIOR=F" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "USEMAPLR=F" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "USEVBLR=F" >> ${TMP_DIR}/$AVM/herest.conf ;;
        "CSMAPLR") 
            echo "TRANSKIND=CMLLR" >> ${TMP_DIR}/$AVM/herest.conf;
            echo "DURTRANSKIND=CMLLR" >> ${TMP_DIR}/$AVM/herest.conf
            echo "USEMAPLR=T" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "USEVBLR=F" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "USESTRUCTURALPRIOR=T" >> ${TMP_DIR}/$AVM/herest.conf ;
            echo "PRIORSCALE=${FLAG_SMAPSIGMA}" >> ${TMP_DIR}/$AVM/herest.conf ;;
    esac
    echo "SPLITTHRESH=\"Vector 5 ${mcepthresh} ${f0thresh} ${f0thresh} ${f0thresh} ${bapthresh}\"" >> ${TMP_DIR}/$AVM/herest.conf
    echo "DURSPLITTHRESH=\"Vector 5 ${durthresh} ${durthresh} ${durthresh}  ${durthresh}  ${durthresh}\"" >> ${TMP_DIR}/$AVM/herest.conf
    echo "BLOCKSIZE=\"IntVec 3 ${mcorder} ${mcorder} ${mcorder} IntVec 1 1 IntVec 1 1 IntVec 1 1 IntVec 3 ${baporder} ${baporder} ${baporder}\"" >> ${TMP_DIR}/$AVM/herest.conf
    echo "BANDWIDTH=\"IntVec 3 ${mband} ${mband} ${mband} IntVec 1 1 IntVec 1 1 IntVec 1 1 IntVec 3 ${bband} ${bband} ${bband}\"" >> ${TMP_DIR}/$AVM/herest.conf

    # Speaker adaptation
    echo "...Speaker adaptation..."
    case $linear in 
        "MLLR") 
            echo "...based on MLLR..." ;;
        "SMAPLR") 
            echo "...based on SMAPLR..." ;;
        "SVBLR") 
            echo "...based on SVBLR..." ;;
        "CMLLR") 
            echo "...based on CMLLR..." ;;
        "CSMAPLR") 
            echo "...based on CSMAPLR..." ;;
    esac
    
    rm -f ${TMP_DIR}/$AVM/herest.log
    i=1
    while [ ${i} -le ${FLAG_NITERATION} ]
    do
        echo "...iteration "${i}" of "${FLAG_NITERATION}
        j=`expr ${i} - 1`
        OUT_XFORM_CMP=""
        IN_XFORM_CMP=""
        OUT_XFORM_CMP="-K ${TMP_DIR}/$AVM/xform/cmp feat${i}"
        if [ ${i} -ne 1 ]
        then
            IN_XFORM_CMP="-J ${TMP_DIR}/$AVM/xform/cmp feat${j} -a"
        fi
        
        OUT_XFORM_DUR=""
        IN_XFORM_DUR=""
        if [ ${FLAG_DUR_ADAPTATION} -eq 1 ]
        then
            OUT_XFORM_DUR="-Z ${TMP_DIR}/$AVM/xform/dur feat${i}"
            if [ ${i} -ne 1 ]
            then
                IN_XFORM_DUR="-Y ${TMP_DIR}/$AVM/xform/dur feat${j} -b"
            fi
        fi
        
        OPTION="-u a"
        if [ ${FLAG_DUR_ADAPTATION} -eq 1 ]
        then
            OPTION="-u ada"
        fi
        
        ${VC_PATH}/HERest \
            -A \
            -B \
            -C ${MODEL_DIR}/$AVM/config/general.conf \
            -C ${TMP_DIR}/$AVM/herest.conf \
            -J ${TMP_DIR}/$AVM \
            -Y ${TMP_DIR}/$AVM \
            ${IN_XFORM_CMP} \
            ${IN_XFORM_DUR} \
            ${OUT_XFORM_CMP} \
            ${OUT_XFORM_DUR} \
            -D \
            -T 1 \
            -m 1 \
            -w 3 \
            -h "*.%%%" \
            -S ${TMP_DIR}/$AVM/herest.scp \
            -I ${TMP_DIR}/$AVM/hled.mlf \
            ${OPTION} \
            -H ${TMP_DIR}/$AVM/adp.clustered.cmp.mmf \
            -N ${TMP_DIR}/$AVM/adp.clustered.dur.mmf \
            ${TMP_DIR}/$AVM/adp.context.full.list \
            ${TMP_DIR}/$AVM/adp.context.full.list \
            >> ${TMP_DIR}/$AVM/herest.log
        i=`expr ${i} + 1`
    done

    echo "...Apply transforms to model if model-space transforms are used..."
    if [ $linear = "MLLR" -o $linear = "SMAPLR" -o $linear = "SVBLR" ]
    then
        # Apply linear transforms to model
        rm -f ${TMP_DIR}/$AVM/hhed.cnv.cmp.hed
        echo "AX \"${TMP_DIR}/$AVM/xform/cmp/cmp.feat${FLAG_NITERATION}\"" >> ${TMP_DIR}/$AVM/hhed.cnv.cmp.hed
        echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.mcep.inf\"" >> ${TMP_DIR}/$AVM/hhed.cnv.cmp.hed
        echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.logF0.inf\"" >> ${TMP_DIR}/$AVM/hhed.cnv.cmp.hed
        echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.bndap.inf\"" >> ${TMP_DIR}/$AVM/hhed.cnv.cmp.hed
        echo "CM \"${TMP_DIR}/$AVM/trash\"" >> ${TMP_DIR}/$AVM/hhed.cnv.cmp.hed
        
        CMPTREEARG="-H ${TMP_DIR}/$AVM/dectree_cmp.base -H ${TMP_DIR}/$AVM/dectree_cmp.tree"
        CMP_MMF=${TMP_DIR}/$AVM/adp.clustered.cmp.mmf
        CMPLIST=${TMP_DIR}/$AVM/adp.context.full.list
        OUT_CMP_MMF=${TMP_DIR}/$AVM/map/0/adp.clustered.cmp.mmf
        ${VC_PATH}/HHEd \
            -A \
            -B \
            -C ${MODEL_DIR}/$AVM/config/general.conf \
            -T 1 \
            -D \
            -V \
            -i \
            -p \
            -H ${CMP_MMF} \
            ${CMPTREEARG} \
            -w ${OUT_CMP_MMF} \
            ${TMP_DIR}/$AVM/hhed.cnv.cmp.hed \
            ${CMPLIST} \
            > ${TMP_DIR}/$AVM/hhed.cnv.cmp.log &
        
        if [ ${FLAG_DUR_ADAPTATION} -eq 1 ]
        then
            # Apply linear transforms to model
            rm -f ${TMP_DIR}/$AVM/hhed.cnv.dur.hed
            echo "AX \"${TMP_DIR}/$AVM/xform/dur/cmp.feat${FLAG_NITERATION}\"" >> ${TMP_DIR}/$AVM/hhed.cnv.dur.hed
            echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.dur.inf\"" >> ${TMP_DIR}/$AVM/hhed.cnv.dur.hed
            echo "CM \"${TMP_DIR}/$AVM/trash\"" >> ${TMP_DIR}/$AVM/hhed.cnv.dur.hed
            
            DURTREEARG="-H ${TMP_DIR}/$AVM/dectree_dur.base -H ${TMP_DIR}/$AVM/dectree_dur.tree"
            DUR_MMF=${TMP_DIR}/$AVM/adp.clustered.dur.mmf
            DURLIST=${TMP_DIR}/$AVM/adp.context.full.list
            OUT_DUR_MMF=${TMP_DIR}/$AVM/map/0/adp.clustered.dur.mmf
            ${VC_PATH}/HHEd \
                -A \
                -B \
                -C ${MODEL_DIR}/$AVM/config/general.conf \
                -T 1 \
                -D \
                -V \
                -i \
                -p \
                -H ${DUR_MMF} \
                ${DURTREEARG} \
                -w ${OUT_DUR_MMF} \
                ${TMP_DIR}/$AVM/hhed.cnv.dur.hed \
                ${DURLIST} \
                > ${TMP_DIR}/$AVM/hhed.cnv.duration.log & 
        else
            # Just copy 
            DUR_MMF=${TMP_DIR}/$AVM/adp.clustered.dur.mmf
            OUT_DUR_MMF=${TMP_DIR}/$AVM/map/0/adp.clustered.dur.mmf
            cp ${DUR_MMF} ${OUT_DUR_MMF} & 
        fi
        wait
    else
        # Just copy 
        CMP_MMF=${TMP_DIR}/$AVM/adp.clustered.cmp.mmf
        DUR_MMF=${TMP_DIR}/$AVM/adp.clustered.dur.mmf
        OUT_CMP_MMF=${TMP_DIR}/$AVM/map/0/adp.clustered.cmp.mmf
        OUT_DUR_MMF=${TMP_DIR}/$AVM/map/0/adp.clustered.dur.mmf
        cp ${CMP_MMF} ${OUT_CMP_MMF} & 
        cp ${DUR_MMF} ${OUT_DUR_MMF} & 
        wait
    fi
    
    echo "...Conduct MAP adaptation further..."
    # Creat a config file for MAP 
    rm -f ${TMP_DIR}/$AVM/map.conf
    echo "MAPTAU              = ${maptau}" >> ${TMP_DIR}/$AVM/map.conf
    echo "DURMAPTAU           = ${maptau}" >> ${TMP_DIR}/$AVM/map.conf
    echo "HMAP:MIXWEIGHTFLOOR = 3"  >> ${TMP_DIR}/$AVM/map.conf
    
    rm -f ${TMP_DIR}/$AVM/herest-map.log
    OPTION="-u mvwp"
    if [ ${FLAG_DUR_ADAPTATION} -eq 1 ]
    then
        OPTION="-u mvwpdmvp"
    fi
    
    i=1
    while [ ${i} -le ${FLAG_NITERATION} ]
    do
        echo "...iteration "${i}" of "${FLAG_NITERATION}
        mkdir -p ${TMP_DIR}/$AVM/map/${i}
        j=`expr ${i} - 1`
        
        IN_XFORM_CMP=""
        if [ $linear = "CMLLR" -o $linear = "CSMAPLR" ]
        then
            IN_XFORM_CMP="-J ${TMP_DIR}/$AVM -J ${TMP_DIR}/$AVM/xform/cmp feat${FLAG_NITERATION} -E ${TMP_DIR}/$AVM/xform/cmp feat${FLAG_NITERATION} -a"
        fi
        
        IN_XFORM_DUR=""
        if [ ${FLAG_DUR_ADAPTATION} -eq 1 ]
        then
            if [ $linear = "CMLLR" -o $linear = "CSMAPLR" ]
            then
                IN_XFORM_DUR="-Y ${TMP_DIR}/$AVM -Y ${TMP_DIR}/$AVM/xform/dur feat${FLAG_NITERATION} -W ${TMP_DIR}/$AVM/xform/dur feat${FLAG_NITERATION} -b"
            fi
        fi
        
        rm -f ${TMP_DIR}/$AVM/herest.scp.*
        cat ${TMP_DIR}/$AVM/herest.scp | ${VC_PATH}/parallel -k -j +0 -X -I {} \
            "echo {} | perl -pe 's/ /\n/g' > ${TMP_DIR}/$AVM/herest.scp.{#} ; \
            ${VC_PATH}/HERest \
            -A \
            -B \
            -C ${MODEL_DIR}/$AVM/config/general.conf \
            -C ${TMP_DIR}/$AVM/map.conf \
            -C ${TMP_DIR}/$AVM/herest.conf \
            ${IN_XFORM_CMP} \
            ${IN_XFORM_DUR} \
            -D \
            -S ${TMP_DIR}/$AVM/herest.scp.{#} \
            -T 1 \
            -I ${TMP_DIR}/$AVM/hled.mlf \
            -m 0 ${OPTION} \
            -w 3 \
            -h \"*.%%%\" \
            -p {#} \
            -H ${TMP_DIR}/$AVM/map/${j}/adp.clustered.cmp.mmf \
            -N ${TMP_DIR}/$AVM/map/${j}/adp.clustered.dur.mmf \
            -M ${TMP_DIR}/$AVM/map/${i}/ \
            -R ${TMP_DIR}/$AVM/map/${i}/ \
            ${TMP_DIR}/$AVM/adp.context.full.list \
            ${TMP_DIR}/$AVM/adp.context.full.list" \
            > ${TMP_DIR}/$AVM/herest-map.${i}.log
    
        find -L ${TMP_DIR}/$AVM/map/${i}/ -name '*.acc' -print \
            | sort > ${TMP_DIR}/$AVM/map/${i}/AccList
        ${VC_PATH}/HERest \
            -A \
            -B \
            -C ${MODEL_DIR}/$AVM/config/general.conf \
            -C ${TMP_DIR}/$AVM/map.conf \
            -D \
            -T 1 \
            -S ${TMP_DIR}/$AVM/map/${i}/AccList \
            -I ${TMP_DIR}/$AVM/hled.mlf \
            -m 0 ${OPTION} \
            -w 3 \
            -p 0 \
            -H ${TMP_DIR}/$AVM/map/${j}/adp.clustered.cmp.mmf \
            -N ${TMP_DIR}/$AVM/map/${j}/adp.clustered.dur.mmf \
            -M ${TMP_DIR}/$AVM/map/${i}/ \
            -R ${TMP_DIR}/$AVM/map/${i}/ \
            ${TMP_DIR}/$AVM/adp.context.full.list \
            ${TMP_DIR}/$AVM/adp.context.full.list \
            > ${TMP_DIR}/$AVM/herest-map.${i}.0.log
        i=`expr ${i} + 1`
    done


    echo "...Make HED file to convert hts_engine format..."
    mkdir -p ${INTER_OUTPUT_ENGINE}/clusters/$AVM
    rm -f ${TMP_DIR}/$AVM/hhed.cnv.mcep.hed
    if [ $linear = "CMLLR" -o $linear = "CSMAPLR" ]
    then
        echo "AX \"${TMP_DIR}/$AVM/xform/cmp/cmp.feat${FLAG_NITERATION}\"" >> ${TMP_DIR}/$AVM/hhed.cnv.mcep.hed
    fi
    echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.mcep.inf\"" >> ${TMP_DIR}/$AVM/hhed.cnv.mcep.hed
    echo "CT \"${INTER_OUTPUT_ENGINE}/clusters/$AVM\"" >> ${TMP_DIR}/$AVM/hhed.cnv.mcep.hed
    echo "CM \"${INTER_OUTPUT_ENGINE}/clusters/$AVM\"" >> ${TMP_DIR}/$AVM/hhed.cnv.mcep.hed
    
    rm -f ${TMP_DIR}/$AVM/hhed.cnv.logF0.hed
    if [ $linear = "CMLLR" -o $linear = "CSMAPLR" ]
    then
        echo "AX \"${TMP_DIR}/$AVM/xform/cmp/cmp.feat${FLAG_NITERATION}\"" >> ${TMP_DIR}/$AVM/hhed.cnv.logF0.hed
    fi
    echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.logF0.inf\"" >> ${TMP_DIR}/$AVM/hhed.cnv.logF0.hed
    echo "CT \"${INTER_OUTPUT_ENGINE}/clusters/$AVM\"" >> ${TMP_DIR}/$AVM/hhed.cnv.logF0.hed
    echo "CM \"${INTER_OUTPUT_ENGINE}/clusters/$AVM\"" >> ${TMP_DIR}/$AVM/hhed.cnv.logF0.hed
    
    rm -f ${TMP_DIR}/$AVM/hhed.cnv.bndap.hed
    if [ $linear = "CMLLR" -o $linear = "CSMAPLR" ]
    then
        echo "AX \"${TMP_DIR}/$AVM/xform/cmp/cmp.feat${FLAG_NITERATION}\"" >> ${TMP_DIR}/$AVM/hhed.cnv.bndap.hed
    fi
    echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.bndap.inf\"" >> ${TMP_DIR}/$AVM/hhed.cnv.bndap.hed
    echo "CT \"${INTER_OUTPUT_ENGINE}/clusters/$AVM\"" >> ${TMP_DIR}/$AVM/hhed.cnv.bndap.hed
    echo "CM \"${INTER_OUTPUT_ENGINE}/clusters/$AVM\"" >> ${TMP_DIR}/$AVM/hhed.cnv.bndap.hed
    
    rm -f ${TMP_DIR}/$AVM/hhed.cnv.dur.hed
    if [ ${FLAG_DUR_ADAPTATION} -eq 1 ]
    then
        if [ $linear = "CMLLR" -o $linear = "CSMAPLR" ]
        then
            echo "AX \"${TMP_DIR}/$AVM/xform/dur/cmp.feat${FLAG_NITERATION}\"" >> ${TMP_DIR}/$AVM/hhed.cnv.dur.hed
        fi
    fi
    echo "LT \"${MODEL_DIR}/$AVM/hmm/tree.dur.inf\"" >> ${TMP_DIR}/$AVM/hhed.cnv.dur.hed
    echo "CT \"${INTER_OUTPUT_ENGINE}/clusters/$AVM\"" >> ${TMP_DIR}/$AVM/hhed.cnv.dur.hed
    echo "CM \"${INTER_OUTPUT_ENGINE}/clusters/$AVM\"" >> ${TMP_DIR}/$AVM/hhed.cnv.dur.hed
    
    # Convert models to hts_engine format
    echo "...Convert models to hts_engine format..."
    if [ $linear = "CMLLR" -o $linear = "CSMAPLR" ]
    then
        CMPTREEARG="-H ${TMP_DIR}/$AVM/dectree_cmp.base -H ${TMP_DIR}/$AVM/dectree_cmp.tree"
        DURTREEARG="-H ${TMP_DIR}/$AVM/dectree_dur.base -H ${TMP_DIR}/$AVM/dectree_dur.tree"
    else
        CMPTREEARG=""
        DURTREEARG=""
    fi
    CMPLIST=${TMP_DIR}/$AVM/adp.context.full.list
    DURLIST=${TMP_DIR}/$AVM/adp.context.full.list
    CMP_MMF=${TMP_DIR}/$AVM/map/${FLAG_NITERATION}/adp.clustered.cmp.mmf
    DUR_MMF=${TMP_DIR}/$AVM/map/${FLAG_NITERATION}/adp.clustered.dur.mmf
    ${VC_PATH}/HHEd \
        -A \
        -B \
        -C ${MODEL_DIR}/$AVM/config/general.conf \
        -T 1 \
        -D \
        -V \
        -H ${CMP_MMF} \
        ${CMPTREEARG} \
        -w ${TMP_DIR}/$AVM/test.mmf \
        -i \
        -p \
        ${TMP_DIR}/$AVM/hhed.cnv.mcep.hed \
        ${CMPLIST} \
        > ${TMP_DIR}/$AVM/hhed.cnv.mcep.log &
    ${VC_PATH}/HHEd \
        -A \
        -B \
        -C ${MODEL_DIR}/$AVM/config/general.conf \
        -T 1 \
        -D \
        -V \
        -H ${CMP_MMF} \
        ${CMPTREEARG} \
        -w ${TMP_DIR}/$AVM/test.mmf \
        -i \
        -p \
        ${TMP_DIR}/$AVM/hhed.cnv.logF0.hed \
        ${CMPLIST} \
        > ${TMP_DIR}/$AVM/hhed.cnv.logF0.log &
    ${VC_PATH}/HHEd \
        -A \
        -B \
        -C ${MODEL_DIR}/$AVM/config/general.conf \
        -T 1 \
        -D \
        -V \
        -H ${CMP_MMF} \
        ${CMPTREEARG} \
        -w ${TMP_DIR}/$AVM/test.mmf \
        -i \
        -p \
        ${TMP_DIR}/$AVM/hhed.cnv.bndap.hed \
        ${CMPLIST} \
        > ${TMP_DIR}/$AVM/hhed.cnv.bndap.log &
    wait

    mv ${INTER_OUTPUT_ENGINE}/clusters/$AVM/trees.1 \
        ${INTER_OUTPUT_ENGINE}/clusters/$AVM/tree-mcep.inf \
        || { echo "adaptation failed" ; exit 1; } 
    mv ${INTER_OUTPUT_ENGINE}/clusters/$AVM/pdf.1 \
        ${INTER_OUTPUT_ENGINE}/clusters/$AVM/mcep.pdf \
        || { echo "adaptation failed" ; exit 1; } 
    mv ${INTER_OUTPUT_ENGINE}/clusters/$AVM/trees.2 \
        ${INTER_OUTPUT_ENGINE}/clusters/$AVM/tree-logF0.inf \
        || { echo "adaptation failed" ; exit 1; } 
    mv ${INTER_OUTPUT_ENGINE}/clusters/$AVM/pdf.2 \
        ${INTER_OUTPUT_ENGINE}/clusters/$AVM/logF0.pdf \
        || { echo "adaptation failed" ; exit 1; } 
    mv ${INTER_OUTPUT_ENGINE}/clusters/$AVM/trees.5 \
        ${INTER_OUTPUT_ENGINE}/clusters/$AVM/tree-bndap.inf \
        || { echo "adaptation failed" ; exit 1; } 
    mv ${INTER_OUTPUT_ENGINE}/clusters/$AVM/pdf.5 \
        ${INTER_OUTPUT_ENGINE}/clusters/$AVM/bndap.pdf \
        || { echo "adaptation failed" ; exit 1; } 
    
    ${VC_PATH}/HHEd \
        -A \
        -B \
        -C ${MODEL_DIR}/$AVM/config/general.conf \
        -T 1 \
        -D \
        -V \
        -H ${DUR_MMF} \
        ${DURTREEARG} \
        -w ${TMP_DIR}/$AVM/test.mmf \
        -i \
        -p \
        ${TMP_DIR}/$AVM/hhed.cnv.dur.hed \
        ${DURLIST} \
        > ${TMP_DIR}/$AVM/hhed.cnv.dur.log
    mv ${INTER_OUTPUT_ENGINE}/clusters/$AVM/trees.1 \
        ${INTER_OUTPUT_ENGINE}/clusters/$AVM/tree-duration.inf \
        || { echo "adaptation failed" ; exit 1; } 
    mv ${INTER_OUTPUT_ENGINE}/clusters/$AVM/pdf.1 \
        ${INTER_OUTPUT_ENGINE}/clusters/$AVM/duration-2.2.pdf \
        || { echo "adaptation failed" ; exit 1; } 
    
    # Convert Duration format to 2.1 format 
    rm -f ${TMP_DIR}/$AVM/dur.head ${TMP_DIR}/$AVM/var ${TMP_DIR}/$AVM/mean
    ${VC_PATH}/bcut +i -e 1 ${INTER_OUTPUT_ENGINE}/clusters/$AVM/duration-2.2.pdf \
        > ${TMP_DIR}/$AVM/dur.head
    ${VC_PATH}/bcut -s 2 ${INTER_OUTPUT_ENGINE}/clusters/$AVM/duration-2.2.pdf \
        | ${VC_PATH}/x2x -o +fa2 \
        | awk '{print $2}' \
        | ${VC_PATH}/x2x -o +af \
        >  ${TMP_DIR}/$AVM/var
    ${VC_PATH}/bcut -s 2 ${INTER_OUTPUT_ENGINE}/clusters/$AVM/duration-2.2.pdf \
        | ${VC_PATH}/x2x -o +fa2 \
        | awk '{print $1}' \
        | ${VC_PATH}/x2x -o +af \
        >  ${TMP_DIR}/$AVM/mean 
    ${VC_PATH}/merge +f -s 5 -l 5 -L 5 ${TMP_DIR}/$AVM/var < ${TMP_DIR}/$AVM/mean \
        | cat ${TMP_DIR}/$AVM/dur.head - \
        > ${INTER_OUTPUT_ENGINE}/clusters/$AVM/duration.pdf
    
    if [ ${FLAG_HTK_MODELS} -eq 1 ]
    then
        echo "...save HTK models..."
        mkdir -p ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk
        if [ $linear = "CMLLR" -o $linear = "CSMAPLR" ]
        then
            cp ${TMP_DIR}/$AVM/xform/cmp/cmp.feat${FLAG_NITERATION} ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/cmp.feat
            cp ${TMP_DIR}/$AVM/xform/dur/cmp.feat${FLAG_NITERATION} ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/dur.feat
            cp ${TMP_DIR}/$AVM/dectree_cmp.base ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/
            cp ${TMP_DIR}/$AVM/dectree_cmp.tree ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/
            cp ${TMP_DIR}/$AVM/dectree_dur.base ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/
            cp ${TMP_DIR}/$AVM/dectree_dur.tree ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/
        fi
        cp ${MODEL_DIR}/$AVM/hmm/tree.mcep.inf  ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/
        cp ${MODEL_DIR}/$AVM/hmm/tree.logF0.inf ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/
        cp ${MODEL_DIR}/$AVM/hmm/tree.bndap.inf ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/
        cp ${MODEL_DIR}/$AVM/hmm/tree.dur.inf   ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/
        cp ${TMP_DIR}/$AVM/adp.context.full.list ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/
        cp ${TMP_DIR}/$AVM/map/${FLAG_NITERATION}/adp.clustered.cmp.mmf ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/
        cp ${TMP_DIR}/$AVM/map/${FLAG_NITERATION}/adp.clustered.dur.mmf ${INTER_OUTPUT_ENGINE}/clusters/$AVM/htk/
    fi
done


# Selection of the best AVM based on likelihood 
rm -rf ${TMP_DIR}/model-selection.list
for AVM in ${AVMS[@]}
do
    likelihood=`grep "average log prob per frame" ${TMP_DIR}/$AVM/herest-map.${FLAG_NITERATION}.0.log | awk '{print $NF}'`
    echo $likelihood $AVM >> ${TMP_DIR}/model-selection.list
done
bestAVM=`sort -r ${TMP_DIR}/model-selection.list | head -1  | awk '{print $NF}'`
echo "...The best AVM is $bestAVM..."

# Save the information of average voice models and their likelihood 
rm -f ${INTER_OUTPUT_ENGINE}/clusters/info.txt
echo "...The best AVM that has highest likelihood is $bestAVM..." > ${INTER_OUTPUT_ENGINE}/clusters/info.txt
cat ${TMP_DIR}/model-selection.list >> ${INTER_OUTPUT_ENGINE}/clusters/info.txt

echo "...Copy hts_engine files generated from the best AVM $bestAVM..." 
# Copy acoustic models and decision trees 
cp -r ${INTER_OUTPUT_ENGINE}/clusters/$bestAVM/*.pdf ${INTER_OUTPUT_ENGINE}/
cp -r ${INTER_OUTPUT_ENGINE}/clusters/$bestAVM/*.inf ${INTER_OUTPUT_ENGINE}/


# Apply the optimal interpolation of the multiple AVMs to further refine acoustic models 
if [ ${FLAG_INTERPOLATION} -eq 1 ]
then
    echo "...AVM interpolation..."
    for AVM in ${AVMS[@]}
    do
        mkdir -p ${TMP_DIR}/$AVM/trimmed
        # Make HED file for trimmed unseen models
        echo "...Make HED file for trimmed unseen models..."
        rm -f ${TMP_DIR}/$AVM/trimmed/hhed.mku.cmp.hed
        echo "LT ${MODEL_DIR}/$AVM/hmm/tree.mcep.inf"  >> ${TMP_DIR}/$AVM/trimmed/hhed.mku.cmp.hed
        echo "LT ${MODEL_DIR}/$AVM/hmm/tree.logF0.inf" >> ${TMP_DIR}/$AVM/trimmed/hhed.mku.cmp.hed
        echo "LT ${MODEL_DIR}/$AVM/hmm/tree.bndap.inf" >> ${TMP_DIR}/$AVM/trimmed/hhed.mku.cmp.hed
        echo "AU ${TMP_DIR}/$AVM/adp.context.list"     >> ${TMP_DIR}/$AVM/trimmed/hhed.mku.cmp.hed
        rm -f ${TMP_DIR}/$AVM/trimmed/hhed.mku.dur.hed
        echo "LT ${MODEL_DIR}/$AVM/hmm/tree.dur.inf"   >> ${TMP_DIR}/$AVM/trimmed/hhed.mku.dur.hed
        echo "AU ${TMP_DIR}/$AVM/adp.context.list"     >> ${TMP_DIR}/$AVM/trimmed/hhed.mku.dur.hed

        # Prepare unseen models
        echo "...Prepare unseen models..."
        ${VC_PATH}/HHEd \
            -A \
            -B \
            -C ${MODEL_DIR}/$AVM/config/general.conf \
            -T 1 \
            -D \
            -V \
            -i \
            -p \
            -H ${TMP_DIR}/$AVM/map/${FLAG_NITERATION}/adp.clustered.cmp.mmf \
            -w ${TMP_DIR}/$AVM/trimmed/adp.clustered.cmp.mmf \
            ${TMP_DIR}/$AVM/trimmed/hhed.mku.cmp.hed \
            ${TMP_DIR}/$AVM/adp.context.full.list \
            > ${TMP_DIR}/$AVM/trimmed/hhed.mku.cmp.log &
        ${VC_PATH}/HHEd \
            -A \
            -B \
            -C ${MODEL_DIR}/$AVM/config/general.conf \
            -T 1 \
            -D \
            -V \
            -i \
            -p \
            -H ${TMP_DIR}/$AVM/map/${FLAG_NITERATION}/adp.clustered.dur.mmf \
            -w ${TMP_DIR}/$AVM/trimmed/adp.clustered.dur.mmf \
            ${TMP_DIR}/$AVM/trimmed/hhed.mku.dur.hed \
            ${TMP_DIR}/$AVM/adp.context.full.list \
            > ${TMP_DIR}/$AVM/trimmed/hhed.mku.dur.log &
        wait
    done
    
    # Make stats file for regression class trees
    echo "...Make stats file for regression class trees..."
    perl ${SCRIPT_DIR}/make_stats.pl \
        ${TMP_DIR}/$bestAVM/adp.context.list \
        ${TMP_DIR}/$bestAVM/adp.context.list \
        ${TMP_DIR}/$bestAVM/trimmed/cmp.stats \
        ${TMP_DIR}/$bestAVM/trimmed/dur.stats

    # Make HED file for regression class trees
    echo "...Make HED file for regression class trees..."
    rm -f ${TMP_DIR}/$bestAVM/trimmed/hhed.reg.cmp.hed
    echo "LS \"${TMP_DIR}/$bestAVM/trimmed/cmp.stats\"" >> ${TMP_DIR}/$bestAVM/trimmed/hhed.reg.cmp.hed
    echo "RC 128 \"dectree_cmp\" "                      >> ${TMP_DIR}/$bestAVM/trimmed/hhed.reg.cmp.hed
    rm -f ${TMP_DIR}/$bestAVM/trimmed/hhed.reg.dur.hed
    echo "LS \"${TMP_DIR}/$bestAVM/trimmed/dur.stats\"" >> ${TMP_DIR}/$bestAVM/trimmed/hhed.reg.dur.hed
    echo "RC 128 \"dectree_dur\""                       >> ${TMP_DIR}/$bestAVM/trimmed/hhed.reg.dur.hed

    # Make regression class trees
    echo "...Make regression class trees..."
    ${VC_PATH}/HHEd \
        -A \
        -B \
        -C ${MODEL_DIR}/$bestAVM/config/general.conf \
        -T 1 \
        -D \
        -V \
        -i \
        -p \
        -H ${TMP_DIR}/$bestAVM/trimmed/adp.clustered.cmp.mmf \
        -M ${TMP_DIR}/$bestAVM/trimmed/ \
        ${TMP_DIR}/$bestAVM/trimmed/hhed.reg.cmp.hed \
        ${TMP_DIR}/$bestAVM/adp.context.list \
        > ${TMP_DIR}/$bestAVM/trimmed/hhed.reg.cmp.log &
    ${VC_PATH}/HHEd \
        -A \
        -B \
        -C ${MODEL_DIR}/$bestAVM/config/general.conf \
        -T 1 \
        -D \
        -V \
        -i \
        -p \
        -H ${TMP_DIR}/$bestAVM/trimmed/adp.clustered.dur.mmf \
        -M ${TMP_DIR}/$bestAVM/trimmed/ \
        ${TMP_DIR}/$bestAVM/trimmed/hhed.reg.dur.hed \
        ${TMP_DIR}/$bestAVM/adp.context.list \
        > ${TMP_DIR}/$bestAVM/trimmed/hhed.reg.dur.log &
    wait

#    # make regression base class files (this is hard coded!!)
#    rm -f >> ${TMP_DIR}/regclass_cmp.base
#    echo "~b \"regclass_cmp.base\"" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<MMFIDMASK> *" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<PARAMETERS> MIXBASE" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<STREAMINFO>  5 180 1 1 1 75" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<NUMCLASSES> 8" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<CLASS> 1 {*.state[2-6].stream[1].mix[1]}" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<CLASS> 2 {*.state[2-6].stream[2].mix[1]}" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<CLASS> 3 {*.state[2-6].stream[2].mix[2]}" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<CLASS> 4 {*.state[2-6].stream[3].mix[1]}" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<CLASS> 5 {*.state[2-6].stream[3].mix[2]}" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<CLASS> 6 {*.state[2-6].stream[4].mix[1]}" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<CLASS> 7 {*.state[2-6].stream[4].mix[2]}" >> ${TMP_DIR}/regclass_cmp.base
#    echo "<CLASS> 8 {*.state[2-6].stream[5].mix[1]}" >> ${TMP_DIR}/regclass_cmp.base
#
#    rm -f >> ${TMP_DIR}/regclass_dur.base
#    echo "~b \"regclass_dur.base\"" >> ${TMP_DIR}/regclass_dur.base
#    echo "<MMFIDMASK> *" >> ${TMP_DIR}/regclass_dur.base
#    echo "<PARAMETERS> MIXBASE" >> ${TMP_DIR}/regclass_dur.base
#    echo "<STREAMINFO>  5 1 1 1 1 1" >> ${TMP_DIR}/regclass_dur.base
#    echo "<NUMCLASSES> 5" >> ${TMP_DIR}/regclass_dur.base
#    echo "<CLASS> 1 {*.state[2-6].stream[1].mix[1]}" >> ${TMP_DIR}/regclass_dur.base
#    echo "<CLASS> 2 {*.state[2-6].stream[2].mix[1]}" >> ${TMP_DIR}/regclass_dur.base
#    echo "<CLASS> 3 {*.state[2-6].stream[3].mix[1]}" >> ${TMP_DIR}/regclass_dur.base
#    echo "<CLASS> 4 {*.state[2-6].stream[4].mix[1]}" >> ${TMP_DIR}/regclass_dur.base
#    echo "<CLASS> 5 {*.state[2-6].stream[5].mix[1]}" >> ${TMP_DIR}/regclass_dur.base

    echo "...Prepare configure files required for optimal/trimmed..."
    rm -f ${TMP_DIR}/auxAvm_cmp.list ${TMP_DIR}/auxAvm_dur.list
    echo "<NUMAUXMMF> ${#AVMS[@]}" >> ${TMP_DIR}/auxAvm_cmp.list
    echo "<NUMAUXMMF> ${#AVMS[@]}" >> ${TMP_DIR}/auxAvm_dur.list
    i=1
    for AVM in ${AVMS[@]}
    do 
        echo "<MMF${i}> ${TMP_DIR}/$AVM/trimmed/adp.clustered.cmp.mmf" >> ${TMP_DIR}/auxAvm_cmp.list
        echo "<MMF${i}> ${TMP_DIR}/$AVM/trimmed/adp.clustered.dur.mmf" >> ${TMP_DIR}/auxAvm_dur.list
        i=`expr ${i} + 1`
    done

    likelihoodsum=`awk 'BEGIN{SUM=0}{SUM+=$1}END{print SUM}' ${TMP_DIR}/model-selection.list`
    rm -f ${TMP_DIR}/auxAvm_cmp.wgt ${TMP_DIR}/auxAvm_dur.wgt
    echo "<NUMAUXMMF> ${#AVMS[@]}" >> ${TMP_DIR}/auxAvm_cmp.wgt
    echo "<NUMAUXMMF> ${#AVMS[@]}" >> ${TMP_DIR}/auxAvm_dur.wgt
    echo "<NUMSTREAM> 5" >> ${TMP_DIR}/auxAvm_cmp.wgt
    echo "<NUMSTREAM> 5" >> ${TMP_DIR}/auxAvm_dur.wgt
    i=1
    for AVM in ${AVMS[@]}
    do 
        initweight=`grep $AVM ${TMP_DIR}/model-selection.list | awk '{printf "%.3f",$1/'$likelihoodsum'}'`
        echo "<MMF${i}> $initweight $initweight $initweight $initweight $initweight" >> ${TMP_DIR}/auxAvm_cmp.wgt
        echo "<MMF${i}> $initweight $initweight $initweight $initweight $initweight" >> ${TMP_DIR}/auxAvm_dur.wgt
        i=`expr ${i} + 1`
    done
    
    rm -rf ${TMP_DIR}/herest-interpolate.conf
    echo "MAXSTDDEVCOEF=10"                          >> ${TMP_DIR}/herest-interpolate.conf
    echo "ADAPTKIND=TREE"                            >> ${TMP_DIR}/herest-interpolate.conf
    echo "DURADAPTKIND=TREE"                         >> ${TMP_DIR}/herest-interpolate.conf
    echo "REGTREE=dectree_cmp.tree"                  >> ${TMP_DIR}/herest-interpolate.conf
    echo "DURREGTREE=dectree_dur.tree"               >> ${TMP_DIR}/herest-interpolate.conf
    echo "AUXMMFCMPLIST=${TMP_DIR}/auxAvm_cmp.list"  >> ${TMP_DIR}/herest-interpolate.conf
    echo "AUXMMFDURLIST=${TMP_DIR}/auxAvm_dur.list"  >> ${TMP_DIR}/herest-interpolate.conf
    echo "AUXAVMWEIGHTCMP=${TMP_DIR}/auxAvm_cmp.wgt" >> ${TMP_DIR}/herest-interpolate.conf
    echo "AUXAVMWEIGHTDUR=${TMP_DIR}/auxAvm_dur.wgt" >> ${TMP_DIR}/herest-interpolate.conf
    echo "TRANSKIND=CMLLR"                           >> ${TMP_DIR}/herest-interpolate.conf
    echo "USEBIAS=T"                                 >> ${TMP_DIR}/herest-interpolate.conf
    echo "DURTRANSKIND=CMLLR"                        >> ${TMP_DIR}/herest-interpolate.conf
    echo "DURUSEBIAS=T"                              >> ${TMP_DIR}/herest-interpolate.conf
    echo "MLLRDIAGCOV=F"                             >> ${TMP_DIR}/herest-interpolate.conf
    echo "BLOCKSIZE=\"IntVec 3 ${mcorder} ${mcorder} ${mcorder} IntVec 1 1 IntVec 1 1 IntVec 1 1 IntVec 3 ${baporder} ${baporder} ${baporder}\"" >> ${TMP_DIR}/herest-interpolate.conf

    i=1
    rm -rf ${TMP_DIR}/herest-interpolate.${i}.log
    while [ ${i} -le ${FLAG_NITERATION} ]
    do
        echo "...iteration "${i}" of "${FLAG_NITERATION}
        j=`expr ${i} - 1`
        OPTION="-u a"
        if [ ${FLAG_DUR_ADAPTATION} -eq 1 ]
        then
            OPTION="-u ada"
        fi
        ${VC_PATH}/HERest_Interp \
            -A \
            -B \
            -C ${MODEL_DIR}/$bestAVM/config/general.conf \
            -C ${TMP_DIR}/herest-interpolate.conf \
            -D \
            -T 1 \
            -m 1 \
            -w 3 \
            -t 1000 100 5000 \
            -S ${TMP_DIR}/$bestAVM/herest.scp \
            -I ${TMP_DIR}/$bestAVM/hled.mlf \
            ${OPTION} \
            -J ${TMP_DIR}/$bestAVM/trimmed/ \
            -Y ${TMP_DIR}/$bestAVM/trimmed/ \
            -H ${TMP_DIR}/$bestAVM/trimmed/adp.clustered.cmp.mmf \
            -N ${TMP_DIR}/$bestAVM/trimmed/adp.clustered.dur.mmf \
            -M ${TMP_DIR} \
            ${TMP_DIR}/$bestAVM/adp.context.list \
            ${TMP_DIR}/$bestAVM/adp.context.list \
            > ${TMP_DIR}/herest-interpolate.${i}.log
        i=`expr ${i} + 1`
    done
    cp ${TMP_DIR}/auxAvm_cmp.wgt ${INTER_OUTPUT_ENGINE}/clusters/
    cp ${TMP_DIR}/auxAvm_dur.wgt ${INTER_OUTPUT_ENGINE}/clusters/
    rm -f ${INTER_OUTPUT_ENGINE}/clusters/modelspath.list
    echo "<NUMAUXMMF> ${#AVMS[@]}" >> ${INTER_OUTPUT_ENGINE}/clusters/modelspath.list
    i=1
    for AVM in ${AVMS[@]}
    do 
        echo "<MMF${i}> ${INTER_OUTPUT_ENGINE}/clusters/$AVM" >> ${INTER_OUTPUT_ENGINE}/clusters/modelspath.list
        i=`expr ${i} + 1`
    done

fi

# Obtain time alignment information for further processing later
echo "...Add time alignment information for further processing later..."
if [ $linear = "CMLLR" -o $linear = "CSMAPLR" ]
then
    IN_XFORM_CMP="-C ${TMP_DIR}/$bestAVM/herest.conf -J ${TMP_DIR}/$bestAVM -J ${TMP_DIR}/$bestAVM/xform/cmp feat${FLAG_NITERATION} -a"
    IN_XFORM_DUR=""
    if [ ${FLAG_DUR_ADAPTATION} -eq 1 ]
    then
        IN_XFORM_DUR="-Y ${TMP_DIR}/$bestAVM -Y ${TMP_DIR}/$bestAVM/xform/dur feat${FLAG_NITERATION} -b"
    fi
else
    IN_XFORM_CMP=""
    IN_XFORM_DUR=""
fi
CMP_MMF=${TMP_DIR}/$bestAVM/map/${FLAG_NITERATION}/adp.clustered.cmp.mmf
DUR_MMF=${TMP_DIR}/$bestAVM/map/${FLAG_NITERATION}/adp.clustered.dur.mmf

rm -f ${TMP_DIR}/$bestAVM/herest.scp.*
cat ${TMP_DIR}/$bestAVM/herest.scp | ${VC_PATH}/parallel -k -j +0 -X -I {} \
    "echo {} | perl -pe 's/ /\n/g' > ${TMP_DIR}/$bestAVM/herest.scp.{#} ; \
    ${VC_PATH}/HAlign \
    -A \
    -T 1 \
    -D \
    -V \
    -C ${MODEL_DIR}/$bestAVM/config/general.conf \
    -H ${CMP_MMF} \
    -N ${DUR_MMF} \
    -I ${TMP_DIR}/$bestAVM/hled.mlf \
    -S ${TMP_DIR}/$bestAVM/herest.scp.{#} \
    -t 3000 \
    -w 1.0 \
    -h \"*.%%%\" \
    -m ${INTER_OUTPUT_ALIGN} \
    ${IN_XFORM_CMP} \
    ${IN_XFORM_DUR} \
    ${TMP_DIR}/$bestAVM/adp.context.full.list \
    ${TMP_DIR}/$bestAVM/adp.context.full.list" \
    > ${INTER_OUTPUT_ALIGN}/align.log

echo "...train context-dependent GV models..."
rm -rf ${INTER_OUTPUT_ENGINE}/cdgv
find -L ${INTER_INPUT_GV} -name '*.cmp' > ${TMP_DIR}/$bestAVM/train.gv.cmp
find -L ${INTER_INPUT_FLABEL} -name '*.gvlab' > ${TMP_DIR}/$bestAVM/train.gv.lab
perl ${SCRIPT_DIR}/ContextGV-Training.pl \
    -data ${TMP_DIR}/$bestAVM/train.gv.cmp \
    -lab ${TMP_DIR}/$bestAVM/train.gv.lab \
    -out ${TMP_DIR}/$bestAVM/cdgv \
    -quest ${SCRIPT_DIR}/gv-questions-spalex.hed \
    -bin ${VC_PATH} > ${TMP_DIR}/$bestAVM/cdgv.log || { echo "context gv training failed" ; exit 1; } 
mv ${TMP_DIR}/$bestAVM/cdgv/hmm/hts_engine ${INTER_OUTPUT_ENGINE}/cdgv

echo "...Finished Speaker Adaptation..."
exit 0
