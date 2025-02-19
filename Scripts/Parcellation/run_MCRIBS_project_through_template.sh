#!/bin/bash

# to use wb_command need to set up path to the local version
. /volatile/dhcp-structural-pipeline/parameters/path.sh 


echo Stared at: `date`

## Loop over subjects! (assumes subj and session IDs are in comma sep csv!) 
while read -r line
do

	subject=$(echo "${line}" | cut -d ',' -f1)
	session2=$(echo "${line}" | cut -d ',' -f2)
	session1=$(echo "${line}" | cut -d ',' -f3)


	INPUTDIR=/neurospin/grip/external_databases/dHCP_CR_JD_2018/release3/dhcp_anat_pipeline/sub-${subject}
	OUTPUTDIR=/neurospin/grip/external_databases/dHCP_CR_JD_2018/Projects/networks/DerivedData/subjects/sub-${subject}/ses-${session1}

	#if [ ! -d "${OUTPUTDIR}" ]; then mkdir -p "${OUTPUTDIR}"; fi

	echo "$subject" "$session"

	for hemi in left right ; do
		
		if [ "${hemi}" == left ]
		then 
			h=l
		else
			h=r
		fi

		echo Working on "$hemi"

		### native surfaces and transform files
		iNatSurf_session2=${INPUTDIR}/ses-${session2}/anat/sub-${subject}_ses-${session2}_hemi-${hemi}_wm.surf.gii
		iNatSphere_session2=${INPUTDIR}/ses-${session2}/anat/sub-${subject}_ses-${session2}_hemi-${hemi}_sphere.surf.gii
		iNatTransSphere_session2=${INPUTDIR}/ses-${session2}/xfm/sub-${subject}_ses-${session2}_hemi-${hemi}_from-native_to-dhcpSym40_dens-32k_mode-sphere.surf.gii
		
		iNatSurf_session1=${INPUTDIR}/ses-${session1}/anat/sub-${subject}_ses-${session1}_hemi-${hemi}_wm.surf.gii
		iNatSphere_session1=${INPUTDIR}/ses-${session1}/anat/sub-${subject}_ses-${session1}_hemi-${hemi}_sphere.surf.gii
		iNatTransSphere_session1=${INPUTDIR}/ses-${session1}/xfm/sub-${subject}_ses-${session1}_hemi-${hemi}_from-native_to-dhcpSym40_dens-32k_mode-sphere.surf.gii

		### templates
		iTemplateSurf=/neurospin/grip/external_databases/dHCP_CR_JD_2018/Projects/andrea/SourceData/dhcpSym_template/week-40_hemi-${hemi}_space-dhcpSym_dens-32k_wm.surf.gii
		iTemplateSphere=/neurospin/grip/external_databases/dHCP_CR_JD_2018/Projects/andrea/SourceData/dhcpSym_template/week-40_hemi-${hemi}_space-dhcpSym_dens-32k_sphere.surf.gii

		### additional anat files 
		iNatMidthickness_session2=${INPUTDIR}/ses-${session2}/anat/sub-${subject}_ses-${session2}_hemi-${hemi}_midthickness.surf.gii
		iNatMidthickness_session1=${INPUTDIR}/ses-${session1}/anat/sub-${subject}_ses-${session1}_hemi-${hemi}_midthickness.surf.gii
		iTemplateMidthickness=/neurospin/grip/external_databases/dHCP_CR_JD_2018/Projects/andrea/SourceData/dhcpSym_template/week-40_hemi-${hemi}_space-dhcpSym_dens-32k_midthickness.surf.gii

		##### parcellations 		
		Parc_session2=/neurospin/grip/external_databases/dHCP_CR_JD_2018/Projects/networks/DerivedData/subjects/sub-${subject}/ses-${session2}/sub-${subject}_ses-${session2}_${h}h.DKT.label.gii
		Parc_template=${OUTPUTDIR}/sub-${subject}_ses-${session2}_${h}h_DKT_template.tex.gii
		Parc_session1=${OUTPUTDIR}/sub-${subject}_ses-${session2}_${h}h.DKT.ses1_template_transform.label.gii

		for iFile in $iNatSurf_session2 $iNatSphere_session2 $iNatTransSphere_session2 $iNatSurf_session1 $iNatSphere_session1 $iNatTransSphere_session $iNatTransSphere $iTemplateSurf $iTemplateSphere $iNatMidthickness_session1 $iNatMidthickness_session2 $iTemplateMidthickness $iNatMidthickness_session2 $iNatMidthickness_session1 $Parc_session2
		
			do 
			if [ ! -e $iFile ]; then 
				echo ${iFile} not found
				check=false
			fi
			done
		
		# need to concatenate msm warps from 'ses2 to template' and 'template to ses1' (inspired by https://github.com/ecr05/dHCP_template_alignment/blob/master/surface_to_template_alignment/align_to_template_3rd_release.sh) 
		# sphere-in = sphere with desired output mesh, sphere-project-to = tat aligns with the sphere in, 
		# sphere-unproject-from - sphere project from - seformed to the desired output space 
		# sphere out - output

		wb_command -surface-sphere-project-unproject ${iTemplateSphere} ${iNatTransSphere_session2} ${iNatTransSphere_session1} ${OUTPUTDIR}/${hemi}_combined_warps.sphere.Ses2toSes1.surf.gii
		
		### project session 2 to template
		wb_command -label-resample "$Parc_session2" "$iNatTransSphere_session2" "${OUTPUTDIR}/${hemi}_combined_warps.sphere.Ses2toSes1.surf.gii" ADAP_BARY_AREA "$Parc_session1" -area-surfs "$iNatMidthickness_session2" "$iNatMidthickness_session1"

	
		
		#cp "$Parc_session2" ${OUTPUTDIR}/${hemi}_DKT_parc_session2.tex.gii


		if [ -e $Parc_session1 ]; then 
			echo $subject $session $hemi projections written. 
		fi 

		done

done < "$1"

echo Finished at: `date`


