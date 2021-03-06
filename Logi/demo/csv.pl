#!/usr/bin/perl

BEGIN { 
	use Env qw(QR_ROOT QR_CGIROOT QR_BIN QR_HOME);
	push @INC, "$QR_CGIROOT";
	push @INC, "$QR_BIN";
	push @INC, "$QR_ROOT";

}

use Env qw(QR_ROOT QR_CGIROOT REMOTE_USER QR_BIN QR_HOME);

use strict;

$QR_CGIROOT="." if !$QR_CGIROOT;
$QR_ROOT=".." if !$QR_ROOT;

my $QR_MANDANT=substr($REMOTE_USER, 0, 4);

my $SCRIPTS="$QR_CGIROOT";


use POSIX qw(strtod setlocale LC_NUMERIC);
use Data::Dumper;
use Math::Round;
use File::Basename;
use Logi::Logi::main_new;
use Getopt::Long;

setlocale LC_NUMERIC, "de_DE.utf8";

$ENV{'LC_ALL'} = "de_DE.utf8";

sub uniq {
	my %seen;
        grep !$seen{$_}++, @_;
}

sub create_rg_files_from_csv {
	my $FH_DBG_in = shift;
	my $tmp_filelist_href = shift;
	my $tmp_barcode_href= shift;
	my $TRANSACTION_ID_FILE=shift;
	my $WORKDIR = shift;

	my $pid = $$;
	my $infile_count =1;


	#$FH_DBG = $FH_DBG_in;

	print "create_rg_files_from_csv\n";

	foreach my $source_file (keys %$tmp_filelist_href) {

		#push @{$filelist_href->{$source_file}{$rg_nr}}, [ $page_img, $page] if ($flag eq "P");




		my ($name, $path, $suffix) = fileparse($source_file, '\.[^\.]*');
		my $fname="$path$name";
		my $is_tiff=1;

		return 0 if ! -f $source_file;

		if ( "$suffix" =~/\.tif+/i ) {
			$is_tiff=1;
		} elsif ( "$suffix" =~ /\.pdf/i) {
			$is_tiff=0;
		} else {
			return 0;
		}

		my $tmp_img_file="$WORKDIR/tmp$pid"."_$infile_count"."_";

		if ($is_tiff) {
			#debug 1, "tiffsplit $name$suffix";
			my @tiff_cmd = ("tiffsplit", "$source_file", $tmp_img_file);
			if (system (@tiff_cmd)) {
				#debug 1, "ERROR: @tiff_cmd";
				return 0;
			}
		} else {
			#debug 1, "pdfsplit $name$suffix";
			my @pdf_cmd = ("pdftocairo", "-r", "300", "-tiff", "-gray", "$source_file", $tmp_img_file);
			if (system (@pdf_cmd)) {
				#debug 1, "ERROR: @pdf_cmd";
				return 0;
			}
		}


		my @tmpfiles = glob ("$WORKDIR/tmp$pid"."_$infile_count*");	

		for my $rg_seq (sort {$a <=> $b} keys %{$tmp_filelist_href->{$source_file}}) {
			print "source_file: $source_file $rg_seq\n";
			# my $rg_nr = get_transaction_id ($TRANSACTION_ID_FILE);

			for my $page (sort {$a <=> $b} @{$tmp_filelist_href->{$source_file}->{$rg_seq}}) {
				print "\tpage $page: ", $tmpfiles[$page-1], "\n";
				# push @{$filelist_href->{$source_file}->{$rg_nr}}, [ $fname, $page_counter];
			}
		}
		$infile_count ++;
		unlink @tmpfiles;
	}


}

sub read_input_csv_file {
	my $input_csv_file = shift;

	my %tmp_filelist = ();
	my %tmp_barcodes=();

	open (my $FH_INPUT_CSV, '<', $input_csv_file) or die "Could not open csv file $input_csv_file";

	my $last_rg_nr=1;
	my $input_line=1;
	while (<$FH_INPUT_CSV>) {

		my ($rg_nr, $source_file, $page, $page_img, $flag, $qrcode) = split /;/;

		chop;

		next if $flag ne "P";		# no page / deleted ...

		die "rechnungsnummern nicht fortlaufend: file $input_csv_file line $input_line rgnr: $rg_nr" if $rg_nr != $last_rg_nr && $rg_nr-1 != $last_rg_nr;

		die "Filename $source_file does not exists" if ! -f $source_file;
		die "Filename $source_file not tiff/pdf" if $source_file !~ /\.(pdf|tif+)$/i;

		$page = $rg_nr if !$page;		# sollte nicht passieren
		push @{$tmp_filelist{$source_file}{$rg_nr}}, $page;
		$tmp_barcodes{$rg_nr} .= $qrcode if $qrcode;

		#die "Filename $page_img not tiff" if $page_img !~ /\.tif+$/i;
		#my_die "Filename $page_img does not exists" if ! -f $page_img;

		$last_rg_nr = $rg_nr;
		$input_line++;

	}

	close $FH_INPUT_CSV;
	return (\%tmp_filelist, \%tmp_barcodes);
}







my $FH_DBG;




################################################################################
########################### MAIN
################################################################################


	my %parms = (
		buchcode => "",    
		steuercode => "",    
		belegnr => "",    
		gkonto => "",    
		kundennr => "",    
		pid => "",    
		buchsymbol   => "",      
		buchtype   => "",      
		buchdatum   => "",      
		comment   => "",      
		customer   => 0,      
		anz_rg_in   => "",      
		transaction_id   => "",      
		debug_level   => 2,      
		rerun_timestamp   => 0,      
		myuid   => "",      
		input_csv_file   => "",      
		periode_in   => "",      		# !!!
		email   => "",      
		jahr   => "",      
		denoise   => "",      
		with_ocr_file   => "",      
		no_sort   => 0,      
		no_tesseract   => 0,      
		do_skonto   => 0,      
		gvision   => 1,      
		no_ust   => 0,      
		e_a   => 0,      
		tessopt1   => "",      
		rpc   => 0,      
		QR_ROOT   => $QR_ROOT,
		QR_CGIROOT   => $QR_CGIROOT,
		REMOTE_USER   => $REMOTE_USER,
		QR_BIN   => $QR_BIN,
		QR_HOME   => $QR_HOME,
		verbose  => "");  

my $result = GetOptions (
		"buchcode=i" => \$parms{buchcode},    # numeric
		"steuercode=i" => \$parms{steuercode},    # numeric
		"belegnr=i" => \$parms{belegnr},    # numeric
		"gkonto=i" => \$parms{gkonto},    # numeric
		"kundennr=i" => \$parms{kundennr},    # numeric
		"pid=i" => \$parms{pid},    # numeric
		"buchsymbol=s"   => \$parms{buchsymbol},      # string
		"buchtype=i"   => \$parms{buchtype},      # string
		"buchdatum=s"   => \$parms{buchdatum},      # string
		"kommentar=s"   => \$parms{comment},      # string
		"rechnungen=i"   => \$parms{anz_rg_in},      # numeric
		"transaction=i"   => \$parms{transaction_id},      # numeric
		"stat=i"   => \$parms{transaction_id},      # 2nd statusfile
		"debug_level=i"   => \$parms{debug_level},      # numeric
		"timestamp=i"   => \$parms{rerun_timestamp},      # numeric
		"customer=i"   => \$parms{customer},      # numeric
		"bereich=s"   => \$parms{bereich},      # string
		"uid=s"   => \$parms{myuid},      # string
		"csv=s"   => \$parms{input_csv_file},      # string
		"remote_csv=s"   => \$parms{remote_csv_file},      # string
		"periode=s"   => \$parms{periode_in},      # string
		"email=s"   => \$parms{email},      # string
		"jahr=i"   => \$parms{jahr},      # string
		"denoise"   => \$parms{denoise},      # flag
		"with_ocr_file"   => \$parms{with_ocr_file},      # flag
		"no_sort"   => \$parms{no_sort},      # flag
		"no_tesseract"   => \$parms{no_tesseract},      # flag
		"skonto"   => \$parms{do_skonto},      # flag
		"ust=i"   => \$parms{no_ust},      # flag
		"ustermittlung=i"   => \$parms{no_ust},      # flag
		"e_a=i"   => \$parms{e_a},      # flag
		"gewinnermittlung=i"   => \$parms{e_a},      # flag
		"tessopt1"   => \$parms{tessopt1},      # flag
		"rpc"   => \$parms{rpc},      # flag
		"single_inv=i" => \@{$parms{single_invoices}},
		"empty_rec=i" => \@{$parms{process_empty_pages}},
		"verbose"  => \$parms{verbose});  # flag

	if ($#ARGV <  0 && !$parms{input_csv_file} && !$parms{remote_csv_file}) {
		print "usage: logi.pl <sourcefiles>\n";
		exit;
	}






	print Dumper(\%parms);

	my $FH_DBG;
	my $TRANSACTION_ID_FILE="XXX";
	my $WORKDIR=".";

	my ($tmp_filelist_ref, $tmp_barcode_ref) = read_input_csv_file ($parms{remote_csv_file});

	#create_rg_files_from_csv ($FH_DBG, $tmp_filelist_ref, $tmp_barcode_ref, $TRANSACTION_ID_FILE, $WORKDIR);

	$parms{remote_file_list} = $tmp_filelist_ref;
	$parms{remote_barcode_list} = $tmp_barcode_ref;
	#$parms{gvision} = 1;
	#$parms{debug_level} = 2;
	
	main::logisthai (\%parms, null, null ,\@ARGV);
