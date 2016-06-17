#!/usr/bin/perl -w
#$|=1;
#versione 20160502
use Getopt::Long;
use File::Find;
use Fcntl 'SEEK_SET';
use strict;
my %output=();
my @queue_dirs=();
my $key;my @tmp=();
my ($go_match,$match_and,$msg_cnt);

sub print_help {
print "$0 -a -s|-d|-r|-m|-c|-h|-o|-j|-e|-b [-S -R -C -H -J -O -B string to match] --help\n";
print "	-s view sender\n";
print "	-S match sender\n";
print "	-f view From\n";
print "	-F match From\n";
print "	-r view standing rcpt\n";
print "	-d view done rcpt\n";
print "	-R match original recipient\n";
print "	-c view client address\n";
print "	-C match client address\n";
print "	-h view helo name\n";
print "	-H match helo name \n";
print "	-o view origin\n";
print "	-O match origin\n";
print "	-j view subject\n";
print "	-J match subject\n";
print "	-e view errto\n";
print "	-E match errto\n";
print "	-u view sasl login\n";
print "	-U match sasl login\n";
print "	-t older then time\n";
print "	-T newer then time\n";
print "	-B match Body\n";
print "	-b limit the Body search to the first n line (default 100)\n";
print "	-m print mail not domain\n";
#print "	-a exclude active queue\n";
#print "	-i exclude incoming queue\n";
print "	-l postfix_id listing mode (postuper -)\n";
print " --listip list ips insthead of session-id\n"; 
print " --listsubj list ips insthead of session-id\n"; 
print " --listuser list sasl user insthead of session-id\n"; 
print " --listsnd list sender user insthead of session-id\n"; 
print " --listrcpt list recipient user insthead of session-id\n"; 
print " --listrrcpt list recipient user insthead of session-id\n"; 
print " --listdrcpt list recipient user insthead of session-id\n"; 
print " --cut truncate subject\n"; 
print " --url list found urls\n"; 
print " --url-ip list url resolved ip\n"; 
print " --url-ip-match list url resolved ip\n"; 
print " --bhost list bouncing hosts\n"; 
print " --no-active exclude active queue from search\n"; 
print " --no-incoming exclude active queue from search\n";
print " --no-deferred exclude deferred queue from search\n";
print " --maildrop include maildrop queue in search\n"; 
print " --hold scan the hold queue\n"; 
print " --flush set $|=1 avoid this in normal operations\n"; 
print " --filter match filter name\n"; 
print " --or\n"; 
print "	--whole workaround for record pointer,run read until eof\n";
print " --dir set postfix spool other than /var/spool/postfix\n";
print "	--help help\n";
}

sub die_help {
&print_help;
die;
}


Getopt::Long::Configure ("bundling");
my ($help, $opt_d, $opt_cut, $opt_B, $opt_b,$opt_m,
	$opt_s,$opt_r,$opt_c,$opt_j,$opt_h,$opt_o,$opt_e,$opt_f,$opt_t,$opt_u,
	$opt_S,$opt_R,$opt_C,$opt_J,$opt_H,$opt_O,$opt_E,$opt_F,$opt_T,$opt_U,
	$opt_noactive,$opt_noincoming,$opt_nodeferred,$opt_hold,$opt_maildrop,
	$opt_or,$opt_l, $opt_L,$opt_PL,
	$opt_listip,$opt_listsubj,$opt_listuser,
	$opt_listsnd,$opt_listrcpt,$opt_listrrcpt,$opt_listdrcpt,
	$opt_flush,$opt_url,$opt_url_ip,$opt_url_ip_match,$opt_bhost,$opt_whole,
	$opt_postdir,$opt_samples)=
	(0,0,0,0,100,0,		#output opt
	0,0,0,0,0,0,0,0,0,0,	#record opt
	0,0,0,0,0,0,0,0,0,0,	#record match opt
	0,0,0,0,0,	 	#queue opt
	0,0,0,0,		#list
	0,0,0,			#list
	0,0,0,0,		#list
	0,0,0,0,0,0,
	'/var/spool/postfix',0
	);

GetOptions ("help" => \$help,   'cut=i' =>\$opt_cut, 'd' =>\$opt_d, 'B=s' =>\$opt_B,'b=i' =>\$opt_b,
		's' =>\$opt_s,  'r' =>\$opt_r,  'c' =>\$opt_c,
	 	'S=s' =>\$opt_S,'R=s' =>\$opt_R,'C=s' =>\$opt_C,
		'h' =>\$opt_h,  'o' =>\$opt_o,  'j' =>\$opt_j,
		'H=s' =>\$opt_H,'O=s' =>\$opt_O,'J=s' =>\$opt_J,
 		'f' =>\$opt_f,  'e' =>\$opt_e,  't=i' =>\$opt_t, 'u'=>\$opt_u,
		'F=s' =>\$opt_F,'E=s' =>\$opt_E,'T=i' =>\$opt_T, 'U=s' => \$opt_U,
		'l' =>\$opt_l, 
		'listip'=> \$opt_listip, 'listsubj'=> \$opt_listsubj,'listuser'=> \$opt_listuser,
		'listsnd'=> \$opt_listsnd,
		 'listrcpt'=> \$opt_listrcpt,
		 'listdrcpt'=> \$opt_listdrcpt,
		 'listrrcpt'=> \$opt_listrrcpt,
		'no-active' =>\$opt_noactive,	'no-incoming' =>\$opt_noincoming,'no-deferred'=>\$opt_nodeferred, 'hold' =>\$opt_hold,"maildrop"=>\$opt_maildrop,
		'm' =>\$opt_m,  'or' =>\$opt_or,'filter=s'=>\$opt_L,'pfilter'=>\$opt_PL,
		'url'=>\$opt_url,'url-ip'=>\$opt_url_ip ,'url-ip-match=s'=>\$opt_url_ip_match ,'bhost'=>\$opt_bhost
		,'flush'=>\$opt_flush,'whole'=>\$opt_whole 
	 	,'samples=i' =>\$opt_samples
		,'dir=s'=>\$opt_postdir)|| &die_help;


#print join(':',$opt_S,$opt_R,$opt_C,$opt_H,$opt_O,$opt_J,$opt_F,$opt_E,$opt_t,$opt_T)."\n";
if ($help) 
	{&print_help; exit};

$go_match=0;
$match_and=1;
$msg_cnt=0;
if (
	($opt_S)|| ($opt_R)||
	($opt_C)|| ($opt_H)||
	($opt_O)|| ($opt_F)||
	($opt_E)|| ($opt_t)||
	($opt_T)|| ($opt_J)||
	($opt_B)|| ($opt_L)||
	($opt_url_ip_match)||
	($opt_U)
	)
	{$go_match=1;}
if (($opt_h) ||($opt_c)
	||($opt_o)||($opt_j)||($opt_u)
	||($opt_url)||($opt_url_ip)||($opt_url_ip_match)||($opt_bhost)
	||($opt_L)
	||($opt_listsubj)
	||($opt_listuser)
	||($opt_listsnd)
	||($opt_listrcpt)
	)
	{$opt_m=1;}
if ($opt_or)
	{$match_and=0}

if ($opt_flush)
	{$|=1;}


my @scan_dirs=();
push @scan_dirs,$opt_postdir.'/deferred/'unless ($opt_nodeferred);
push @scan_dirs,$opt_postdir.'/active/' unless ($opt_noactive);
push @scan_dirs,$opt_postdir.'/incoming/' unless ($opt_noincoming);
push @scan_dirs,$opt_postdir.'/maildrop/' if ($opt_maildrop);

if ($opt_hold)
	{@scan_dirs=($opt_postdir.'/hold/')};
find(\&leggi_mailq,@scan_dirs);
if ($opt_l || $opt_listip || $opt_listsubj || $opt_listuser || $opt_listsnd ||$opt_listrcpt )
	{exit 0}
else	{
	#out finale
	my $tot=0;
	foreach $key (keys %output) {
		push @tmp,"$output{$key} $key";
		$tot=$tot+$output{$key};
		}
	
	@tmp=sort{ ($a=~ /^(\d+) /)[0]<=>($b=~ /^(\d+) /)[0] || ($a=~ /^\d+ (.*)/)[0] cmp ($b=~ /^\d+ (.*)/)[0]} @tmp;
	print join ("\n",@tmp,"\n");
	print "Totale: $tot\n";
	}

sub leggi_mailq
{
#azzero 
#my @headers=(); 
my $filename=$_;
my ($sel_record,$client,$hello,$origin,$login
	,$errto,$sender,$from,$subject
	,$tstamp,$filter,$url_tmp,$url_tmp_ip,$url_tmp_host,$url_tmp_proto,$bhost_tmp)=
 	('','NULL_CLIENT','NULL_HELLO','NULL_ORIGIN','NULL_LOGIN'
	,'NULL_ERRTO','NULL_SENDER','NULL_FROM','NULL_SUBJECT'
	,0,'NULL_FILTER','','','');
my ($rec_tmp,$rec_type,$last_record
	,$rec_cnt,$body_match,$url_ip_match)=
	('','',''
	,0,0,0);
my $msg_fh;
my @sel_data=(); my @rrcpts=(); my @done=(); my @rcpts=(); my @urls=(); my @url_ip; my @tmp_ary=();

if (!(-f $File::Find::name)){return 0};
$msg_cnt++;
if ( ($opt_samples > 0)
	&& ($msg_cnt > $opt_samples) )
	{return 0;}
#open (FILE,"</var/spool/postfix/deferred/0/09F163CDF2")|| print  "Errore $File::Find::name $!\n";
#open (FILE,"</var/spool/postfix/deferred/0/081B831A39")|| print  "Errore $File::Find::name $!\n";
#open ($msg_fh,"</home/spaolo/081B831A39")|| print  "Errore $File::Find::name $!\n";
#open ($msg_fh,"</home/spaolo/09F163CDF2")|| print  "Errore $File::Find::name $!\n";
#open (FILE,"</var/spool/postfix/deferred/0/084962C3BF")|| print  "Errore $File::Find::name $!\n";
#open ($msg_fh,"</var/spool/postfix/deferred/F/F331C30804")|| print  "Errore $File::Find::name $!\n";
#open ($msg_fh,"</home/spaolo/9CB163231C")|| print  "Errore $File::Find::name $!\n";
#open ($msg_fh,"</home/spaolo/DB7E22F2CA5")|| print  "Errore $File::Find::name $!\n";
#open ($msg_fh,"</home/spaolo/DB7E22F2CA5")|| print  "Errore $File::Find::name $!\n";
#open ($msg_fh,"</var/spool/postfix/deferred/4/4ADA1432C64")|| print  "Errore $File::Find::name $!\n";
open ($msg_fh,"<$File::Find::name")|| print  "Errore $File::Find::name $!\n";
#print STDERR "open $File::Find::name\n";

#read $msg_fh,$rec_tmp,65,0;
#$rec_tmp=~m/.*\s(\d+)$/;
if    (($opt_e)||($opt_E)){$last_record='e';}
#elsif (($opt_j)||($opt_J)){$last_record='X';}
#elsif (($opt_f)||($opt_F)){$last_record='X';}
elsif ( ($opt_j)||($opt_J) || ($opt_listsubj)
	||($opt_B)||($opt_url)
	||($opt_f)||($opt_F)
	||($opt_url_ip)||($opt_url_ip_match)
	||($opt_bhost)
	)
	{$last_record='X';}
else {$last_record='M'}

if ($opt_whole)
	{$last_record='E';}

my $rec_len;
while (defined ($rec_type)
	 &&($rec_type ne $last_record ))
{
($rec_type,$rec_tmp,$rec_len)=&read_record($msg_fh);
#####
#DEBUG
#print "$rec_type\t$rec_len\t$rec_tmp\n";
if ($rec_len == -1)
	{#print "ERRORE in $File::Find::name EOF \n";
	last}
if    ($rec_type eq 'S') {$sender=$rec_tmp;}
elsif ($rec_type eq 'T') {$tstamp=$rec_tmp;$tstamp=~s/ .*$//;}
elsif ($rec_type eq 'A') {
			if ((($opt_c)||($opt_C)||($opt_listip))&&($rec_tmp=~ /^client_address=(.*)/)) {$client=$1}
			elsif ((($opt_h)||($opt_H))&&($rec_tmp=~ /^helo_name=(.*)/))   {
											$hello=$1;
											if ($opt_cut)
												{
												@tmp_ary=();
												@tmp_ary=split(/\./,$hello);
												#splice ARRAY,OFFSET,LENGTH
												if ($opt_cut < $#tmp_ary)
													{
													splice (@tmp_ary,0,($#tmp_ary-$opt_cut+1));
													$hello=join('.',@tmp_ary);
													}
												}
											}
			elsif ((($opt_o)||($opt_O))&&($rec_tmp=~ /^message_origin=(.*)/)) {$origin=$1}
			elsif ((($opt_u)||($opt_U)||($opt_listuser))&&($rec_tmp=~ /^sasl_username=(.*)/)) {$login=$1}
			#push @headers,$rec_tmp;
			}
elsif ($rec_type eq 'R') {push @rrcpts,$rec_tmp;}
elsif ($rec_type eq 'D') {push @done,$rec_tmp;}
elsif ($rec_type eq 'O') {push @rcpts,$rec_tmp;}
elsif ($rec_type eq 'L') {$filter=$rec_tmp;}

#record pointer salto al prossimo
elsif ($rec_type eq 'p') 
	{
	sysseek($msg_fh,$rec_tmp,SEEK_SET) if ($rec_tmp >0); 
	}
#elsif (($rec_type eq 'M')||
elsif	($rec_type eq 'N') {
				if (($opt_b>0) && ($rec_cnt > $opt_b))
						{$rec_type='X';}
				if ( (($opt_f)||($opt_F))
						&&( $from eq 'NULL_FROM' )
						&&($rec_tmp=~ /^From:\s+(.+)\s*$/)
					)
						{ 
						$from=$1; 
						#$from=~ s/\s.*$/;
						if ($from=~ /<([^>]*)>/)
							{$from=$1};
						if ( ($opt_j)||($opt_J)
							||($opt_bhost)||($opt_B)) 
							#||($opt_b)||($opt_B)) 
							{ $rec_type='N'} else	{ $rec_type='X'}
						}
				if ( (($opt_j)||($opt_J)||($opt_listsubj)) 
					&& ( $subject eq 'NULL_SUBJECT' ) 
					&& ($rec_tmp=~ /^Subject:\s+(.*)/i) 
						) #MATCH only first subject
						{ $subject=$1;
						if ($opt_cut){$subject=substr $subject,0,$opt_cut;}
						if ( ($opt_f)||($opt_f)
							||($opt_bhost)||($opt_B)) 
							#||($opt_b)||($opt_B)) 
							{ $rec_type='N'} 
						else	{ $rec_type='X'}
						}
				if ($opt_B)
						{
						if ($rec_tmp=~ /$opt_B/)
							{$body_match=1;
							if ( ($opt_j)||($opt_J)
								||($opt_f)||($opt_F)) 
								{ $rec_type='N'} 
							else	{ $rec_type='X'}
						#$rec_type='X';
							}
						$rec_cnt++;
						}
				if (($opt_url)
					||($opt_url_ip)
					||($opt_url_ip_match))
						{
						#if ($rec_tmp=~ /http:\/\/([\w|\d|\.|-|\/]+)/i)
						if ($rec_tmp=~ /(https?):\/\/(\S+)/i)
							{
							$url_tmp_proto=$1;
							$url_tmp=$2;
							unless ($url_tmp=~ /www.w3.org/)
								{
								$url_tmp_host=$url_tmp;
								$url_tmp_host=~s/\/.*$//;
								if (($opt_url_ip)||($opt_url_ip_match))
									{
									#$url_tmp_ip=`host $url_tmp 212.97.35.24|grep "has address"`;
									$url_tmp_ip=`dig \@212.97.32.2 $url_tmp_host +noall +answer|grep "IN	A"`;
									$url_tmp_ip=~s/[\S]+\s+IN\s+A\s+//gs;
									push @urls,split (/\n/,$url_tmp_ip);
									if ($url_tmp_ip=~ /$opt_url_ip_match/gs)
										{#print "$url_tmp_ip $opt_url_ip_match\n"; 
										$url_ip_match=1; }
									}
								else 
									{push @urls,$url_tmp_proto."://".$url_tmp;}
							#	$rec_type='X';
								}
							}
						$rec_cnt++;
						}
				if ($opt_bhost)
					{
						if ($rec_tmp=~ /^<([^@]+@[^\>]+)>: host ([^\]]+)\[([^\]]+)\] said: /)
							#Diagnostic-Code: X-Postfix; host mail.rusconi.it[212.97.56.117] said:
							{
							#$bhost_tmp=$2;
							$bhost_tmp=$2;
							$rec_type='X';
							}
					}
			}
elsif ($rec_type eq 'e') {$errto=$rec_tmp;
			#print "$File::Find::name $sender record e $rec_tmp\n";
			}
#if ($rec_type eq 'X') {last;}

}
close $msg_fh;

@sel_data=();
#solo se sender o uno dei destinatari destinatario 
#if (($go_match==0)||
#	($opt_S&&($sender=~ /$opt_S/)) || 
#	($opt_J&&($subject=~ /$opt_J/)) || 
#	($opt_R&&(scalar(grep(/$opt_R/,@rcpts)) > 0))||
#	($opt_C&&($client eq $opt_C))||
#	($opt_O&&($origin eq $opt_O))||
#	($opt_H&&($hello eq $opt_H)))
if (($go_match==0)                     
        || (($match_and==0)&&
                (($opt_S&&($sender=~ /$opt_S/)) || 
                 ($opt_J&&($subject=~ /$opt_J/)) || 
                 ($opt_R&&(scalar(grep(/$opt_R/,@rcpts)) > 0))|| 
                 ($opt_C&&($client eq $opt_C))|| 
                 ($opt_O&&($origin eq $opt_O))|| 
                 ($opt_U&&($login eq $opt_U))|| 
                 ($opt_F&&($from=~ /$opt_F/))|| 
                 ($opt_E&&($errto=~ /$opt_E/))|| 
                 ($opt_t&&($tstamp < $opt_t))|| 
                 ($opt_T&&($tstamp > $opt_T))|| 
                 ($opt_H&&($hello eq $opt_H))||
                 #(($opt_L && $filter)&&($filter eq $opt_L))||
		 ($opt_B&& $body_match)||
		($url_ip_match)
                )
        )
        ||(($match_and==1) &&
                ((!$opt_S||($sender=~ /$opt_S/)) &&
                 (!$opt_J||($subject=~ /$opt_J/)) &&
                 (!$opt_R||(scalar(grep(/$opt_R/,@rcpts)) > 0))&&
                 (!$opt_C||($client eq $opt_C))&&
                 (!$opt_O||($origin=~ /$opt_O/))&&
                 (!$opt_U||($login eq $opt_U))&&
                 (!$opt_F||($from=~ /$opt_F/))&&
                 (!$opt_E||($errto=~ /$opt_E/))&&
                 (!$opt_t||($tstamp < $opt_t))&&
                 (!$opt_T||($tstamp > $opt_T))&&
                 (!$opt_H||($hello=~ /$opt_H/))&&
                 (!$opt_L||($filter=~ /$opt_L/))&&
                 (!$opt_B||$body_match)&&
		(!$opt_url_ip_match||$url_ip_match)
                )
        )
)

{
if    ($opt_s) {@sel_data=($sender);}
elsif ($opt_r) {@sel_data=@rrcpts;}
elsif ($opt_d) {@sel_data=@done;}
elsif ($opt_c) {@sel_data=($client);}
elsif ($opt_h) {@sel_data=($hello);}
elsif ($opt_o) {@sel_data=($origin);}
elsif ($opt_u) {@sel_data=($login);}
elsif ($opt_j) {@sel_data=($subject);}
elsif ($opt_f) {@sel_data=($from);}
elsif ($opt_e) {@sel_data=($errto);}
elsif ($opt_PL) {@sel_data=($filter);}
elsif ($opt_l) {print "$filename\n";}
elsif ($opt_listip) {print "$client\n";}
elsif ($opt_listsubj) {print "$subject\n";}
elsif ($opt_listuser) {print "$login\n";}
elsif ($opt_listsnd) {print "$sender\n";}
elsif ($opt_listrrcpt) {print join("\n",@rrcpts)."\n";}
elsif ($opt_listdrcpt) {print join("\n",@done)."\n";}
elsif ($opt_listrcpt) {print join("\n",@rcpts)."\n";}
elsif ($opt_url) {@sel_data=@urls;}
elsif ($opt_url_ip) {@sel_data=@urls;}
elsif ($opt_bhost) {@sel_data=($bhost_tmp);}
else 		 {@sel_data=@rcpts;}
}

foreach $sel_record (@sel_data)
{
if (!($opt_m)
	&&($sel_record=~m/.*\@(.*)/))
	{$sel_record=$1;}
	
if (defined ($output{$sel_record}))
	{$output{$sel_record}+=1}
else	{$output{$sel_record}=1};
#$output{$sel_record}++;
}
#undef @headers=();
undef @rrcpts=(); undef @done=(); undef @rcpts=();
#undef $tstamp;
undef $sender;
undef $rec_tmp;undef $rec_type;
undef @sel_data;undef $sel_record;
}

sub read_record()
{
my $file=shift;
my ($rec_type,$rec_data)='';
my ($shift,$byte_tmp,$byte_len,$rec_len)= (0,0,0,0);
my $rc;
#$rec_type=getc($file);
#$rec_type=sysread($file);
$rc=sysread($file,$rec_type,1,0);
#print STDERR "read_record type $rec_type rc $rc\n";
#if ( (defined $rc) && ($rc ==1 ) )
if ( $rc==1 )
{
	do {
	$rc=sysread($file,$byte_tmp,1,0);
#	print STDERR "read_record rc $rc len part $byte_tmp\n";
	#$byte_tmp=getc($file);
	#$byte_len=ord(getc($file));
	#if (defined($byte_tmp))
	if ( $rc !=1 )
		{return ($rec_type,'',-1)}
	#print STDERR "read_record rc $rc len part $byte_tmp\n";
	if ( defined($byte_tmp) )
		{ $byte_len=ord($byte_tmp) }
	else {return ($rec_type,'',-1)}
	$rec_len|=( 0x7F & $byte_len) << $shift;
	$shift+=7;
	}while (($byte_len>=0x80) && ($rc >0) );
}
else {
	#print STDERR "read_record error reading rectype\n";
	return ($rec_type,'',-1);
	}
#else {$rec_len=-1;}
if ($rec_len >0) 
	{$rc=sysread($file,$rec_data,$rec_len,0);
	if ($rec_len != $rc)
		{ $rec_data=''; $rec_len=-1; }
		#{die "error $rec_len ne $rc";}
	unless ( defined ($rec_data) )
		{ $rec_data=''; $rec_len=-1; }
	}
else 	{$rec_data='';}
#print STDERR "read_record $rec_len == $rc data $rec_data\n";
undef $byte_len;
return($rec_type,$rec_data,$rec_len);
}

#changelog
#20130711
#--flush
#20130625
#--list[ip|user|subject]
#20121222
# -bB -jJ -fF not mutually exclusive anymore
#print " -b/-B , -f/-F , -J/-j are alternative\n";
# -fF better string parsing
#20131202
#--whole for recipients listed near EOF
#20150122
#support for pointer record type
#20160502
#limit search to n mails
