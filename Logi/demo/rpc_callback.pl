#!/usr/bin/perl

BEGIN { 
	use Env qw(QR_ROOT QR_CGIROOT QR_BIN HOME);
	push @INC, "$QR_ROOT";
	push @INC, "/home/andi";
}

use Logi::rpc::RemoteCall qw(call);
use Logi::rpc::Data;


use JSON;
use Data::Dumper;






use strict;

use POSIX qw(strtod setlocale LC_NUMERIC);
use locale;
use File::Basename;
use Math::Round;
use Getopt::Long;
use Fcntl qw ( LOCK_EX SEEK_SET );
use DateTime;
use DateTime::Format::Strptime;
use File::Copy qw(copy);
use Image::Size;
use YAML qw(LoadFile Load);

use Env qw(QR_ROOT QR_CGIROOT REMOTE_USER);

$QR_CGIROOT="." if !$QR_CGIROOT;
$QR_ROOT=".." if !$QR_ROOT;

my $QR_MANDANT=substr($REMOTE_USER, 0, 4);


my $FH_DBG;
my $buchdatum;
my $date_max;
my $date_min;
my $date_min_e_a;			# E/A Rechner
my $buchdatum_first_day;
my $myuid;

setlocale LC_NUMERIC, "de_DE.utf8";

$ENV{'LC_ALL'} = "de_DE.utf8";


my $debug_level=2;

##################################################

sub debug {
	my $level = shift;
	return if $level>$debug_level;
	print $FH_DBG "($level) " if ($debug_level > 1); 
	foreach my $v (@_) {
		print $FH_DBG "$v";
	}
	print $FH_DBG "\n";
}

##################################################

sub form {
	my $val=$_[0];
	# debug 3, "form: ret: ", sprintf ("%.02f", round ($val*100)/100);
	return sprintf ("%.02f", round ($val*100)/100);
}

##################################################


my $pdf_file="";
my $my_uid="";
my $e_a=0;
my $verbose;
my $buchtype;	# 1 ER; 2 AR; 3 KA
my $kundennr;
my $buchsymbol;




my @input_files = @ARGV;		# ohne page sep
my $source_files = join (' ', @_);	# array of inputfiles

my $debug_file = "ocr_client.dbg";
open ($FH_DBG, '>>', $debug_file) or die "Could not create debug file $debug_file";
debug 1, "********************************************************************************";

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
my $current_date=sprintf ("%04d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min, $sec);

debug 1, "debug opened $current_date debug_level: $debug_level";


	my @tess_files = @ARGV;
	my $rg_nr = 1111;

	$kundennr = "288888" if !$kundennr;
	my $mandant_id=1;
	my $rpc_server = "http://cloud09.xion.at/cgi-bin/ocr_server.pl";


print "> sender begin ";
print `date +"%T.%N"`;


        my $req = Logi::rpc::Data->new;

	$req->set_function('Xqueue_callback');
	$req->add_data("mandant", $mandant_id);
	$req->add_data("client", $kundennr);


	#### add files to request


	#### send request to remote server and store response (response is a json string)
	my $res = call($rpc_server, $req);


## DEBUG START ##
	print "> sender got response ";
	print `date +"%T.%N"`;
## DEBUG END ##


print "*** $res";
print "\n";
my $data = decode_json($res);



print Dumper(\$data);

debug 1, "debug closed $current_date";
