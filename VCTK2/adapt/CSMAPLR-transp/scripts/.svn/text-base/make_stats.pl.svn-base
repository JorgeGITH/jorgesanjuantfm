$flist = $ARGV[0];
$alist = $ARGV[1];
$cmp_s = $ARGV[2];
$dur_s = $ARGV[3];

open(O1,"> $cmp_s");
open(O2,"> $dur_s");
open(I,"$flist");
for($i = 1;$line = <I>;$i++){
    chomp($line);
    print O1 "$i $line 1";
    print O2 "$i $line 1";
    for($s=1;$s<=5;$s++){
        print O1 " 0.0";
    }
    print O1 "\n";
    print O2 " 0.0\n"
}
close(I);
open(I,"$alist");
for(;$line = <I>;$i++){
    chomp($line);
    print O1 "$i $line 1";
    print O2 "$i $line 1";
    for($s=1;$s<=5;$s++){
        print O1 " 1.0";
    }
    print O1 "\n";
    print O2 " 1.0\n";
}
close(O1);
close(O2);

exit(0);

open(I,"$cmp_s");
open(O,"> $dur_s");
while($line = <I>){
    @list = split(/ /,$line);
    if($list[2] > 0){
        print O "$list[0] $list[1] $list[2] $list[2]\n";
    }
}
close(O);
close(I);
