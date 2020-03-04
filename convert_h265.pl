#!/usr/bin/perl
# korolev-ia [at] yandex.ru

use File::Which;
use Getopt::Long;
use Cwd;
use File::Basename;
use File::Find;
use Data::Dumper;
use JSON;

my $version = "1.0 20200304";
my $video_extensions =
"avi|mkv|mov|mp4|webm|flv|m2ts|mts|qt|wmv|asf|amv|m4p|m4v|mpg|mp2|mpeg|mpe|mpv|m2v|m4v|svi|3gp|3gp2|mxf|nsv";
my $basedir = dirname($0);
chdir($basedir);
my $curdir = getcwd();
mkdir("log");
mkdir("tmp");
mkdir("data");

my $logFile = "$curdir/log/$0.log";
my $videoFilesDataFile="$curdir/data/video_files_info.json";
my @videoFiles=();
my $videoFilesData={};

my $defIn      = "";
my $defFfmpeg  = "ffmpeg";
my $defFfprobe = "ffprobe";
my $defCpu     = 1;

my $once = 0;

my ( $in, $cpu, $backup, $ffmpeg, $ffprobe, $help );

GetOptions(
    'in=s'      => \$in,
    'backup'    => \$backup,
    'ffmpeg=s'  => \$ffmpeg,
    'ffprobe=s' => \$ffprobe,
    'cpu=n'  => \$cpu,
    "help|h|?"  => \$help
);

$in      = ($in)      ? $in       : $defIn;
$cpu      = ($cpu)     ? int($cpu) : $defCpu;
$backup  = ($backup)  ? 1         : 0;
$ffmpeg  = ($ffmpeg)  ? $ffmpeg   : $defFfmpeg;
$ffprobe = ($ffprobe) ? $ffprobe  : $defFfprobe;



if ($help) {
    show_help();
}

unless ($ffmpeg) {
    $ffmpeg = which 'ffmpeg';
}
unless ($ffprobe) {
    $ffmpeg = which 'ffprobe';
}
if ( !-f "$ffmpeg" ) {
    show_help(
        'Please, set the path to ffmpeg in enviroment or use option --ffmpeg ');
    exit(1);
}
if ( !-f "$ffprobe" ) {
    show_help(
        'Please, set the path to ffprobe in enviroment or use option --ffprobe '
    );
    exit(1);
}
w2log("INFO: Script started");
w2log("INFO: Parameters: --in='$in' --cpu=$cpu");
if ( !-d $in ) {
    w2log("EROOR: Do not exist input dir '$in'");
    exit(1);
}
w2log("INFO: Will use ffmpeg binary: '$ffmpeg'");
w2log("INFO: Will use ffprobe binary: '$ffmpeg'");

if( -e $videoFilesDataFile) {
    w2log("INFO: Read info from datafile: '$videoFilesDataFile'");
    $videoFilesData=decode_json( ReadFile( $videoFilesDataFile) );
}


find( \&wanted, $in );

foreach my $file (@videoFiles) {
    if( $videoFilesData->{$file}->{'encoded'} ) {        
        next;
    } else {
        $videoFilesData->{$file}->{'started'} =get_date();
        my $videoInfo=getVideoInfo( $file);
        #if( $videoInfo->{'streams'}[0]->{'codec_name'}==='hevc' ) {
        #    w2log("INFO: Read info from datafile: '$videoFilesDataFile'");
        #}
        if( runEncoding( $file ) ) {

        }
        $videoFilesData->{$file}->{'finished'} =get_date();
    }
}


print Dumper(@videoFiles);

sub show_help {
    my $msg = shift;
    print STDERR ("##	$msg\n\n") if ($msg);
    print STDERR (
        "Version $version
This script converting video files to H.265 codec 
Usage: $0 --in=/path/input [--backup] [--cpu 1] [--ffmpeg=/path/to/ffmpeg][--ffprobe=/path/to/ffprobe]  [--help]
Where:
 --in=/path/input - search videos from this folder 
 --cpu 1 - define how many CPUs use for transcoding. Possible values: 0 - mean use all CPUs, from 1 to all CPU cores ( can be checked with 'nproc' linux command ), default -1.
 --backup - do not remove original video file. File will be ranamed to 'original_video_filename.backup'
 --ffmpeg=/path/to/ffmpeg - path to ffmpeg binariy ( by default using 'ffmpeg', must be found in environment PATH )
 --ffprobe=/path/to/ffprobe - path to ffprobe binariy ( by default using 'ffprobe', must be found in environment PATH )
 --help - this help
Sample:	${0} --in=/mediaserver/media/tv --cpu 1 --ffmpeg=/opt/ffmpeg/bin/ffmpeg --ffprobe=/opt/ffmpeg/bin/ffprobe 
"
    );
    #print "Press ENTER to exit:";
    #<STDIN>;
    exit(1);
}

 sub wanted {
    if( /\.($video_extensions)$/i )  {
        push( @videoFiles, $File::Find::name) ;
    } 
 }

sub w2log {
    my $msg = shift;
    open( LOG, '>>', $logFile ) || print("Can't open file $logFile. $msg");
    print LOG get_date() . "\t$msg\n";
    print STDERR get_date() . "\t$msg\n";
    close(LOG);
}

sub get_date {
    my $time   = shift() || time();
    my $format = shift   || "%s-%.2i-%.2i %.2i:%.2i:%.2i";
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime($time);
    $year += 1900;
    $mon++;
    return sprintf( $format, $year, $mon, $mday, $hour, $min, $sec );
}

sub ReadFile {
	my $filename=shift;
	my $ret="";
	open (IN,"<",$filename) || w2log("Can't open file $filename") ;
		while (<IN>) { $ret.=$_; }
	close (IN);
	return $ret;
}	

sub WriteFile {
	my $filename=shift;
	my $body=shift;
	unless( open (OUT,">", $filename)) { w2log("Can't open file $filename for write" ) ;return 0; }
	print OUT $body;
	close (OUT);
	return 1;
}	

sub AppendFile {
	my $filename=shift;
	my $body=shift;
	unless( open (OUT,">>", $filename)) { w2log("Can't open file $filename for append" ) ;return 0; }
	print OUT $body;
	close (OUT);
	return 1;
}


sub getVideoInfo
{
    my $input=shift;
    my $cmd = "$ffprobe -v quiet -hide_banner -show_streams -select_streams v:0 -of json $input";
    my $json = `$cmd`;
    my $out = decode_json($json);
    return ($out);
}

sub getAudioInfo
{
    my $input=shift;
    my $cmd = "$ffprobe -v quiet -hide_banner -show_streams -select_streams a:0 -of json $input";
    my $json = `$cmd`;
    my $out = decode_json($json);
    return ($out);
}