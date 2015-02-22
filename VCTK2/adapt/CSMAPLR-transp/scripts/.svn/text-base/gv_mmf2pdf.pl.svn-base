@pdf = ("","","","");

$mmf = $ARGV[0];
$pdf[1] = $ARGV[1];
$pdf[2] = $ARGV[2];
$pdf[3] = $ARGV[3];
$sptk = $ARGV[4];

open(I,"$mmf");
while($line = <I>){
    chomp($line);
    if(index($line,"<STREAM> ") == 0 || index($line,"<Stream> ") == 0 || index($line,"<stream> ") == 0){
	$stream = substr($line,9);
	if(1 <= $stream && $stream <= 3){
	    $line = <I>;
	    $line = <I>;
	    chomp($line);
	    system("echo \"$line\" | $sptk/x2x +ad > $pdf[$stream]");
	    $line = <I>;
	    $line = <I>;
	    chomp($line);
	    system("echo \"$line\" | $sptk/x2x +ad >> $pdf[$stream]");
	}
    }
}
close(O);
