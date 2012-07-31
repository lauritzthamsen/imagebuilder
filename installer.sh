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
   if [[ -z $(ls | grep "Squeak[^\.]*\.sources") ]]; then
      echo "Downloading current trunk image"
      SOURCES="ftp://ftp.squeak.org/sources_files/"
      SQUEAK_IMAGE_FILES=$(curl ${SQUEAK} | grep "Squeak.*zip" | grep -v "SqueakCore" | tail -1 | awk '{print $NF}')
      SQUEAK_SOURCES_FILE=$(curl ${SOURCES} | grep "sources.gz" | tail -1 | awk '{print $NF}')
      curl -O "${SOURCES}${SQUEAK_SOURCES_FILE}"
      curl -O "${SQUEAK}${SQUEAK_IMAGE_FILES}"
      unzip $SQUEAK_IMAGE_FILES
      UNZIPPED_DIRECTORY=${SQUEAK_IMAGE_FILES%.zip}
      echo $SQUEAK_IMAGE_FILES
      if [[ -e "${UNZIPPED_DIRECTORY}" ]]; then
        cp ${UNZIPPED_DIRECTORY}/* .
        rm "${UNZIPPED_DIRECTORY}"
      fi
      gunzip Squeak*sources.gz
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

	(Installer repository: '${REPOSITORY}')	
		install: '${CONFIG}'.
	(Smalltalk at: #${CONFIG}) install.

	MCMcmUpdater updateFromDefaultRepository.
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

cd $PREVIOUS_DIR

cd ..
