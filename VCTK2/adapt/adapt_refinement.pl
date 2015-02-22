#!/usr/bin/perl
require "./adapt.conf";
if(${SW6} != 1 || ${SW8} == 1){ exit(0);}
print "===========================================================\n";
print "Speaker Adaptation\n";
shell(date);
print "===========================================================\n";
print "\n";
print "adapt_refinement.pl\n";

open(CONFIG0,"<${LOCAL_CONFIG_0}")||die "can't open $LOCAL_CONFIG_0\n";
open(CONFIG,">${LOCAL_CONFIG}")||die "can't create $LOCAL_CONFIG\n";

print CONFIG "WD_EMIME=${WD_EMIME}\n";
print CONFIG "VC_PATH=${TOOL_VC}\n";

print CONFIG "INTER_INPUT_FLABEL=$INTER_INPUT_FLABEL\n";
print CONFIG "INTER_INPUT_FEATURE=$INTER_INPUT_FEATURE\n";
print CONFIG "INTER_INPUT_GV=$INTER_INPUT_GV\n";
print CONFIG "INTER_OUTPUT_ENGINE=$INTER_OUTPUT_ENGINE\n";
print CONFIG "INTER_OUTPUT_ALIGN=$INTER_OUTPUT_ALIGN\n";
print CONFIG "AVMS=$AVMS\n";
print CONFIG "MODEL_DIR=$MODEL_DIR\n";
print CONFIG "TMP_DIR=$TMP_DIR\n";
print CONFIG <CONFIG0>;
close(CONFIG);
close(CONFIG0);

chdir "$WM_CLSA";
shell("$MODULE_EXECUTABLE $MODULE_EXTRA_PARAM");
if(${TRACE} != 1){
    shell("rm -rf $TMP_DIR ${LOCAL_CONFIG}");
}
print "done\n";
print "\n";
exit(0);

sub shell($) {
  my($command) = @_;
  my($exit);
  $exit = system($command);
  die "Error in this command : $command\n" if($exit/256 != 0);
}

