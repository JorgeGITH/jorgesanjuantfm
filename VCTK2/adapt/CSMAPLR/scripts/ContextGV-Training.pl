#!/usr/bin/perl
#$ -S /usr/bin/perl
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
##                         Date:   31 October 2011                        #
##                         Contact: jyamagis@inf.ed.ac.uk                 #
###########################################################################

use File::Path;
$| = 1;

#==============  BASIC INFORMATION =======================================
$DATA            = "";                # list of cmp files 
$LABEL           = "";                # list of label files 
$OUTDIR          = "";                # output directory 
$QFILE           = "";                # question file used for context clustering

#==============  CONFIGURABLE VARIABLES ================================== 
# Configuration (HMM)
$NUMSTATE        = 1;                 # number of states for a HMM
%STREAM          = ('gv-mcep'  => '1',   # stream structure 
                    'gv-logF0' => '2',
                    'gv-bndap' => '3');
$STATICSTREAM1   = 60;                # Order of static feature for stream 1
$STATICSTREAM2   = 1;                 # Order of static feature for stream 2
$STATICSTREAM3   = 25;                # Order of static feature for stream 5


#============== Initialization (do not change these values) ===============
$PARALLEL       = -1;                 # pararrel mode
$SSTATE         = 2;                  # HTK normally starts from state 2
$ESTATE         = $NUMSTATE + 1;      # HTK normally starts from state 2
$MDLWEIGHT      = 0.1;                  # MDL Weight 

#============== Arguments operation ========================================

$NUMSTEP        = 60;
$FROM           = 1;
$TO             = $NUMSTEP;

foreach $i (1..$NUMSTEP) {
    $EXEC[$i] = 0;
}

while ($ARGV[0] =~ /^-/) {
    $_ = shift;
    if    (/^-data$/)       {$DATA = shift;}
    elsif (/^-lab$/)        {$LABEL = shift;}
    elsif (/^-out$/)        {$OUTDIR= shift;}
    elsif (/^-quest$/)      {$QFILE = shift;}
    elsif (/^-from$/)       {$FROM = shift;}
    elsif (/^-to$/)         {$TO = shift;}
    elsif (/^-state$/)      {$NUMSTATE = shift;}
    elsif (/^-stream1$/)    {$STATICSTREAM1 = shift;}
    elsif (/^-stream5$/)    {$STATICSTREAM5 = shift;}
    elsif (/^-pa$/)         {$PARALLEL = shift;}
    elsif (/^-ma$/)         {$MDLWEIGHT = shift;}
    elsif (/^-bin$/)        {$BIN = shift;}
}

foreach $i ($FROM..$TO) {
    $EXEC[$i] = 1;
}

# Check required minimum inputs
if (($DATA eq "") || ($LABEL eq "") || ($OUTDIR eq "") || ($QFILE eq "")){
    print "USAGE: HTS2011-Training.pl requires at least the following four files\n";
    print "\t -data  <file>   : list of cmp files \n";
    print "\t -lab   <file>   : list of label files \n";
    print "\t -out   <dir>    : output directory \n";
    print "\t -quest <file>   : question file used for context clustering \n";
    exit;
}

#============= Re-define based on specified arguments  ===================

$ESTATE         = $NUMSTATE + 1;

#============= Grid Engine Variables ======================================


#=======================================================================
# Directories and Files
#=======================================================================
#=============Working Directory==========================================
#$BIN                   = "$ENV{VC_PATH}";   

#=============Label directory =============================
$LISTDIR               = "$OUTDIR/list";
$TRAIN                 = "$LISTDIR/train.scp";
$FULLLIST              = "$LISTDIR/full.lst";
$FULLMLF               = "$LISTDIR/full.mlf";
$MONOLIST              = "$LISTDIR/mono.lst";
$MONOMLF               = "$LISTDIR/mono.mlf";
$NULLHED               = "$LISTDIR/null.hed";
#=============Config Files ============================================
$CONFIG                = "$OUTDIR/config/general.conf";
$UNFCONFIG             = "$OUTDIR/config/general-unfloor.conf";
$CONFIGCLUST           = "$OUTDIR/config/clust.conf";
#=============HMM-training common directory and names ==================
$HMMDIR                = "$OUTDIR/training";
$FLOORMMF{'gv'}        = "vFloor.gv.mmf";
$FULLMMF{'gv'}         = "full.gv.mmf";
$CLSTMMF{'gv'}         = "clustered.gv.mmf";
#=============Floor=====================================================
$HCOMPVDIR             = "$HMMDIR/VarianceFloor";
$PROTO                 = "$HCOMPVDIR/cmp.prt";
$MONO2FULLHED          = "$HCOMPVDIR/mono2full.gv.hed";
#=============Embedded Training (CD)====================================
$HERESTFULL            = "$HMMDIR/EmbeddedTraining";
$STAFILE{'gv'}         = "$HERESTFULL/gvp.sts";
#=============Clustering (Spec)==========================================
$HHEDCLUSTRINGSPEC     = "$HMMDIR/ContextClustering-Spec";
$CLSTHED{'gv-mcep'}     = "$HHEDCLUSTRINGSPEC/cluster.gv-mcep.hed";
$INFFILE{'gv-mcep'}     = "$HHEDCLUSTRINGSPEC/tree.gv-mcep.inf";
#=============Clustering (logF0)=========================================
$HHEDCLUSTRINGLOGF0    = "$HMMDIR/ContextClustering-logF0";
$CLSTHED{'gv-logF0'}    = "$HHEDCLUSTRINGLOGF0/cluster.gv-logF0.hed";
$INFFILE{'gv-logF0'}    = "$HHEDCLUSTRINGLOGF0/tree.gv-logF0.inf";
#=============Clustering (Bndap)=========================================
$HHEDCLUSTRINGBND      = "$HMMDIR/ContextClustering-Bndap";
$CLSTHED{'gv-bndap'}    = "$HHEDCLUSTRINGBND/cluster.gv-bndap.hed";
$INFFILE{'gv-bndap'}    = "$HHEDCLUSTRINGBND/tree.gv-bndap.inf";
#=============Embedded Training (Tied CD HMM)=================================
$HERESTCLUSTED         = "$HMMDIR/EmbeddedTrainingCluster";
$FLOORHED              = "$HMMDIR/EmbeddedTrainingCluster/floor.hed";
#=============Convert====================================================
$OUTHMMs               = "$OUTDIR/hmm";
$CHSHED{'gv-mcep'}      = "$OUTDIR/hmm/hts_engine/chs.gv-mcep.hed";
$CHSHED{'gv-logF0'}     = "$OUTDIR/hmm/hts_engine/chs.gv-logF0.hed";
$CHSHED{'gv-bndap'}     = "$OUTDIR/hmm/hts_engine/chs.gv-bndap.hed";


#=======================================================================
# Main Program
#=======================================================================
#-----------------------------------------------------------------------
# Step1 Prepare Files
#-----------------------------------------------------------------------

if ($EXEC[1]) {
  print_step("Preparation for HTK/HTS");
  print_time("Started at");
  makedir("$OUTDIR/config");
  makedir("$LISTDIR");

  shell("cp $DATA $TRAIN");

  # Generate config files for HTK/HTS
  shell("rm -f $OUTDIR/config/*");
  make_config();

  # Generate null.hed
  shell("rm -rf $NULLHED");
  shell("touch $NULLHED");

  # Ignore files which caused some errors in feature extraction
  shell("awk -F \/ '{print \$NF}' $TRAIN | sed 's/\\.cmp//g' > $LISTDIR/cmp.lst");
  shell("fgrep -f $LISTDIR/cmp.lst $LABEL > $LISTDIR/label.lst");

  shell("$BIN/HLEd -A -D -T 1 -V -l '*' -n $FULLLIST -i $FULLMLF -S $LISTDIR/label.lst $NULLHED");
  shell("$BIN/HLEd -A -D -T 1 -V -l '*' -n $MONOLIST -i $MONOMLF -m $NULLHED $FULLMLF");
  print_time("Finished at");
}

#-----------------------------------------------------------------------
# Step2 Flooring of Covariance
#-----------------------------------------------------------------------

if ($EXEC[2]) {
    print_step("Flooring of Covariance");
    print_time("Started at");
    makedir("$HMMDIR");
    makedir("$HCOMPVDIR");

    # Create an HMM proto file 
    make_proto();

    # Estimate variance floor 
    open(FILE, "<$MONOLIST") or die "Can't open `$MONOLIST': $!";
    $i=1;
    while (<FILE>) {
        chomp;
        shell("$BIN/HCompV -A -C $CONFIG -D -V -l $_ -o $_ -m -I $MONOMLF -S $TRAIN -T 1 -M $HCOMPVDIR $PROTO");
        shell("mv $HCOMPVDIR/$_ $HCOMPVDIR/$i.mmf");
        $i++;
    }
    close(FILE);
    shell("head -n 1 $PROTO | cat - $HCOMPVDIR/vFloors > $HCOMPVDIR/$FLOORMMF{'gv'} ");

    shell("echo \"CL $FULLLIST\" > $MONO2FULLHED");
    open(HMMLIST, "<$MONOLIST");
    $i=1;
    $arg = "";
    while (<HMMLIST>) {
        $arg = $arg . " -H $HCOMPVDIR/$i.mmf ";
        $i++;
    }
    close(HMMLIST);
    shell("$BIN/HHEd -A -C $CONFIG -D -V -T 1 $arg -s -p -i -w $HCOMPVDIR/$FULLMMF{'gv'} $MONO2FULLHED $MONOLIST");
    print_time("Finished at");
}

#-----------------------------------------------------------------------
# Step3 Embedded Training for FullContext HMM 
#-----------------------------------------------------------------------

if ($EXEC[3]) {
    print_step(" Embedded Training for FullContext HMM");
    print_time("Started at");
    makedir("$HERESTFULL");

    shell("$BIN/HERest -A -C $UNFCONFIG -D -V -H $HCOMPVDIR/$FULLMMF{'gv'} -I $FULLMLF -M $HERESTFULL/ -S $TRAIN -T 1 -m 1 -s $STAFILE{'gv'} -u mv -w 0.0 $FULLLIST");

    print_time("Finished at");
}

#-----------------------------------------------------------------------
# Step4. Context Clustering for Spec
#-----------------------------------------------------------------------

if ($EXEC[4]) {
    print_step("Context Clustering for Spec");
    print_time("Started at");
    makedir("$HHEDCLUSTRINGSPEC");

    mkclsthed('gv-mcep',0);
    shell("$BIN/HHEd -A -C $CONFIG -C $CONFIGCLUST -D -V -H $HERESTFULL/$FULLMMF{'gv'} -T 1 -i -m -a $MDLWEIGHT -p -r 1 -s -w $HHEDCLUSTRINGSPEC/$CLSTMMF{'gv'} $CLSTHED{'gv-mcep'} $FULLLIST");

    print_time("Finished at");
}

#-----------------------------------------------------------------------
# Step4. Context Clustering for LogF0
#-----------------------------------------------------------------------

if ($EXEC[5]) {
    print_step("Context Clustering for logF0");
    print_time("Started at");
    makedir("$HHEDCLUSTRINGLOGF0");

    mkclsthed('gv-logF0',0);
    shell("$BIN/HHEd -A -C $CONFIG -C $CONFIGCLUST -D -V -H $HHEDCLUSTRINGSPEC/$CLSTMMF{'gv'} -T 1 -i  -m -a $MDLWEIGHT  -p -r 1 -s -w $HHEDCLUSTRINGLOGF0/$CLSTMMF{'gv'} $CLSTHED{'gv-logF0'} $FULLLIST");

    print_time("Finished at");
}

#-----------------------------------------------------------------------
# Step6. Context Clustering for Bndap
#-----------------------------------------------------------------------

if ($EXEC[6]) {
    print_step("Context Clustering for Bndap");
    print_time("Started at");
    makedir("$HHEDCLUSTRINGBND");

    mkclsthed('gv-bndap',0);
    shell("$BIN/HHEd -A -C $CONFIG -C $CONFIGCLUST -D -V -H $HHEDCLUSTRINGLOGF0/$CLSTMMF{'gv'} -T 1 -i  -m -a $MDLWEIGHT  -p -r 1 -s -w $HHEDCLUSTRINGBND/$CLSTMMF{'gv'} $CLSTHED{'gv-bndap'} $FULLLIST");

    print_time("Finished at");
}

#-----------------------------------------------------------------------
# Step7  Embedded Training for Clustered HMM
#-----------------------------------------------------------------------

if ($EXEC[7]) {
    print_step(" Embedded Training for Clustered HMM ");
    print_time("Started at");
    makedir("$HERESTCLUSTED");

    shell("$BIN/HERest -A -C $CONFIG -D -V -H $HCOMPVDIR/$FLOORMMF{'gv'} -H $HHEDCLUSTRINGBND/$CLSTMMF{'gv'} -I $FULLMLF -M $HERESTCLUSTED -S $TRAIN -T 1 -m 1 -u mv -w 3 $FULLLIST");

    print_time("Finished at");
}

#-----------------------------------------------------------------------
# Step8 Output Trained Models
#-----------------------------------------------------------------------

if ($EXEC[8]) {
  print_step("Save Trained Models");
  print_time("Started at");
  makedir("$OUTHMMs");
  ${TMP_DIR} = "$OUTHMMs/hts_engine";

  shell("cp $HERESTCLUSTED/$CLSTMMF{'gv'} $OUTHMMs/");
  shell("cp $FULLLIST $OUTHMMs/context.gv.list");
  shell("cp $INFFILE{'gv-mcep'} $OUTHMMs/tree.gv-mcep.inf");
  shell("cp $INFFILE{'gv-logF0'} $OUTHMMs/tree.gv-logF0.inf");
  shell("cp $INFFILE{'gv-bndap'} $OUTHMMs/tree.gv-bndap.inf");

  # Create hts_engine models 
  makedir("$OUTHMMs/hts_engine");
  mkclchs('gv-mcep');
  shell("$BIN/HHEd -A -C $CONFIG -T 1 -D -V -H $OUTHMMs/$CLSTMMF{'gv'} -i -p $CHSHED{'gv-mcep'} $OUTHMMs/context.gv.list");
  shell("mv $OUTHMMs/hts_engine/trees.1 $OUTHMMs/hts_engine/tree-gv-mcep.inf");
  shell("mv $OUTHMMs/hts_engine/pdf.1 $OUTHMMs/hts_engine/gv-mcep.pdf");  
  mkclchs('gv-logF0');
  shell("$BIN/HHEd -A -C $CONFIG -T 1 -D -V -H $OUTHMMs/$CLSTMMF{'gv'} -i -p $CHSHED{'gv-logF0'} $OUTHMMs/context.gv.list");
  shell("mv $OUTHMMs/hts_engine/trees.2 $OUTHMMs/hts_engine/tree-gv-logF0.inf");
  shell("mv $OUTHMMs/hts_engine/pdf.2 $OUTHMMs/hts_engine/gv-logF0.pdf");
  mkclchs('gv-bndap');
  shell("$BIN/HHEd -A -C $CONFIG -T 1 -D -V -H $OUTHMMs/$CLSTMMF{'gv'} -i -p $CHSHED{'gv-bndap'} $OUTHMMs/context.gv.list");
  shell("mv $OUTHMMs/hts_engine/trees.3 $OUTHMMs/hts_engine/tree-gv-bndap.inf");
  shell("mv $OUTHMMs/hts_engine/pdf.3 $OUTHMMs/hts_engine/gv-bndap.pdf");
  shell("rm -f ${TMP_DIR}/dur.head ${TMP_DIR}/var ${TMP_DIR}/mean");
  shell("rm -f $CHSHED{'gv-mcep'} $CHSHED{'gv-logF0'} $CHSHED{'gv-bndap'}");

  print_time("Finished at");
}

#-----------------------------------------------------------------------
# Step9 Clean Data
#-----------------------------------------------------------------------

if ($EXEC[9]) {
  print_step("Clean Unnecessary Data");
  print_time("Started at");

  shell("rm -rf $HMMDIR $ANALYSIS $LISTDIR ");

  print_time("Finished at");
}

#=======================================================================
# Subroutines
#=======================================================================

sub makedir($) {
  my($targetdir) = @_;
  
  if (! -d $targetdir) {
      eval{
          mkpath($targetdir);
      };
      if( $@ ){ die "failed to create $targetdir $@"; }
  }
}

sub shell($) {
  my($command) = @_;
  my($exit,$start,$end);
  
  print "\n$command\n\n";
  
  $start = time;
  $exit = system($command);
  $end = time;
  
  $h = int(($end-$start)/3600);
  $m = int((($end-$start)-$h*3600)/60);
  $s = $end-$start-$h*3600-$m*60;
  
  print "--------------------------------------------------\n";
  printf(" Realtime %3d:%02d:%02d\n",$h,$m,$s);
  print "--------------------------------------------------\n";
  
  die "Error in this command : $command\n" if($exit/256 != 0);
}

sub print_step($) {
  print "\n";
  print "************************************************************************\n\n";
  print "@_\n\n";
  print "************************************************************************\n\n";
}

sub print_time($) {
  print "\n";
  print "--------------------------------------------------\n";
  print " @_ ".`date`;
  print "--------------------------------------------------\n";
  print "\n";
}

sub print_ls(@) {
  print "\n";
  print "==================================================\n";
  print " ".`ls -l @_`;
  print "==================================================\n";
  print "\n";
}


# sub routine for generating config files for HTS
sub make_config {

    my($specthreshold,$bapthreshold);
    
   # general.conf
   open(CONFIG,">$CONFIG") || die "Cannot open $!";   
   # Input/Output variables
   print CONFIG "NATURALREADORDER      = T\n";    # Input byte order (little endian)
   print CONFIG "NATURALWRITEORDER     = T\n";    # Output byte order (little endian)
   # Variance flooring  
   print CONFIG "APPLYVFLOOR           = T\n";    
   # Scaling factor for variance floor of each stream (variance floor = global variance * 0.01)
   print CONFIG "VFLOORSCALESTR        = \"Vector 3 0.01 0.01 0.01\"\n" ;  
   close(CONFIG);


   # general-unfloor.conf
   open(CONFIG,">$UNFCONFIG") || die "Cannot open $!";
   # Input/Output variables
   print CONFIG "NATURALREADORDER      = T\n";    # Input byte order (little endian)
   print CONFIG "NATURALWRITEORDER     = T\n";    # Output byte order (little endian)
   # Variance flooring 
   print CONFIG "APPLYVFLOOR           = F\n";    
   close(CONFIG);


   # clust.conf
   open(CONFIG,">$CONFIGCLUST") || die "Cannot open $!";
   # Mimimum state-occupancy in each leaf nodes
   print CONFIG "MINLEAFOCC            =  5\n";
   close(CONFIG);


}

# sub routine for generating proto-type model (Copy from HTS-2.1)
sub make_proto {
   my($i, $j, $k, $s);

   # calculate total number of vectors including delta and delta-delta
   $vsize = ($STATICSTREAM1 + $STATICSTREAM2 + $STATICSTREAM3);  

   # output prototype definition
   # open proto type definition file 
   open(PROTO,">$PROTO") || die "Cannot open $!";

   # output header 
   # output vector size & feature type
   print PROTO "~o <VecSize> $vsize <USER> <DIAGC>";
   
   # output information about multi-space probability distribution (MSD)
   print PROTO "<MSDInfo> 3 0 0 0 ";
   
   # output information about stream
   print PROTO "<StreamInfo> 3 $STATICSTREAM1 $STATICSTREAM2 $STATICSTREAM3";
   print PROTO "\n";

   # output HMMs
   print  PROTO "<BeginHMM>\n";
   printf PROTO "  <NumStates> %d\n", $NUMSTATE+2;

   # output HMM states 
   for ($i=2;$i<=$NUMSTATE+1;$i++) {

      # output state information
      print PROTO "  <State> $i\n";

      # output stream weight
      print PROTO "  <SWeights> 3 1.0 1.0 1.0  \n";

      # output stream 1 information
      print  PROTO "  <Stream> 1\n";
      # output mean vector 
      printf PROTO "    <Mean> %d\n", $STATICSTREAM1;
      for ($k=1;$k<=$STATICSTREAM1;$k++) {
          print PROTO "      " if ($k%10==1); 
          print PROTO "0.0 ";
          print PROTO "\n" if ($k%10==0);
      }
      print PROTO "\n" if ($k%10!=1);

      # output covariance matrix (diag)
      printf PROTO "    <Variance> %d\n", $STATICSTREAM1;
      for ($k=1;$k<=$STATICSTREAM1;$k++) {
          print PROTO "      " if ($k%10==1); 
          print PROTO "1.0 ";
          print PROTO "\n" if ($k%10==0);
      }
      print PROTO "\n" if ($k%10!=1);


      # output stream 2 information
      print  PROTO "  <Stream> 2\n";
      # output mean vector 
      printf PROTO "    <Mean> %d\n", $STATICSTREAM2;
      for ($k=1;$k<=$STATICSTREAM2;$k++) {
          print PROTO "      " if ($k%10==1); 
          print PROTO "0.0 ";
          print PROTO "\n" if ($k%10==0);
      }
      print PROTO "\n" if ($k%10!=1);

      # output covariance matrix (diag)
      printf PROTO "    <Variance> %d\n", $STATICSTREAM2;
      for ($k=1;$k<=$STATICSTREAM2;$k++) {
          print PROTO "      " if ($k%10==1); 
          print PROTO "1.0 ";
          print PROTO "\n" if ($k%10==0);
      }
      print PROTO "\n" if ($k%10!=1);

      # output stream 3 information 
      print  PROTO "  <Stream> 3\n";
      # output mean vector 
      printf PROTO "    <Mean> %d\n", $STATICSTREAM3;
      for ($k=1;$k<=$STATICSTREAM3;$k++) {
          print PROTO "      " if ($k%10==1); 
          print PROTO "0.0 ";
          print PROTO "\n" if ($k%10==0);
      }
      print PROTO "\n" if ($k%10!=1);

      # output covariance matrix (diag)
      printf PROTO "    <Variance> %d\n", $STATICSTREAM3;
      for ($k=1;$k<=$STATICSTREAM3;$k++) {
          print PROTO "      " if ($k%10==1); 
          print PROTO "1.0 ";
          print PROTO "\n" if ($k%10==0);
      }
      print PROTO "\n" if ($k%10!=1);

  }

   # output state transition matrix
   printf PROTO "  <TransP> %d\n", $NUMSTATE+2;
   print  PROTO "    ";
   for ($j=1;$j<=$NUMSTATE+2;$j++) {
      print PROTO "1.000e+0 " if ($j==2);
      print PROTO "0.000e+0 " if ($j!=2);
   }
   print PROTO "\n";
   print PROTO "    ";
   for ($i=2;$i<=$NUMSTATE+1;$i++) {
      for ($j=1;$j<=$NUMSTATE+2;$j++) {
         print PROTO "0.000e+0 " if ($i==$j);
         print PROTO "1.000e+0 " if ($i==$j-1);
         print PROTO "0.000e+0 " if ($i!=$j && $i!=$j-1);
      }
      print PROTO "\n";
      print PROTO "    ";
   }
   for ($j=1;$j<=$NUMSTATE+2;$j++) {
      print PROTO "0.000e+0 ";
   }
   print PROTO "\n";

   # output footer
   print PROTO "<EndHMM>\n";
   close(PROTO);
}


sub mkclsthed($) {
  my($kind,$sti) = @_;
  my($state,$rothr,$tbthr,$stats,$lines,$i,$j,@set,$second);
  
  $stats = 'gv';
  $state = $NUMSTATE;    
  
  open(F, "<$QFILE");
  @lines = <F>;
  close(F);
  
  open(EDFILE,">$CLSTHED{$kind}");
  print EDFILE "RO 0 \"$STAFILE{$stats}\"\n";
  print EDFILE "\nTR 1\n\n";
  print EDFILE @lines;
  print EDFILE "\nTR 1\n\n";
  for ($i = 2;$i < 2+$state;$i++){
      print EDFILE "TB 0 ${kind}_s${i}_ {*.state[${i}].stream[$STREAM{$kind}]} \n";
  }
  print EDFILE "\nTR 1\n\n";
  print EDFILE "ST \"$INFFILE{$kind}\"\n";
  close(EDFILE);
}



sub mkclchs($) {
  my($kind) = @_;

  open(EDFILE,">$CHSHED{$kind}");
  print EDFILE "\nTR 2\n\n"; 
  print EDFILE "LT \"$OUTHMMs/tree.${kind}.inf\"\n";
  print EDFILE "CT \"$OUTHMMs/hts_engine\"\n";
  print EDFILE "CM \"$OUTHMMs/hts_engine\"\n";
  close(EDFILE);
}
