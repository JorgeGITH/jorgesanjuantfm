#!/bin/bash
#$ -S /bin/bash

# bash xadapt-select.sh $WORKDIR"/"$TMPOUTDIR $MODELSDIR $NAVGDIR $j $i $factor $HTSEMO $HTSNEU $TRANSPF0 $TRANSPSPECT $TRANSPDUR $EMOBASE

###########################
EXP=$1 # path for Experiment directory

#VC_PATH="/autofs/home/gth02a/jaime.lorenzo/VCTK/bin"
VC_PATH="/home/gth08a/EXPERIMENTOS/jorgesanjuan/VCTK2/bin"
#CSMAPLR="/autofs/home/gth02a/jaime.lorenzo/VCTK/Research-Demo/adapt/CSMAPLR-transp"
CSMAPLR="/home/gth08a/EXPERIMENTOS/jorgesanjuan/VCTK2/Research-Demo/adapt/CSMAPLR-transp"
CSMAPLR_SCRIPT_DIR="$CSMAPLR/scripts"
CONVERTXFORMS="$CSMAPLR/ConvertXform.py"

LOG_DIR="$EXP/log"
CFG_DIR="$EXP/config"

mkdir -p $CFG_DIR $LOG_DIR

FLAG_NITERATION=5

MODELS=$2

SPKNEU=$5
SPKNEU_DIR=$MODELS"/"$SPKNEU
AVGNEU_TO_SPKNEU_CMPXFORM=$SPKNEU_DIR/xform/cmp/cmp.feat$FLAG_NITERATION
AVGNEU_TO_SPKNEU_DURXFORM=$SPKNEU_DIR/xform/dur/cmp.feat$FLAG_NITERATION

AVGNEU_DIR=$3
AVGNEU_TO_AVGSTYLE=$4
AVGNEU_TO_AVGSTYLE_DIR=$MODELS"/"$AVGNEU_TO_AVGSTYLE

AVGNEU_TO_AVGSTYLE_CMPXFORM=$AVGNEU_TO_AVGSTYLE_DIR/xform/cmp/cmp.feat$FLAG_NITERATION
AVGNEU_TO_AVGSTYLE_DURXFORM=$AVGNEU_TO_AVGSTYLE_DIR/xform/dur/cmp.feat$FLAG_NITERATION

TGT_STYLESPK_VOICE=$5"-"$4"-K"$6
TGT_STYLESPK_DIR="$CSMAPLR/$EXP/$TGT_STYLESPK_VOICE"

# Style Strength Control Parameters
K=$6
K2=1.00 # Control for the neutral speaker, default = 1.00

## Transplantation streams selection                                                                                                                         
HTSEMO=$7
HTSNEU=$8
TRANSPF0=$9
TRANSPSPECT=${10}
TRANSPDUR=${11}
EMOTIONALBASE=${12}


#####################################

# Mel-cepstral analysis 
mcorder=60
# Aperiodicity analysis
baporder=25
USESMAP=0
# # of iteration of HERest (>= 1)
FLAG_NITERATION2=3
# Apply State duration adaptation as well as 
# Spectrum, F0 and aperiodicity adaptation 
FLAG_DUR_ADAPTATION=$11
# Additional MAP adaptation on the top of CMLLR/CSMAPLR (0 or 1)
FLAG_MAP_ADAPTATION=0
FLAG_SMAPSIGMA=100
# Regression class tree 
treeprune=100.0
mcepthresh=4000.0
f0thresh=500.0
bapthresh=1000.0
durthresh=500.0
# Setting for MAP adaptation 
maptau=50 

#######################################
# Apply linear transforms to model    #                                                                                                             
####################################### 
echo "STEP 9 ...Applying transforms to generate TGT_STYLE_VOICE=$TGT_STYLESPK_VOICE..."
VOICE=$TGT_STYLESPK_VOICE
rm -f $CONF_DIR/xadapt.cmp.$VOICE.hed $CONF_DIR/xadapt.dur.$VOICE.hed
mkdir -p $EXP/$VOICE/hts_engine >& /dev/null
mkdir -p $EXP/$VOICE/xform/cmp >& /dev/null
mkdir -p $EXP/$VOICE/xform/dur >& /dev/null

### PREPARE TRANSFORMS
python $CONVERTXFORMS $AVGNEU_TO_AVGSTYLE_CMPXFORM $K | sed -e "s/cmp\.feat$FLAG_NITERATION/cmp.ctrl.$K.feat$FLAG_NITERATION/g" > $EXP/$VOICE/xform/cmp/cmp.ctrl.$K.feat$FLAG_NITERATION
python $CONVERTXFORMS $AVGNEU_TO_AVGSTYLE_DURXFORM $K | sed -e "s/cmp\.feat$FLAG_NITERATION/cmp.ctrl.$K.feat$FLAG_NITERATION/g" > $EXP/$VOICE/xform/dur/cmp.ctrl.$K.feat$FLAG_NITERATION 


python $CONVERTXFORMS $AVGNEU_TO_SPKNEU_CMPXFORM $K2 | sed -e "s/cmp\.feat$FLAG_NITERATION/cmp.spkneu.$K2.feat$FLAG_NITERATION/g" | awk -v name="cmp.ctrl.$K.feat$FLAG_NITERATION" '$0=="<XFORMSET>"{print "<PARENTXFORM>~a", "\""name"\""; print "<XFORMSET>"}$0!="<XFORMSET>"{print}' > $EXP/$VOICE/xform/cmp/cmp.spkneu.$K2.feat$FLAG_NITERATION
python $CONVERTXFORMS $AVGNEU_TO_SPKNEU_DURXFORM $K2 | sed -e "s/cmp\.feat$FLAG_NITERATION/cmp.spkneu.$K2.feat$FLAG_NITERATION/g" | awk -v name="cmp.ctrl.$K.feat$FLAG_NITERATION" '$0=="<XFORMSET>"{print "<PARENTXFORM>~a", "\""name"\""; print "<XFORMSET>"}$0!="<XFORMSET>"{print}' > $EXP/$VOICE/xform/dur/cmp.spkneu.$K2.feat$FLAG_NITERATION


################################

touch $CFG_DIR/xadapt.cmp.$VOICE.hed
if [ $TRANSPSPECT -ge 1 ]; then echo "LT \"${AVGNEU_DIR}/tree.mcep.inf\"" > $CFG_DIR/xadapt.cmp.${VOICE}.hed; fi
if [ $TRANSPF0 -ge 1 ]; then echo "LT \"${AVGNEU_DIR}/tree.logF0.inf\"" >> $CFG_DIR/xadapt.cmp.${VOICE}.hed; fi
if [ $TRANSPSPECT -ge 1 ]; then echo "LT \"${AVGNEU_DIR}/tree.bndap.inf\"" >> $CFG_DIR/xadapt.cmp.${VOICE}.hed; fi
echo "AX \"$EXP/$VOICE/xform/cmp/cmp.spkneu.$K2.feat$FLAG_NITERATION\""   >> $CFG_DIR/xadapt.cmp.$VOICE.hed
echo "CT \"$EXP/$VOICE/hts_engine\""                      >> $CFG_DIR/xadapt.cmp.$VOICE.hed
echo "CM \"$EXP/$VOICE/hts_engine\""                      >> $CFG_DIR/xadapt.cmp.$VOICE.hed

cp $AVGNEU_DIR/adp.clustered.cmp.mmf $EXP/$VOICE
cp $AVGNEU_DIR/adp.context.full.list $EXP/$VOICE
CMP_MMF=$EXP/$VOICE/adp.clustered.cmp.mmf
CMPLIST=$EXP/$VOICE/adp.context.full.list
cp $AVGNEU_DIR/dectree_cmp.base $EXP/$VOICE
cp $AVGNEU_DIR/dectree_cmp.tree $EXP/$VOICE
CMPTREEARG="-H $EXP/$VOICE/dectree_cmp.base -H $EXP/$VOICE/dectree_cmp.tree"

${VC_PATH}/HHEd \
    -A \
    -B \
    -C ${AVGNEU_DIR}/config/general.conf \
    -T 1 \
    -D \
    -V \
    -i \
    -p \
    -H ${CMP_MMF} \
    ${CMPTREEARG} \
    -H $EXP/$VOICE/xform/cmp/cmp.ctrl.$K.feat$FLAG_NITERATION\
    $CFG_DIR/xadapt.cmp.$VOICE.hed \
    ${CMPLIST} \
    > ${LOG_DIR}/hhed.cnv.cmp.$VOICE.log 

if [ $TRANSPSPECT -ge 1 ]; then
    echo "spect"
    mv $EXP/$VOICE/hts_engine/trees.1 $EXP/$VOICE/hts_engine/tree-mcep.inf
    mv $EXP/$VOICE/hts_engine/pdf.1 $EXP/$VOICE/hts_engine/mcep.pdf
    mv $EXP/$VOICE/hts_engine/trees.5 $EXP/$VOICE/hts_engine/tree-bndap.inf
    mv $EXP/$VOICE/hts_engine/pdf.5 $EXP/$VOICE/hts_engine/bndap.pdf
elif [ $EMOTIONALBASE -ge 1 ]; then
    echo "emotional"
    cp ${HTSEMO}/tree-mcep.inf $EXP/$VOICE/hts_engine/tree-mcep.inf
    cp ${HTSEMO}/mcep.pdf $EXP/$VOICE/hts_engine/mcep.pdf
    cp ${HTSEMO}/tree-bndap.inf $EXP/$VOICE/hts_engine/tree-bndap.inf
    cp ${HTSEMO}/bndap.pdf $EXP/$VOICE/hts_engine/bndap.pdf
else
    echo "neutral"
    cp ${HTSNEU}/tree-mcep.inf $EXP/$VOICE/hts_engine/tree-mcep.inf
    cp ${HTSNEU}/mcep.pdf $EXP/$VOICE/hts_engine/mcep.pdf
    cp ${HTSNEU}/tree-bndap.inf $EXP/$VOICE/hts_engine/tree-bndap.inf
    cp ${HTSNEU}/bndap.pdf $EXP/$VOICE/hts_engine/bndap.pdf
fi

if [ $TRANSPF0 -ge 1 ]; then
    echo "F0"
    mv $EXP/$VOICE/hts_engine/trees.2 $EXP/$VOICE/hts_engine/tree-logF0.inf
    mv $EXP/$VOICE/hts_engine/pdf.2 $EXP/$VOICE/hts_engine/logF0.pdf
elif [ $EMOTIONALBASE -ge 1 ]; then
    echo "emotional"
    cp ${HTSEMO}/tree-logF0.inf $EXP/$VOICE/hts_engine/tree-logF0.inf
    cp ${HTSEMO}/logF0.pdf $EXP/$VOICE/hts_engine/logF0.pdf
else
    echo "neutral"
    cp ${HTSNEU}/tree-logF0.inf $EXP/$VOICE/hts_engine/tree-logF0.inf
    cp ${HTSNEU}/logF0.pdf $EXP/$VOICE/hts_engine/logF0.pdf
fi

# convert dur models from hts to hts_engine
if [ $TRANSPDUR -ge 1 ]; then
    echo "LT \"$AVGNEU_DIR/tree.dur.inf\""            > $CFG_DIR/xadapt.dur.$VOICE.hed
    echo "AX \"$EXP/$VOICE/xform/dur/cmp.spkneu.$K2.feat$FLAG_NITERATION\""   >> $CFG_DIR/xadapt.dur.$VOICE.hed
    echo "CT \"$EXP/$VOICE/hts_engine\""                      >> $CFG_DIR/xadapt.dur.$VOICE.hed
    echo "CM \"$EXP/$VOICE/hts_engine\""                      >> $CFG_DIR/xadapt.dur.$VOICE.hed
    
    cp $AVGNEU_DIR/adp.clustered.dur.mmf $EXP/$VOICE
    DUR_MMF=$EXP/$VOICE/adp.clustered.dur.mmf
    DURLIST=$EXP/$VOICE/adp.context.full.list
    cp $AVGNEU_DIR/dectree_dur.base $EXP/$VOICE
    cp $AVGNEU_DIR/dectree_dur.tree $EXP/$VOICE
    DURTREEARG="-H $EXP/$VOICE/dectree_dur.base -H $EXP/$VOICE/dectree_dur.tree"
    
    ${VC_PATH}/HHEd \
	-A \
	-B \
	-C ${AVGNEU_DIR}/config/general.conf \
	-T 1 \
	-D \
	-V \
	-i \
	-p \
	-H ${DUR_MMF} \
	${DURTREEARG} \
	-H $EXP/$VOICE/xform/dur/cmp.ctrl.$K.feat$FLAG_NITERATION \
	$CFG_DIR/xadapt.dur.$VOICE.hed \
	${DURLIST} \
	> ${LOG_DIR}/hhed.cnv.dur.$VOICE.log 
    
    mv $EXP/$VOICE/hts_engine/trees.1 $EXP/$VOICE/hts_engine/tree-duration.inf
    mv $EXP/$VOICE/hts_engine/pdf.1 $EXP/$VOICE/hts_engine/duration-2.2.pdf
    
elif [ $EMOTIONALBASE -ge 1 ]; then
    echo "emotional"
    cp ${HTSEMO}/tree-duration.inf $EXP/$VOICE/hts_engine/tree-duration.inf
    cp ${HTSEMO}/duration-2.2.pdf $EXP/$VOICE/hts_engine/duration-2.2.pdf
else
    echo "neutral"
    cp ${HTSNEU}/tree-duration.inf $EXP/$VOICE/hts_engine/tree-duration.inf
    cp ${HTSNEU}/duratio-2.2.pdf $EXP/$VOICE/hts_engine/duration-2.2.pdf
fi

# Convert Duration format to 2.1 format 
rm -f $EXP/$VOICE/dur.head $EXP/$VOICE/var $EXP/$VOICE/mean
${VC_PATH}/bcut +i -e 1 $EXP/$VOICE/hts_engine/duration-2.2.pdf \
    > $EXP/$VOICE/dur.head
${VC_PATH}/bcut -s 2 $EXP/$VOICE/hts_engine/duration-2.2.pdf \
    | ${VC_PATH}/x2x -o +fa2 \
    | awk '{print $2}' \
    | ${VC_PATH}/x2x -o +af \
    >  $EXP/$VOICE/var
${VC_PATH}/bcut -s 2 $EXP/$VOICE/hts_engine/duration-2.2.pdf \
    | ${VC_PATH}/x2x -o +fa2 \
    | awk '{print $1}' \
    | ${VC_PATH}/x2x -o +af \
    >  $EXP/$VOICE/mean 
${VC_PATH}/merge +f -s 5 -l 5 -L 5 $EXP/$VOICE/var < $EXP/$VOICE/mean \
    | cat $EXP/$VOICE/dur.head - \
    > $EXP/$VOICE/hts_engine/duration.pdf

#### FINALIZE THE TRANSPLANTATION

cp $HTSEMO/gv*  $EXP/$VOICE/hts_engine/
cp $HTSEMO/*win $EXP/$VOICE/hts_engine/
