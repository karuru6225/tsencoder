#!/bin/bash

MAP=`ffmpeg -i "$1" 2>&1 | sed 's/^[ ]*//g' | awk '
	function printLists(){
		if(target == 1 && svlistIdx != 1 && salistIdx != 1){
			#print "----------";
			maps=""
			for(i = 1; i in svlist; i++){
				tmp = svlist[i]
				maps = maps " -map " tmp;
			}
			for(i = 1; i in salist; i++){
				tmp = salist[i]
				maps = maps " -map " tmp;
			}
			print maps
			#for(i = 1; i in streams; i++){
			#	print streams[i];
			#}
			#print "----------";
		}
	}

	function debug(mes){
		#print "debug:::"mes > "/dev/stderr"
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
		target=0
		svlistIdx=1
		salistIdx=1
		streamsIdx=1
		split("", svlist);
		split("", salist);
		split("", streams);
	}

	/.*Program/{
		printLists();
		target=0
		svlistIdx=1
		salistIdx=1
		split("", svlist);
		split("", salist);
		debug($0);
	}
	
	/Stream #([0-9]+):([0-9]+).*(Video.*1440x1080)/{
		debug($0);
		target=1;
		s = $1" "$2;
		all = $0
		if(findStream(s)){
			streams[streamsIdx++] = s
			#svlist[svlistIdx++] = all
			if(match(all, /([0-9]+:[0-9]+)/)){
				svlist[svlistIdx++] = substr(all, RSTART, RLENGTH);
			}
		}
	}
	
	/Stream #([0-9]+):([0-9]+).*(Audio.*)stereo.*/{
		debug($0);
		s = $1" "$2;
		all = $0
		if(findStream(s)){
			streams[streamsIdx++] = s
			#salist[salistIdx++] = all
			if(match(all, /([0-9]+:[0-9]+)/)){
				salist[salistIdx++] = substr(all, RSTART, RLENGTH);
			}
		}
	}
	
	END{
		printLists();
	}'`

THREADS=3
if [  "" != "${MAP}" ]; then
	nice -n 19 ffmpeg -y -fflags discardcorrupt -i "$1" -f mp4 -vcodec libx264 -vpre libx264-hq-ts -r 30000/1001 -aspect 16:9 -s 1440x1080 -bufsize 20000k -maxrate 25000k -vsync 1 -movflags faststart -vf "w3fdif=complex:interlaced" -acodec libvo_aacenc -aq 100 -bsf aac_adtstoasc -threads ${THREADS} ${MAP} "$1".mp4.tmp
	RESULT=$?
	if [ ${RESULT} = 0 ]; then
		echo
		echo "done"
		echo
		mv "$1".mp4.tmp "$1".mp4
		if [ "" != "$2" ]; then
			mv "$1" "$2"
		fi
	fi
fi
