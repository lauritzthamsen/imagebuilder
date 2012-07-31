#!/bin/bash

function run {
   image_arg="$1"
   args=$@

   BIN=`/usr/bin/dirname "$0"`/lib/squeak/$version
   if [[ -e "$image_arg" ]]; then
      if [[ -n $(echo "$image_arg" | grep "\.image$") ]]; then
         IMAGE="$image_arg" # If the file exists and ends with image, use it
      fi
   fi
   if [[ -e "${image_arg}.image" ]]; then
      IMAGE="${image_arg}.image" # Use prefixed image if it exists, use it
   fi

   if [[ -n $IMAGE ]]; then
      eval "${VM_PATH}" "$args"
   else
      eval "${VM_PATH}" "$(pwd)/$(ls Squeak*image | head -1)" "$args"
   fi
}

function download {
    # from https://github.com/timfel/dotfiles
    if [[ -z $(ls | grep "Squeak[^\.]*\.sources") ]]; then
	declare -a IMAGES
	declare -a IMAGE_FOLDERS
	image_idx=1
	for i in $(curl -s $SQUEAK_SERVER | grep DIR | grep -o "href=\".*\"" | grep "$SQUEAK_WILDCARD"); do
	    i=${i#*=}
	    i=${i#\"}
	    i=${i%%\"}
	    for j in $(curl -s $SQUEAK_SERVER/$i/ | grep -o "href=\"Squeak.*zip\""); do
		j=${j#*=}
		j=${j#\"}
		j=${j%%\"}
		IMAGE_FOLDERS[image_idx]=$i
		IMAGES[image_idx]=$j
		image_idx=$[image_idx + 1]
	    done
	done

	for i in `seq 1 $[image_idx - 1]`; do echo "[$i] ${IMAGES[i]}"; done
	printf "Choose Image Index: "
	read image_idx

	source_idx=1
	declare -a SOURCES
	for j in $(curl -s $SQUEAK_SERVER/$SOURCE_FOLDER/ | grep -o "href=\".*gz\""); do
	    j=${j#*=}
	    j=${j#\"}
	    j=${j%%\"}
	    SOURCES[source_idx]=$j
	    source_idx=$[source_idx + 1]
	done

	for i in `seq 1 $[source_idx - 1]`; do echo "[$i] ${SOURCES[i]}"; done
	printf "Choose Sources Index: "
	read source_idx
    
	curl -O "$SQUEAK_SERVER/${IMAGE_FOLDERS[image_idx]}${IMAGES[image_idx]}"
	unzip ${IMAGES[image_idx]}
    
    # Pull Squeak out of subdirectory
    SQUEAK_VERSION=${IMAGES[image_idx]%.zip}
    if [[ -e "${SQUEAK_VERSION}" ]]; then
      cp ${SQUEAK_VERSION}/* .
      rm -r "${SQUEAK_VERSION}"
    fi    
	rm ${IMAGES[image_idx]}
    
	curl -O "$SQUEAK_SERVER/$SOURCE_FOLDER/${SOURCES[source_idx]}"
	gunzip ${SOURCES[source_idx]}
    fi
}

function setup {
   echo "Setting up image.."
   setup_file="__squeak_setup.st"
   cat <<EOF> $setup_file
    Utilities setAuthorInitials: 'Setup'.
   
    Installer squeaksource
    	project: 'MetacelloRepository';
    	install: 'ConfigurationOfMetacello'. 
	
	(Smalltalk at: #ConfigurationOfMetacello) load.
    
    MCMcmUpdater updateFromDefaultRepository.

	(Installer repository: '${REPOSITORY}')	
		install: '${CONFIG}'.
    (Smalltalk at: #${CONFIG}) install.

    SmalltalkImage current snapshot: true andQuit: true embedded: true.
EOF
   run $1 $setup_file
}

function usage {
	E_OPTERROR=65
	echo "Usage: `basename $0` -v <BUILD_VM_PATH> -c <METACELLO_CONFIGURATION> -r <MONTICELLO_REPOSITORY> -i <IMAGE_DIRECTORY>"
	exit $E_OPTERROR	
}

if [ $# -le 5 ] # print usage if there are not enough arguments
then
	usage
fi

while getopts ":v:c:r:i:d:" OPTION
do
	case $OPTION in
		v) VM_PATH="$OPTARG" ;;
		c) CONFIG="$OPTARG" ;;
		r) REPOSITORY="$OPTARG" ;;
        i) SQUEAK="$OPTARG" ;;
        d) DIRECTORY="$OPTARG" ;;
		*) usage ;;
	esac
done

PREVIOUS_DIR=$(pwd)
TEMP=$(mktemp -d -t squeak_installer_XXXXXX)

SQUEAK_SERVER="http://ftp.squeak.org"
SOURCE_FOLDER="sources_files"
SQUEAK_WILDCARD="4."

cd $TEMP
download
setup

DATE_STRING=`date +%Y%m%d_%H%M%S`

mkdir "squeak_${DATE_STRING}"
cd "squeak_${DATE_STRING}"

eval "mv $(ls ../*.image | head -1)" "Squeak.image"
eval "mv $(ls ../*.changes | head -1)" "Squeak.changes"
mv ../SqueakV41.sources ./

mv "${TEMP}/squeak_${DATE_STRING}" $DIRECTORY/
echo "Build available at ${DIRECTORY}/squeak_${DATE_STRING}/"
 
cd $PREVIOUS_DIR
cd ..
