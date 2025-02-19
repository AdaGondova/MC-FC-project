#!/bin/bash


### the script will first register the parcellation to the functional space and then runs the python script to extract matrices
### requires fsl and conda networks environment 

## Loop over subjects! (assumes subj and session IDs are in comma sep csv!) 

while read -r line
do
	subject=$(echo "${line}" | cut -d ',' -f1)
	session=$(echo "${line}" | cut -d ',' -f2)

	echo Working on ${subject} ${session}
	#=== REGISTER STUFF ===#
	mkdir -p tmp
	oDIR=../../DerivedData/subjects/sub-${subject}/ses-${session}

	# convert xfm
	convert_xfm -inverse rel3_dhcp_fmri_pipeline/sub-${subject}/ses-${session}/xfm/sub-${subject}_ses-${session}_from-bold_to-T2w_mode-image.mat -omat tmp/T2_to_bold.mat 
	# register 
	flirt -in ${oDIR}/sub-${subject}_ses-${session}.combined.DKT-DRAWEM.volume.anat.nii.gz -ref rel3_dhcp_fmri_pipeline/sub-${subject}/ses-${session}/func/sub-${subject}_ses-${session}_task-rest_desc-preproc_bold.nii.gz -out tmp/ROIs_func.nii.gz -init tmp/T2_to_bold.mat -applyxfm -interp nearestneighbour

	if [ ! -f "tmp/ROIs_func.nii.gz" ]
	then 
		echo ${subject} ${session} registration did not work
		echo ${subject},${session} >> registration_failed.csv
	else 
		echo ${subject} ${session} registered OK		
	fi


	#=== EXTRACT STUFF ===#
	# will use nilearn to relabel parcellations to match the structural matrices indexing 
	# will create the regional mask within which the data is post-processed 
	# will low-pass (.1Hz) and smooth the data (3.225 mm)
	# will save the matrices for subject in a pickle file
	python3 2_processing_and_extraction.py ${subject} ${session}

	rm -r tmp
done < "$1"
echo Finished at: `date`


