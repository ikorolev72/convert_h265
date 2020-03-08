#!/usr/bin/perl
# korolev-ia [at] yandex.ru

use Getopt::Long;
use Cwd;
use File::Basename;
use File::Find;
use Data::Dumper;
use lib ".";
use JSON;

my $version = "1.1 20200308";
my $video_extensions =
"avi|mkv|mov|mp4|flv|m2ts|mts|wmv|asf|amv|m4p|mpg|mp2|mpeg|mpe|mpv|m2v|m4v|svi|3gp";

my $basedir = dirname($0);
chdir($basedir);
my $curdir = getcwd();
mkdir("log");
mkdir("tmp");
mkdir("data");

my $logFile     = "log/convert_h265.log";
my $encodedFile = "data/encoded.txt";
my $failedFile  = "data/failed.txt";

my @videoFiles = ();

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
    'cpu=n'     => \$cpu,
    "help|h|?"  => \$help
);

$in      = ($in)      ? $in       : $defIn;
$cpu     = ($cpu)     ? int($cpu) : $defCpu;
$backup  = ($backup)  ? 1         : 0;
$ffmpeg  = ($ffmpeg)  ? $ffmpeg   : $defFfmpeg;
$ffprobe = ($ffprobe) ? $ffprobe  : $defFfprobe;

if ($help) {
    show_help();
}

if ( system("$ffmpeg -version -hide_banner") ) {
    show_help(
        'Please, set the path to ffmpeg in enviroment or use option --ffmpeg ');
    exit(1);
}
if ( system("$ffprobe -version -hide_banner") ) {
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
w2log("INFO: Will use ffprobe binary: '$ffprobe'");

# read encoded and failed files and ignore those files in processing
my $encoded = {};
my $failed  = {};
%{$encoded} = ReadFileInHash($encodedFile);
%{$failed}  = ReadFileInHash($failedFile);

# looking for all video files
find( \&wanted, $in );

foreach my $file (@videoFiles) {

    eval {
        if ( $encoded->{$file} ) {
            next;
        }
        if ( $failed->{$file} ) {
            next;
        }

        w2log("INFO: Check info for video file '$file'");
        my $videoInfo     = getVideoInfo($file);
        my $audioInfo     = getAudioInfo($file);
        my $subtitlesInfo = getSubtitlesInfo($file);

        my $tmpFileName = time() . rand(10000);
        my $encodingLog = "$curdir/log/$tmpFileName.log";
        my ($ext)       = $file =~ /(\.[^.]+)$/;
        my $outFile     = "$curdir/tmp/${tmpFileName}$ext";

        if ( $videoInfo->{'streams'}[0]->{'codec_name'} =~ /^hevc$/ ) {
            w2log("INFO: File '$file' already encoded in H.265");
            AppendFile( $encodedFile, "$file\n" );
            next;
        }

        w2log("INFO: Start encoding video file '$file'");
        if (
            runEncoding(
                $file,      $outFile,   $encodingLog,
                $videoInfo, $audioInfo, $subtitlesInfo
            )
          )
        {
            w2log("Info: file '$file' encoded to H.265");
            AppendFile( $encodedFile, "$file\n" );
            if ($backup) {
                if ( !rename( $file, "$file.$tmpFileName" ) ) {
                    w2log(
"Warning: Cannot make backup copy of original file '$file' to '$file.$tmpFileName'"
                    );
                }
                else {
                    w2log(
"Info: Backup copy of original file '$file' is '$file.$tmpFileName'"
                    );
                }

            }
            if ( !rename( $outFile, $file ) ) {
                w2log(
                    "ERROR: Cannot rename trancoded file '$outFile' to '$file'"
                );
            }

            #unlink( $encodingLog); # remove log for successfuly encoded files
        }
        else {
            w2log(
"Warning: file '$file' encoding  to H.265 failed. Please check log '$encodingLog'"
            );
            unlink($outFile);
            AppendFile( $failedFile, "$file\n" );
        }
    };
    if ($@) {
        w2log( "Error: Something went wrong:" . $@ );
    }

}

w2log("INFO: All done. Script finished");
exit(0);

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
    if (/\.($video_extensions)$/i) {
        push( @videoFiles, $File::Find::name );
    }
}

sub w2log {
    my $msg = shift;
    open( my $LOG, '>>', $logFile ) || print("Can't open file $logFile. $msg");
    print $LOG get_date() . "\t$msg\n";
    print STDERR get_date() . "\t$msg\n";
    close($LOG);
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
    my $filename = shift;
    my $ret      = "";
    open( IN, "<", $filename ) || w2log("Can't open file $filename");
    while (<IN>) { $ret .= $_; }
    close(IN);
    return $ret;
}

sub WriteFile {
    my $filename = shift;
    my $body     = shift;
    unless ( open( OUT, ">", $filename ) ) {
        w2log("Can't open file $filename for write");
        return 0;
    }
    print OUT $body;
    close(OUT);
    return 1;
}

sub AppendFile {
    my $filename = shift;
    my $body     = shift;
    unless ( open( OUT, ">>", $filename ) ) {
        w2log("Can't open file $filename for append");
        return 0;
    }
    print OUT $body;
    close(OUT);
    return 1;
}

sub getVideoInfo {
    my $input = shift;
    my $cmd =
"$ffprobe -v quiet -hide_banner -show_streams -select_streams v:0 -of json \"$input\" 2>/dev/null";
    my $json = `$cmd`;
    my $out  = decode_json($json);
    return ($out);
}

sub getAudioInfo {
    my $input = shift;
    my $cmd =
"$ffprobe -v quiet -hide_banner -show_streams -select_streams a -of json \"$input\" 2>/dev/null";
    my $json = `$cmd`;
    my $out  = decode_json($json);
    return ($out);
}

sub getSubtitlesInfo {
    my $input = shift;
    my $cmd =
"$ffprobe -v quiet -hide_banner -show_streams -select_streams s -of json \"$input\" 2>/dev/null";
    my $json = `$cmd`;
    my $out  = decode_json($json);
    return ($out);
}

sub ReadFileInArray {
    my $path_to_file = shift;
    my @lines;
    if ( -e $path_to_file ) {
        open my $handle, '<',
          $path_to_file || w2log("Can't open file $path_to_file ");
        chomp( @lines = <$handle> );
        close $handle;
    }
    return (@lines);
}

sub ReadFileInHash {
    my $path_to_file = shift;
    my %hash;
    my @lines = ReadFileInArray($path_to_file);
    foreach (@lines) {
        $hash{$_} = 1;

    }
    return (%hash);
}

sub runEncoding {
    my ( $file, $outFile, $encodingLog, $videoInfo, $audioInfo, $subtitlesInfo )
      = @_;

    my $audioCodec     = "";
    my $videoCodec     = "";
    my $subtitlesCodec = "";

    my $i = 0;
    foreach ( @{ $audioInfo->{'streams'} } ) {

        #print Dumper( $_);
        if ( defined $_->{'index'} ) {
            $audioCodec .= " -map 0:a:$i -c:a copy ";
        }
        $i++;

    }

    $i = 0;
    foreach ( @{ $videoInfo->{'streams'} } ) {

        #print Dumper( $_);
        if ( defined $_->{'index'} ) {
            $videoCodec .= " -map 0:v:$i -c:v libx265 -crf 25 -preset medium ";
        }
        $i++;
    }

    $i = 0;
    foreach ( @{ $subtitlesInfo->{'streams'} } ) {

        #print Dumper( $_);
        if ( defined $_->{'index'} ) {
            $subtitlesCodec .= " -map 0:s:$i -c:s copy ";
        }
        $i++;
    }

    my $cmd =
"$ffmpeg -y -loglevel warning -i \"$file\"  $videoCodec $audioCodec $subtitlesCodec -x265-params pools=$cpu $outFile  >  $encodingLog 2>&1  ";
    w2log("Info: Start encoding command $cmd");

    if ( system($cmd ) ) {
        return (0);
    }
    return 1;
}
