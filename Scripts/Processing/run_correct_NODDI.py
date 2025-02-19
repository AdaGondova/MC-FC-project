####bv bash environment 
## use the old one: /i2bm/brainvisa/brainvisa-cea-5.0.4/bin/bv bash
## there has been changes to the new one which break this

from soma import aims 
import pandas as pd 
from skimage.feature import peak_local_max
from scipy import ndimage as ndi
import matplotlib.pyplot as plt
import numpy as np
import os, datetime, sys
from scipy.signal import find_peaks

## NOISE REMOVAL 
#from skimage.filters.rank import median 
from scipy.ndimage import median_filter, gaussian_filter, generic_filter
from skimage.morphology import disk, ball, cube
from scipy.stats import trim_mean

### To learn more about the NODDI model
## http://mig.cs.ucl.ac.uk/index.php?n=Tutorial.NODDImatlab 

##====================== FUNCTIONS ===================##
def alpha_trim(y):
    
    inp = y.copy()
    inp.sort()
    
    middleIdx = int(len(inp)/2)
    
    return np.mean(inp[middleIdx-1:middleIdx+2])

def alpha_trim_only_outside_range(y, first_peak):
    inp = y.copy()
    middleIdx = int(len(inp)/2)
    
    if (0< inp[middleIdx] < first_peak) or (inp[middleIdx] > 0.95):
        inp.sort()
        inp = inp[(inp >= first_peak) & (inp < 0.95)]
        
        if len(inp) <= 1:
            return np.nan
    
        elif 1 < len(inp) < 3:
            return np.mean(inp)
        
        else: 
            idx = int(len(inp)/2)
            return np.mean(inp[idx-1:idx+2])
            #return np.mean(inp)
    else: 
        return inp[middleIdx]
    
def calculate_corrected_number(y, first_peak):
    inp = y.copy()
    middleIdx = int(len(inp)/2)
    
    if (0 < inp[middleIdx] < first_peak) or (inp[middleIdx] > 0.95):
        inp.sort()
        inp = inp[(inp >= first_peak) & (inp < 0.95)]
        
        if len(inp) <= 1:
            return 2000

        elif 1 < len(inp) < 3:
            return 1000
        
        else: 
            idx = int(len(inp)/2)
            return 1000
            #return np.mean(inp)
    else: 
        return inp[middleIdx]

def denoise_NDI(NDI_image, arg):

    new_NDI = NDI_image.copy()
    for i in range(len(arg[0])):
        idx = (arg[0][i], arg[1][i], arg[2][i])
        #print(im_NDI[idx])
        if im_NDI[idx] > 0:
        
    
            cube = im_NDI[idx[0]-1:idx[0]+2,idx[1]-1:idx[1]+2,idx[2]-1:idx[2]+2 ]
            inp = cube.ravel()
            middleIdx = int(len(inp)/2)
            inp.sort()
        
            new_NDI[idx] = np.mean(inp[middleIdx-1:middleIdx+2])
            
            #new_NDI[idx] = np.mean(inp[1:-1])
    
            #print(np.mean(inp[middleIdx-1:middleIdx+2]))
            #print(np.mean(inp[1:-1]))
            #print(inp)
    
        else: 
            new_NDI[idx] = im_NDI[idx]
            #print(im_NDI[idx])
        
    return new_NDI

############################ RUN CORRECTIONS 

if __name__ == "__main__":
	print('START at: {}'.format(datetime.datetime.now()))	
	
	### read in the file containing the list of subject ID and session IDs
	if len(sys.argv) < 2:
		print("You must provide subject file!")
		sys.exit()
	else:
		subject_file = sys.argv[1]

	subjects = pd.read_csv(subject_file, header=None)


	for i, row in subjects.iterrows():

		oOD = '/neurospin/grip/external_databases/dHCP_CR_JD_2018/release3/dhcp_dmri_shard_pipeline/sub-{}/ses-{}/dwi/NODDI/cOD.nii.gz'.format(row[0], row[1])
		oNDI = '/neurospin/grip/external_databases/dHCP_CR_JD_2018/release3/dhcp_dmri_shard_pipeline/sub-{}/ses-{}/dwi/NODDI/cNDI.nii.gz'.format(row[0], row[1])
		
		if os.path.isfile(oOD) and os.path.isfile(oNDI):
			print(row[0], row[1], 'already  had corrected NDI and ODI.')
			print('SKIPPING')
		else:

			print('Working on: ', row[0], row[1])

			iVol = aims.read('/neurospin/grip/external_databases/dHCP_CR_JD_2018/release3/dhcp_dmri_shard_pipeline/sub-{}/ses-{}/dwi/NODDI/OD.nii.gz'.format(row[0], row[1]))
			im = iVol.arraydata()[0]

			### get range
			his, bin_edges = np.histogram(im.ravel(), bins=np.arange(0.01,1.01,0.01))
			peaks, _ = find_peaks(his*-1, distance=25)
			first_peak = round(bin_edges[peaks[0]],3)
			#print(first_peak)
    
			### quantify found for correction 
			denoised = generic_filter(im, calculate_corrected_number, size=2, extra_arguments=(first_peak,)) 
 			#print('Corrected voxels: {} ({}%)'.format(
                	#        len(denoised[denoised == 1000]),
                	#        len(denoised[denoised == 1000])*100/len(denoised.ravel())))
			#print('Set to NAN {} ({}%)'.format(
                	#        len(denoised[denoised == 2000]),
                	#        len(denoised[denoised == 2000])*100/len(denoised.ravel())))
    
			#====== CORRECT & SAVE ODI
			denoised_ODI = generic_filter(im, alpha_trim_only_outside_range, size=2, extra_arguments=(first_peak,))
			denoised_ODI[ np.isnan(denoised_ODI)] = 0

		
			new_ODI = aims.Volume(denoised_ODI)
			new_ODI.header().update(iVol.header())
			aims.write(new_ODI, oOD)
			if os.path.isfile( oOD):
                		print('{} {} {} metric finished'.format(row[0], row[1], 'ODI'))
    
			#===== CORRECT & SAVE NDI
			### Set 'turned-off' voxels found in ODI to 0 in NDI file as well
			iVol = aims.read('/neurospin/grip/external_databases/dHCP_CR_JD_2018/release3/dhcp_dmri_shard_pipeline/sub-{}/ses-{}/dwi/NODDI/mean_fintra.nii.gz'.format(row[0], row[1]))

			im_NDI = iVol.arraydata()[0]
    
			#denoised_NDI = im_NDI.copy()
			#denoised_NDI[np.where(denoised == 2000)] = 0
    
			arg = np.where(denoised == 1000)
			denoised_NDI = denoise_NDI(NDI_image = im_NDI, arg = arg)
    
			denoised_NDI_turned_off = denoised_NDI.copy()
			denoised_NDI_turned_off[np.where(denoised == 2000)] = 0

			new_NDI = aims.Volume(denoised_NDI_turned_off)
			new_NDI.header().update(iVol.header())
			aims.write(new_NDI, oNDI)
			if os.path.isfile(oNDI):
                		print('{} {} {} metric finished'.format(row[0], row[1], 'NDI'))
			else:
				print('Something went wrong with the correction')
	
	print('END at: {}'.format(datetime.datetime.now()))

