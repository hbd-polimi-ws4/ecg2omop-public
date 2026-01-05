# ecg2omop-public
Pipeline for electrocardiography (ECG) signals processing, feature extraction, and mapping into OMOP CDM.

# ECG data import and processing functions
Each module of the pipeline corresponds to a MATLAB function and can be classified as a key component or an auxiliary one; the former are in particular:
1. **MAINextraction**: The main unit responsible for scanning the files contained in the directory of the dataset under examination, specifying the number of samples to be processed at a time, orchestrating and coordinating the activities involved by calling the other modules, and initialising the data structures needed to store the data to be exported at the end of the process.
2. **COMextraction**: Extracts and outputs the various information contained in the .hea files.
3. **SMPextraction**: Reads the .dat files and returns the sampled voltage values from each ECG record with a timestamp and the associated lead.
4. **RRextraction**: Determines the duration of the RR intervals by keeping track of the start and end timestamps.
5. **ANNextraction**: Processes annotation files by collecting any additional information indicated.
6. **MTRextraction**: Based on the MHRV Toolbox, evaluates all calculable indices for HRV.

The auxiliary components, listed below, serve as support routines for the execution of additional optimisation processes:
- **EXPLextraction**: To appropriately convert the encodings accepted in the annotation files into textual expressions that can be understood and interpreted by the OMOP CDM lexicon.
- **EXTextraction**: To detect the extensions of the processed files, checking the presence of the "ANNOTATOR" file to enable the activation of the other functions dedicated to the processing of this type of data.
- **FSextraction**: To retrieve the sampling frequency of digitised signals, to be passed as an argument to other routines for subsequent operations.
- **LEADextraction**: To generate a list of labels associated with detected leads from the extracted samples.
- **TMSextraction**: To format the timestamps reported with the processed data.
- **tableBuilder**: To initialise the tables for the semi-processed output .csv files.
- **tailPathRec**: To check the correct path of each record retrieved from a dataset.
- **translateDate**: To translate the given dates into a common format.
