Instructions for the use of the MATLAB automated image analysis program
Authors: Joshua James Elacqua, Jan Lammerding
Date: March 5, 2018

System requirements/compatibility: 
This program was written in MATLAB version R2016a and will not work on older versions due to certain functions that are used. The following MATLAB toolboxes must be installed: 
- Computer Vision System Toolbox 
- Control System Toolbox 
- Image Processing Toolbox 
- Parallel Computing Toolbox

The program can accept both *.avi and *czi files as input.
To read *.avi files, please ensure that the movie contains color (RGB) images with H2B-tdTomato in the red color channel, NLS-copGFP in the green color channel, and DIC in the blue color channel.
In order to read *.czi files, the Bio-Formats MATLAB Toolbox must be downloaded from the Open Microscopy Environment website (https://www.openmicroscopy.org/bio-formats/) and added to the MATLAB search path. 

Application Note I: The MATLAB code was designed specifically for Windows. It should also run on Mac/Linux systems; however, the directory path/syntax may have to be adjusted so that files are written into the proper directories. 

Application Note II: To analyze videos of cell migration in unconfined, 2-D environments, enter ‘0’ for the constriction size

Installation: 
Copy the following files and folder into the MATLAB directory or a directory accessible to the MATLAB search path: 
- “AutomatedMigrationAnalyzer2.m” file 
- “MigrationAnalysisVerification2.m” file 
- “Migration Analysis” folder (including its full content)
 
 
Instructions for example data: 

1. Run the "AutomatedMigrationAnalyzer2.m" script in MATLAB. 
2. Select "MDA-MD-468 NLS-copGFP H2B-tdTomato 0to10FBS 2umConstrictions 10minPerImage.czi" or "MDA-MD-468 … 10minPerImage.avi" from the file explorer GUI. If the *.avi files is selected, please ignore steps 4 and 7 below.
3. Select/create a folder for the results generated by the program. For the example, create and select a folder "...\Program Example\" as the location for the results files. 
4. Choose to analyze every position of a migration device or a subset of positions. The example file has only one position, so select all.
5. Enter the constriction sizes of the migration device positions being analyzed. For this example, the size is 2 (microns). 
6. Select in which direction cells migrate. In the example, cells migrate from bottom to top. 
7. Select the order of the fluorescent channels being used. The order of the channels can be viewed by opening the .czi file in ZEN or FIJI. In the example file, H2B-tdTomato is in the first channel, so enter 1; NLS-copGFP is in the second channel, so enter 2. 
8. Wait a few moments for the program to automatically rotate the image sequence and locate the constrictions. 
9. Verify that the constriction detection and alignment worked properly. If the constriction detection/alignment did not work properly, the user is prompted to manually define the boundaries for the constrictions. 
10. Wait for the program to analyze the image sequence. 
11. Run "MigrationAnalysisVerification2.m" 
12. Navigate to the folder that was chosen to save the results in when starting AutomatedMigrationAnalyzer2.m and select the newly created folder containing the migration tracking results. 
13. Select the migration device position to begin verifying the tracking results. The example has only one position, so choose 1, i.e., start verifying the tracking results from the first position. 
14. Scroll through the video of tracked nuclei to confirm all automated results. Do this by using the scroll bar at the bottom of the window, the mouse wheel, or the arrow keys. Fix any tracking errors if necessary (see below for detailed instructions). The provided example should not contain any tracking errors. 
15. Close the window with the tracking results to save data on constriction transit and nuclear envelope rupture duration. 
16. View the results saved in the *.csv files. See below for a description of the saved results. 

Fixing Tracking Errors: 
Tracking errors can be fixed by clicking on the corresponding nuclei. Different options are available depending on whether the left or right mouse button is used, and if only one nucleus is clicked or if two nuclei are selected.

To select a nucleus to make corrections to the nuclear envelope rupture detection/labeling, click with the right mouse button. This will allow a rupture event to be ended earlier than the program identified, cancel the rupture event entirely, or create a new rupture event not detected by the program. 

To make corrections to a single nucleus, click on it twice with the left mouse button. This option can be used to perform such actions as deleting the selected object if the program mistakenly identified it as a nucleus, or splitting the object into two nuclei if the program mistakenly identified two touching nuclei as a single nucleus. 

To make corrections involving two nuclei, click on each nucleus once with the left mouse button. This option can be used to perform such actions as combining two objects if the program mistakenly split a nucleus in two, or to inform the program that it made a tracking mistake and switch two mismatched nuclei.
 
If the program loses track of an identified nucleus, but identifies it again at a later time point, these nuclei can be manually linked to generate a continuous track for the nucleus. To do this select the original nucleus at any time point that it is identified (visible via a nuclear outline), then scroll the image sequence forward to the time point where the nucleus is once again identified (visible via a differently colored nuclear outline) and select this nucleus. The nuclei should now be paired, and outlined consistently with the same color throughout the video. 

Saved Results: 
The files titled “row X.csv” contain constriction transit data for each row of constrictions, with row 1 indicating the first row of constrictions in the migration direction. These results include identification for each cell attempt at migration through a constriction and whether the attempt was successful or not. Such information can be used to determine the percentage of cells successfully passing through each constriction.

The file titled “successes.csv” contains constriction transit data for all successful attempts at passing through the constrictions. This file allows the user to calculate the average constriction transit time. 

The file titled “rupture.csv” contains data for each detected nuclear envelope rupture event. These data include the duration of the rupture, and information whether the rupture was caused by the nucleus attempting to pass through a constriction or occurred outside a constriction. Ruptures that are still ongoing at the end of the video (i.e., the NLS-GFP signal has not been fully reentered the nucleus) are not stored in this file, but rather in a file titled “unfinished ruptures.csv”. Since the completion of these rupture events cannot be observed, these ‘unfinished’ events cannot be included when calculating the average duration of nuclear envelope rupture events. 

The file titled ‘rupture2.csv” contains the normalized fluorescence data for the NLS-GFP and the H2B-TdTomato signal (see Figure 6c). Each row in the file contains the fluorescence intensity ratios for a single cell starting 10 time points prior to the beginning of a nuclear envelope rupture event (or when the nucleus is first identified, in the case the nuclear envelope rupture starts before 10 time points have not passed), until the end of the video or the beginning of another rupture event.
