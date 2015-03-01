#!/usr/bin/perl
require "./adapt.conf";
if(${SW9} == 1 ){ exit(0);}
print "===========================================================\n";
print "Speaker Transplantation\n";
shell(date);
print "===========================================================\n";
print "\n";
print "transp_baseline.pl\n";

open(CONFIG0,"<${LOCAL_CONFIG_0}")||die "can't open $LOCAL_CONFIG_0\n";
open(CONFIG,">${LOCAL_CONFIG}")||die "can't create $LOCAL_CONFIG\n";

print CONFIG "VC_PATH=${TOOL_VC}";
print CONFIG "WORKDIR=${WM_CLSA}";
print CONFIG "CSMAPLR=${WM_CLSA}";
print CONFIG "CSMAPLR_SCRIPT_DIR=${WM_CLSA}/scripts";
print CONFIG "CONVERTXFORMS=${WM_CLSA}/ConvertXform.py";

print CONFIG "MODELS=${MODELSDIR}";
print CONFIG "AVGNEU_DIR=${NAVGDIR}";
print CONFIG "HTSEMOBASE=${HTSEMOBASE}";
print CONFIG "HTSNEUBASE=${HTSNEUBASE}";
print CONFIG "HTSEMO=$HTSEMOBASE/${TRANSP_STYLE}";
print CONFIG "HTSNEU=${HTSNEUBASE}/${TRANSP_NEUTRAL_TARGET}";
print CONFIG "AVGNEU_TO_AVGSTYLE=${TRANSP_STYLE}"; #4 j
print CONFIG "SPKNEU=${TRANSP_NEUTRAL_TARGET}"; #5 i
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

