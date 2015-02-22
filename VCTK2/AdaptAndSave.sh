#!/bin/bash 

WORKDIR="/autofs/home/gth02a/jorgesanjuan/VCTK2/Research-Demo"

MODEL="joa-neutral_fromNeutralAverage_fromjoa-emos_NeuSpk"
trainspeakers=( "JCI" "joa-happiness" )

for i in ${trainspeakers[*]}
do
    echo "------- Processing $i, "`date`" ---------"
    cat global-spanish.template | sed -e "s/XXMODELXX/$MODEL/" | sed -e "s/XXSPEAKERXX/$i/" > global.conf
    bash run_demo.sh
    wait
    echo "------- Saving $i Temporary Files "`date`" ----"
    rm -r $WORKDIR/adapt/CSMAPLR/tmp/Spa/$i/$MODEL/map
    rm -r "/autofs/home/gth08a/EXPERIMENTOS/jorgesanjuan/CSMAPLRmodels/"$MODEL"/"$i
    mkdir -p /autofs/home/gth08a/EXPERIMENTOS/jorgesanjuan/CSMAPLRmodels/$MODEL > /dev/null
    mv $WORKDIR/adapt/CSMAPLR/tmp/Spa/$i/$MODEL "/autofs/home/gth08a/EXPERIMENTOS/jorgesanjuan/CSMAPLRmodels/"$MODEL"/"$i
    mkdir -p $WORKDIR/inter-module/hts_engine/Spa/$MODEL > /dev/null
    cp -r $WORKDIR/inter-module/hts_engine/Spa/$i $WORKDIR/inter-module/hts_engine/Spa/$MODEL
    cp -r $WORKDIR/models/Spa/spalex/$MODEL/config "/autofs/home/gth08a/EXPERIMENTOS/jorgesanjuan/CSMAPLRmodels/"$MODEL"/"$i
    cp $WORKDIR/models/Spa/spalex/$MODEL/hmm/tree* "/autofs/home/gth08a/EXPERIMENTOS/jorgesanjuan/CSMAPLRmodels/"$MODEL"/"$i
    echo "------- Finished Processing $i, "`date`" --------"
done
