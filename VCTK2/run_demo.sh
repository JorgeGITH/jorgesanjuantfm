#!/bin/bash

export PATH=/autofs/home/gth08a/EXPERIMENTOS/jorgesanjuan/VCTK2/bin:$PATH
export LANG="es_ES.iso885915@euro"
export LC_ALL="es_ES.iso885915@euro"
 
# init
cd init
perl init_baseline.pl || { echo "Step 0: initialisation failed" ; exit 1; } 
cd ..

# fa-tts
cd fa-tts
perl fa-tts_baseline.pl || { echo "Step 1: feature extraction failed" ; exit 1; } 
cd ..

# adapt-prep
cd adapt-prep
perl adapt-prep_baseline.pl || { echo "Step 2: text analysis failed" ; exit 1; } 
cd ..

# adapt 
cd adapt
perl adapt_baseline.pl || { echo "Step 3: speaker adaptation failed" ; exit 1; } 
cd ..

# data cleaning  
cd data-clean
perl data-clean_baseline.pl || { echo "Step 4: data cleaning failed" ; exit 1; } 
cd ..

# label cleaning
cd label-clean
perl label-clean_baseline.pl || { echo "Step 5: label cleaning failed" ; exit 1; } 
cd ..

# adapt
cd adapt
perl adapt_refinement.pl || { echo "Step 6: final speaker adaptation failed" ; exit 1; } 
cd ..

# speaker dependent HMM
cd sdvoice
perl sdvoice_baseline.pl || { echo "Step 7: speaker dependent HMM training failed" ; exit 1; } 
cd ..

# average voice building 
cd averagevoice
perl averagevoice_baseline.pl || { echo "Step 8: average voice model training failed" ; exit 1; }
cd ..
