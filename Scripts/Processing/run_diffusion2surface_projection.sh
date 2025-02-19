#!/bin/bash

# requires fsl_init

#===== Projecting the diffusion metrics to the surface =======# 
# should incorporate the NODDI correction within the loop so the files are only tmp to save space 
# in the loop register the diffusion maps to anat 
# project to the surface & save in DerivedData dir 

echo Stared at: `date`

## subject info / line 
while read -r line
do
	subject=$(echo "${line}" | cut -d ',' -f1)
	session=$(echo "${line}" | cut -d ',' -f2)
	echo WORKING ON SUBJECT: "$subject", session "$session"



	### =================== REGISTER shard 2 anat ====== ###
	iREF=/neurospin/grip/external_databases/dHCP_CR_JD_2018/release3/dhcp_anat_pipeline/sub-${subject}/ses-${session}/anat/sub-${subject}_ses-${session}_desc-restore_T2w.nii.gz
	iWARP=/neurospin/grip/external_databases/dHCP_CR_JD_2018/release3/dhcp_dmri_shard_pipeline/sub-${subject}/ses-${session}/xfm/sub-${subject}_ses-${session}_from-dwi_to-T2w_mode-image.mat

	## will be created and crushed in the loop to save space
	mkdir -p tmp
	

	### REGISTER DTI metrics 
	for metric in L1 RD MD FA #and others you need
	do 
		iMETRIC=/neurospin/grip/external_databases/dHCP_CR_JD_2018/release3/dhcp_dmri_shard_pipeline/sub-${subject}/ses-${session}/dwi/DTI/dtifit_b1000/sub-${subject}_ses-${session}_${metric}.nii.gz
		oMETRIC=tmp/registered_${metric}.nii.gz

		#registration 
		echo Registering ${metric}
		flirt -in ${iMETRIC} -ref ${iREF} -out ${oMETRIC} -init ${iWARP} -applyxfm -interp trilinear
		if [ -f "$oMETRIC" ]
		then 
			echo ${metric} REGISTERED
		fi	
	done

	### REGISTER NODDI metrics 
	for metric in cOD cNDI
	do 
		iMETRIC=/neurospin/grip/external_databases/dHCP_CR_JD_2018/release3/dhcp_dmri_shard_pipeline/sub-${subject}/ses-${session}/dwi/NODDI/${metric}.nii.gz
		oMETRIC=tmp/registered_${metric}.nii.gz

		#registration 
		echo Registering ${metric}
		flirt -in ${iMETRIC} -ref ${iREF} -out ${oMETRIC} -init ${iWARP} -applyxfm -interp trilinear
		if [ -f "$oMETRIC" ]
		then 
			echo ${metric} REGISTERED
		fi	
	done 	
	
	### =============================== EXTRACTION ========== ###
	OUTDIR=/neurospin/grip/external_databases/dHCP_CR_JD_2018/Projects/networks/DerivedData/subjects/sub-${subject}/ses-${session}
	metricsDIR=${OUTDIR}/surf_metrics
	mkdir -p ${metricsDIR}

	for hemi in left right 
	do 
		if [ "${hemi}" == left ]
		then 
			in_hemi=L
		else
			in_hemi=R
		fi 

		for metric in L1 RD MD FA cOD cNDI
		do 
			#echo $hemi $metric ...
			iMESH=/neurospin/grip/external_databases/dHCP_CR_JD_2018/release3/dhcp_anat_pipeline/sub-${subject}/ses-${session}/anat/sub-${subject}_ses-${session}_T2w_${in_hemi}white_bv_transformed.gii
			oTEXTURE=${metricsDIR}/sub-${subject}_ses-${session}_${hemi}_${metric}.gii

			#takes min using L1
			#/i2bm/brainvisa/brainvisa-master/bin/bv AimsVol2Tex -a tmp/registered_${metric}.nii.gz -m ${iMESH} -o ${oTEXTURE} -i tmp/registered_L1.nii.gz -height 1.5 -radius 1.5 -v 3
			# now available by default			
			AimsVol2Tex -a tmp/registered_${metric}.nii.gz -m ${iMESH} -o ${oTEXTURE} -i tmp/registered_L1.nii.gz -height 1.5 -radius 1.5 -v 3
			
			if [ -f "$oTEXTURE" ]
			then 
				echo $oTEXTURE created
				echo $subject,$session,$hemi >> projected_subjects.csv
			fi 
		done 
	done 
	echo "$subject" "$session" DONE
	rm -r tmp
done < "$1"
echo Finished at: `date`


