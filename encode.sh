#set -ex
IFILE="x"
ODIR="x"
ONAME="x"
FAIL_DIR="x"
ENCODED_DIR="x"
MAP="x"
SIZE="-s 1280x720"
NORM="n"
TYPE="x"
THREADS=2
usage(){
  echo "Usage: $0 [-h]"
  echo "Usage: $0 -i INPUT-FILE -o OUTPUT-DIR -t TYPE"
  echo "          [-f ERROR-DIR] [-e PROCESSED-DIR] [-d OUTPUT-NAME]"
  echo "          [-m MAP-OPTION] [-s SIZE]  [-n]"
  echo "  -h"
  echo "    echo help"
  echo "  -i INPUT-FILE"
  echo "    input file"
  echo "  -o OUTPUT-DIR"
  echo "    output directory"
  echo "  -d OUTPUT-NAME"
  echo "    output file name"
  echo "  -t TYPE"
  echo "    encode type. Specify one of ts, hls, hlslow, general"
  echo "  -f ERROR-DIR"
  echo "    move input file to this directory if encode is failed"
  echo "  -e PROCESSED-DIR"
  echo "    move input file to this directory if encode is successed"
  echo "  -m MAP-OPTION"
  echo "    specify map options same as ffmpeg map option. if scecify 'copy', encode file without map option."
  echo "  -s SIZE"
  echo "    specify size options same as ffmpeg size option. if scecify 'copy', encode file without size option."
  echo "    but, if specified TYPE is 'hlslow', SIZE is forced to 800x450"
  echo "  -n"
  echo "    normalize audio volume"
  exit 0
}

while getopts hi:o:d:f:m:s:t:e:n OPT
do
  case $OPT in
    h)
      usage
      ;;
    i)
      IFILE="$OPTARG"
      ;;
    o)
      ODIR="$OPTARG"
      ;;
    d)
      ONAME="$OPTARG"
      ;;
    f)
      FAIL_DIR="$OPTARG"
      ;;
    m)
      MAP="$OPTARG"
      ;;
    s)
      SIZE="-s "$OPTARG
      if [ "$OPTARG" = "copy" ]; then
        SIZE=""
      fi
      ;;
    t)
      TYPE="$OPTARG"
      if [ "$TYPE" = "hls" ];then
        # exit 0
      fi
      ;;
    e)
      ENCODED_DIR="$OPTARG"
      ;;
    n)
      NORM="y"
      ;;
  esac
done

if [ "$IFILE" = "x" -o "$ODIR" = "x" -o "$TYPE" = "x" ]; then
  echo missing args
  exit 1
fi

FFMPEG_BIN="./ffmpeg-git-20170721-64bit-static/ffmpeg"
BASE=`basename "$IFILE"`
DIR=`dirname "$ODIR"`/`basename "$ODIR"`

echo $IFILE
echo $ODIR

AFSTR=""
if [ $NORM = "y" ]; then
  TARGET_IL="-24.0"
  TARGET_LRA="+11.0"
  TARGET_TP="-2.0"
  JSON=`${FFMPEG_BIN} -hide_banner -i "$IFILE" -af loudnorm=I=${TARGET_IL}:LRA=${TARGET_LRA}:tp=${TARGET_TP}:print_format=json -f null - 2>&1 | tail -n 12`
  M_I=`echo ${JSON} | jq -r '.input_i'`
  M_LRA=`echo ${JSON} | jq -r '.input_lra'`
  M_TP=`echo ${JSON} | jq -r '.input_tp'`
  M_THRESH=`echo ${JSON} | jq -r '.input_thresh'`
  OFFSET=`echo ${JSON} | jq -r '.target_offset'`
  AFSTR="-af loudnorm=print_format=summary:linear=true:I=${TARGET_IL}:LRA=${TARGET_LRA}:TP=${TARGET_TP}:measured_I=${M_I}:measured_LRA=${M_LRA}:measured_tp=${M_TP}:measured_thresh=${M_THRESH}:offset=${OFFSET}"
fi

if [ "$MAP" = "x" ]; then
MAP=`${FFMPEG_BIN} -i "$IFILE" 2>&1 | sed 's/^[ ]*//g' | gawk '
	function debug(mes){
		print "debug:::"mes > "/dev/stderr"
	}

	function findStream(s){
		for(i = 1; i in streams; i++){
			if(streams[i] == s){
				return 0;
			}
		}
		return 1;
	}

	BEGIN{
		streamsIdx=1
		split("", streams);
	}
	
	/Stream #[0-9]+:[0-9]+.*Video.*/{
		all = $0
		if(findStream(all)){
			if(match(all, /([0-9]+):([0-9]+).* ([0-9]{3,4})x([0-9]{3,4})/, matches)){
				f = substr(all, matches[1, "start"], matches[1, "length"])
				c = substr(all, matches[2, "start"], matches[2, "length"])
				w = substr(all, matches[3, "start"], matches[3, "length"])
				h = substr(all, matches[4, "start"], matches[4, "length"])
				if(int(w) > 1000){
					streams[streamsIdx++] = all
					print " -map "f":"c;
				}
			}
		}
	}
	
	/Stream #[0-9]+:[0-9]+.*Audio: aac.*stereo.*/{
		all = $0
		if(findStream(all)){
			if(match(all, /([0-9]+):([0-9]+).* ([0-9]+) kb\/s/, matches)){
				f = substr(all, matches[1, "start"], matches[1, "length"])
				c = substr(all, matches[2, "start"], matches[2, "length"])
				b = substr(all, matches[3, "start"], matches[3, "length"])
				if(int(b) > 100){
					streams[streamsIdx++] = all
					print " -map "f":"c;
				}
			}
		}
	}
	
	/Stream #[0-9]+:[0-9]+.*Audio: aac.*mono.*/{
		all = $0
		if(findStream(all)){
			if(match(all, /([0-9]+):([0-9]+).* ([0-9]+) kb\/s/, matches)){
				f = substr(all, matches[1, "start"], matches[1, "length"])
				c = substr(all, matches[2, "start"], matches[2, "length"])
				b = substr(all, matches[3, "start"], matches[3, "length"])
				if(int(b) > 60){
					streams[streamsIdx++] = all
					print " -map "f":"c;
				}
			}
		}
	}
	
	/Stream #[0-9]+:[0-9]+.*Audio: aac.*5\.1.*/{
		all = $0
		if(findStream(all)){
			if(match(all, /([0-9]+):([0-9]+).*/, matches)){
				f = substr(all, matches[1, "start"], matches[1, "length"])
				c = substr(all, matches[2, "start"], matches[2, "length"])
				b = substr(all, matches[3, "start"], matches[3, "length"])
				if(int(b) > 100){
					streams[streamsIdx++] = all
					print " -map "f":"c;
				}
			}
		}
	}
	
	/Stream #[0-9]+:[0-9]+.*Audio: dts.*/{
		all = $0
		if(findStream(all)){
			if(match(all, /([0-9]+):([0-9]+).*/, matches)){
				f = substr(all, matches[1, "start"], matches[1, "length"])
				c = substr(all, matches[2, "start"], matches[2, "length"])
				streams[streamsIdx++] = all
				print " -map "f":"c;
			}
		}
	}

	# /Stream #[0-9]+:[0-9]+.*Subtitle.*/{
	# 	all = $0
	# 	if(findStream(all)){
	# 		if(match(all, /([0-9]+):([0-9]+).*/, matches)){
	# 			f = substr(all, matches[1, "start"], matches[1, "length"])
	# 			c = substr(all, matches[2, "start"], matches[2, "length"])
	# 			streams[streamsIdx++] = all
	# 			print " -map "f":"c;
	# 		}
	# 	}
	# }
	'`
fi

hls(){
  mkdir -p "${DIR}"/tsfiles/
  mkdir -p "${DIR}"/m3ufiles
  M3UNAME=${BASE}
  if [ "$1" = "low" ];then
    M3UNAME="${BASE}-low"
  fi
  if [ "$ONAME" != "x" ];then
    M3UNAME="${ONAME}"
  fi
  if [ -e ${DIR}/m3ufiles/${M3UNAME}.m3u8 ];then
    echo "${DIR}/m3ufiles/${M3UNAME}.m3u8 is already exist."
    exit 0;
  fi

  TSDIR=`mktemp -d --tmpdir="${DIR}"/tsfiles/ f-XXXXXXXXXX`
  if [ "$1" = "low" ];then
    VOPTS="-vcodec libx264 -fpre ./libx264-hq-hls.ffpreset -bufsize 600k -maxrate 600k -vsync 1 -r 20 -g 100"
    AOPTS="-acodec aac -b:a 96k"
    SIZE="-s 800x450"
  else
    VOPTS="-vcodec libx264 -fpre ./libx264-hq-hls.ffpreset -bufsize 1500k -maxrate 1500k -vsync 1 -r 30 -g 150"
    AOPTS="-acodec aac -b:a 128k"
  fi
  SOPTS="-scodec webvtt"
  ODIRNAME=$(basename "$ODIR")
  TSDIRNAME=$(basename "$TSDIR")
  BSFS=""
  HLSOPTS="-flags +loop-global_header -segment_format mpegts -segment_time 5 -segment_list_flags +cache+live -segment_list ${DIR}/m3ufiles/${TSDIRNAME}.m3u8 -segment_list_entry_prefix https://karuru.info/kmv/tsfiles/${ODIRNAME}/${TSDIRNAME}/"
  chmod a+rx "${TSDIR}"
  ${FFMPEG_BIN} -i "$IFILE" ${AFSTR} ${VOPTS} ${SIZE} -strict experimental ${AOPTS} $BSFS $SOPTS ${HLSOPTS} ${MAP} -threads ${THREADS} -f segment "${TSDIR}/ts%04d.ts"

  mv -v "${DIR}/m3ufiles/${TSDIRNAME}.m3u8" "${DIR}/m3ufiles/${M3UNAME}.m3u8"
  touch -m -d "`stat -c %y \"$IFILE\"`" "${DIR}"/m3ufiles/"${M3UNAME}".m3u8

  fsize=`wc -c "${DIR}"/m3ufiles/"${M3UNAME}".m3u8 | awk '{print $1}'`

  if [ ${fsize} -lt 1024 ]; then
    rm -f "${DIR}"/m3ufiles/"${M3UNAME}".m3u8
    rm -rf "${DIR}"/tsfiles/${TSDIR}
    echo ${JSON}
  fi
}

ts(){
  FMT="mp4"
  EXT="mp4"
  VOPTS="-vcodec libx264 -fpre ./libx264-hq-ts.ffpreset -r 30000/1001 -aspect 16:9 -s 1440x1080 -bufsize 20000k -maxrate 25000k -vsync 1 -movflags faststart -vf 'w3fdif=complex:interlaced'"
  AOPTS="-acodec aac -strict -2 -b:a 256k -ar 48000"
  SOPTS=""
  BSFS=""
  ${FFMPEG_BIN} -y -fflags discardcorrupt -i "$IFILE" $VOPS $AOPTS $BSFS $SOPTS ${MAP} -threads ${THREADS} -f $FMT "$IFILE".$EXT.tmp
  RESULT=$?
  echo
  mv -v "$IFILE".$EXT.tmp "$IFILE".$EXT
  touch -m -d "`stat -c %y \"$IFILE\"`" "$IFILE".$EXT
  IDIR=`dirname "$IFILE".$EXT`
  REAL_IDIR=`realpath ${IDIR}`
  if [ "${REAL_IDIR}" != "`realpath $ODIR`" ]; then
    mv -v "$IFILE".$EXT "$ODIR"
  fi
  if [ ${RESULT} = 0 ]; then
    if [ "$ENCODED_DIR" != "x" ]; then
      mv -v "$IFILE" "$ENCODED_DIR"
    fi
  else
    if [ "$FAIL_DIR" != "x" ]; then
      mv -v "$IFILE" "$FAIL_DIR"
    fi
  fi
}

general(){
  FMT="matroska"
  EXT="mkv"
  VOPTS="-vcodec libx264 -fpre ./libx264-hq-ts.ffpreset -bufsize 20000k -maxrate 25000k -vsync 1 -movflags faststart"
  AOPTS="-acodec aac -strict -2 -b:a 256k"
  SOPTS="-scodec copy -disposition:s:0 default"
  BSFS=""
  ${FFMPEG_BIN} -y -i "$IFILE" $VOPS ${SIZE} $AOPTS $BSFS $SOPTS ${MAP} -threads ${THREADS} -f $FMT "$IFILE".$EXT.tmp
  RESULT=$?
  echo
  mv -v "$IFILE".$EXT.tmp "$IFILE".$EXT
  if [ "$ONAME" != "x" ];then
    mv -v "$IFILE".$EXT "$ONAME".$EXT
    IFILE="${ONAME}"
  fi
  IDIR=`dirname "$IFILE".$EXT`
  REAL_IDIR=`realpath ${IDIR}`
  if [ "${REAL_IDIR}" != "`realpath $ODIR`" ]; then
    mv -v "$IFILE".$EXT "$ODIR"
  fi
}

if [  "" != "${MAP}" ]; then
  if [ "${MAP}" = "copy" ]; then
    MAP=""
  fi
  if [ $TYPE = "ts" ];then
    ts
  fi
  if [ $TYPE = "hls" ];then
    hls
  fi
  if [ $TYPE = "hlslow" ];then
    hls low
  fi
  if [ $TYPE = "general" ];then
    general
  fi
else
  echo failed mapping
  exit 1
fi

