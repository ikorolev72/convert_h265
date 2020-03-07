#					Recurcively convert movies in specified directory to H.265


##  What is it?
##  -----------
Comman line script.
Convert movie and TV shows to H.265 and then delete the original. 
The script also does this when new content is added to the media library.
Process can be start with lower priority.
The server is running Debian 10 .	

##  How to install 
##  -------------
You need install ffmpeg and this script.
I recommeded use last version ffmpeg ( at this momemnt 4.2.2). Debian version available here https://tracker.debian.org/pkg/ffmpeg or static binaries https://johnvansickle.com/ffmpeg/

```
git clone https://github.com/ikorolev72/convert_h265.git
cd 
```


##	Usage:
##
```bash
This script converting video files to H.265 codec 
Usage: convert_h265.pl --in=/path/input [--backup] [--cpu 1] [--ffmpeg=/path/to/ffmpeg][--ffprobe=/path/to/ffprobe]  [--help]
Where:
 --in=/path/input - search videos from this folder 
 --cpu 1 - define how many CPUs use for transcoding. Possible values: 0 - mean use all CPUs, from 1 to all CPU cores ( can be checked with 'nproc' linux command ), default: 1.
 --backup - do not remove original video file. File will be ranamed to 'original_video_filename' with digits extension like 'original_video_filename.1234455.22222'
 --ffmpeg=/path/to/ffmpeg - path to ffmpeg binariy ( by default using 'ffmpeg', must be found in environment PATH )
 --ffprobe=/path/to/ffprobe - path to ffprobe binariy ( by default using 'ffprobe', must be found in environment PATH )
 --help - this help
Sample:	convert_h265.pl --in=/mediaserver/media/tv --cpu 1 --ffmpeg=/opt/ffmpeg/bin/ffmpeg --ffprobe=/opt/ffmpeg/bin/ffprobe 
```



##  Bugs
##  ------------



  Licensing
  ---------
	GNU

  Contacts
  --------

     o korolev-ia [at] yandex.ru
     o http://www.unixpin.com

