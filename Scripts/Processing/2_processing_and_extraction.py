import os, sys, pickle
import numpy as np
from nilearn.image import load_img
from nilearn.maskers import NiftiLabelsMasker
from nilearn.connectome import ConnectivityMeasure
import nibabel as nib
import pickle
import pandas as pd 

## requires networks conda environment

def relabel_ROIs(rois, lookup_table, return_mask=False):
	labels = np.unique(np.asanyarray(rois.dataobj)) ## this is the original 'merged' labeling 

	## removal of segmentations is required 
	not_labels = np.isin(np.asanyarray(rois.dataobj),  [44,45,48,99,199] ).astype(int) # remove regions 
	not_labels = (~not_labels.astype(bool)).astype(int)

	labels = np.asanyarray(rois.dataobj) * not_labels
	labels[labels == 87] = 43 ## merging high and low intensity thalami
	labels[labels == 86] = 42 ## merging high and low intensity thalami

	relabeled_rois = np.zeros_like(labels)
	for i, row in lookup.iterrows():
    		relabeled_rois[np.asanyarray(rois.dataobj) == row.old_label] = row.new_label
 
	relabeled_filename = 'tmp/ROIs_func_relabeled.nii.gz'
	ni_img = nib.Nifti1Image(relabeled_rois, rois.affine, dtype=np.int64)
	nib.save(ni_img,relabeled_filename  )

	if return_mask == True:
		mask = (relabeled_rois > 0).astype(np.int_)
		mask_filename='tmp/func_ROI_mask.nii.gz'
		ni_mask = nib.Nifti1Image(mask, rois.affine, dtype=np.int64)
		nib.save(ni_mask,mask_filename)
		
		return relabeled_filename, mask_filename
	else: 
		return relabeled_filename

def write_matrix(out_name, line):
	if os.path.isfile(out_name):
		name = out_name
		with open(out_name, 'rb') as handle:
			results = pickle.load(handle)
			results.update(line)
			#with open(out_name, 'wb') as handle:
				#pickle.dump(results, handle, protocol=pickle.HIGHEST_PROTOCOL)
		with open(name, 'wb') as out:
			pickle.dump(results, out, protocol=pickle.HIGHEST_PROTOCOL)
	else: 
		with open(out_name, 'wb') as handle:
        		pickle.dump(line, handle, protocol=pickle.HIGHEST_PROTOCOL)
        
	

if __name__ == "__main__":
	
	#print('START at: {}'.format(datetime.datetime.now()))

	### read in the file containing the list of subject ID and session IDs
	if len(sys.argv) < 3:
		print("You must provide subject id and session id!")
		sys.exit()
	else:
		subject_id = sys.argv[1]
		session_id = sys.argv[2]
		lookup = pd.read_csv('../../DerivedData/lookup_parcellation_labels.csv')


	### relabel here 
	iFUNC='rel3_dhcp_fmri_pipeline/sub-{}/ses-{}/func/sub-{}_ses-{}_task-rest_desc-preproc_bold.nii.gz'.format(
                            subject_id, session_id,subject_id, session_id)
	iROI='tmp/ROIs_func.nii.gz'.format(subject_id, session_id)

	if not os.path.isfile(iROI):
		sys.exit('Parcellation missing')
	else: 
		fmri = load_img(iFUNC)
		rois = load_img(iROI)
		
		relabeled_filename, mask_filename = relabel_ROIs(rois=rois, lookup_table=lookup, return_mask=True)
		mask = load_img(mask_filename)

		### post-process here 
		tr=0.392
		smooth=3.225

		masker = NiftiLabelsMasker(labels_img=relabeled_filename, strategy='median', standardize='zscore', 
                           low_pass=0.1, t_r=tr, smoothing_fwhm = smooth,
                         memory='nilearn_cache', verbose=False, mask_img = mask)
		time_series = masker.fit_transform(fmri) 
		# trim 
		time_series = time_series[50:-50]
			

		### compute matrix here 
		
		for metric, name in zip(['correlation', 'partial correlation'], ['correlation', 'partial_correlation']):
			correlation_measure = ConnectivityMeasure(kind=metric)
			correlation_matrix = correlation_measure.fit_transform([time_series])[0]
			np.fill_diagonal(correlation_matrix , 0)

			result = {session_id: correlation_matrix}
			write_matrix(out_name='/neurospin/grip/external_databases/dHCP_CR_JD_2018/Projects/networks/DerivedData/matrices/functional/{}.pickle'.format(name), line=result)
			
		
