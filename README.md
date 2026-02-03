# ecg2omop-public
Pipeline for electrocardiography (ECG) signals processing, feature extraction, and mapping into OMOP CDM.

# Requirements, dependencies, and setup process
This pipeline has been tested on several Linux-based (Fedora and Ubuntu) systems, but it should work fine on Windows too, with no foreseen issues.

First, we need the following software installed, which shouldn't require administrator privileges on your machine (as long as unprivileged paths are chosen for the installation):
1. **MATLAB**: <ins>Only releases from R2020b to R2023a are supported</ins>, as compatibility with Python 3.8 is ensured with all these versions (check it out [here](https://uk.mathworks.com/support/requirements/python-compatibility.html)). We used **R2023a** to develop the code, and this version is the only one we tested. Including the **Parallel Computing Toolbox** in the installation is recommended for running the pipeline example script (`example.m`).
2. **Python 3.8**: <ins>The 3.8 version is strictly required</ins> as the automatic ECG diagnosis pipeline we selected can only utilize TensorFlow up to the 2.2.0 version, which isn't compatible with later Python versions. To install Python and the required packages for this pipeline, we suggest using a virtual environment manager, such as Miniconda. If you've never installed one, you can refer to the [official Miniconda installation webpage](https://www.anaconda.com/docs/getting-started/miniconda/install#linux-terminal-installer). If you prefer, to install Miniconda on Linux and familiarize yourself with the basics, you can also follow [these simplified instructions](https://github.com/pierreali-gerp/server-utilization/blob/main/02-coolToolsForYourVM/conda.md) that Pierluigi curated.

To function correctly, this Extraction Transform and Load (ETL) pipeline requires setting up some open-source components:
- [**WFDB Toolbox for MATLAB**](https://physionet.org/content/wfdb-matlab/0.10.0/): This tool provides basic functions for reading and processing Physionet waveform (including ECG) datasets and related header and annotation files. The latest version of this toolbox (0.10.0), the one that was last tested in Jan 2026, can be directly downloaded from [this link](https://physionet.org/content/wfdb-matlab/get-zip/0.10.0/). We suggest that you unzip the downloaded file into a subfolder created in the typical _MATLAB user's folder_: on Windows, where it generally gets created during MATLAB's installation, you can find it at `C:\Users\Username\Documents\MATLAB`; on Linux, you can create one yourself in `/home/username/Documents/MATLAB` and add it to the Matlab path (without subfolders). After unzipping the content, permanently add the `mcode` subfolder (which relative path from your MATLAB folder should look like `wfdb-app-toolbox-0-10-0/mcode`) to the MATLAB path (<ins>without subfolders</ins>). Full instructions and troubleshooting can be found on the official project webpage linked above.
- **MHRV Toolbox for MATLAB**: The official GitHub repository for this tool is available [here](https://github.com/physiozoo/mhrv). For the needs of this ECG pipeline, the original version required a few edits that we integrated in [our fork of the original project](https://github.com/hbd-polimi-ws4/mhrv). To install this tool, you need to download the `.zip` file from the previous GitHub page (or clone the repository), unzip it in a folder, and permanently add this folder (without subfolders) to the MATLAB path. Afterwards, we must allow MHRV to interact with the WFDB libraries it needs. To do so, create a `bin` folder and a `wfdb` subfolder within it (i.e., create the path `bin/wfdb` inside the `mhrv` folder), move (`cd`) to the path where you previously unzipped the WFDB Toolbox and look for the `wfdb-app-toolbox-0-10-0/mcode/nativelibs` subfolder. Here, you find the WFDB libraries compiled for different OSs: open the folder corresponding to your OS and copy <ins>its content</ins> to the `bin/wfdb` path previously created within the `mhrv` base path. You can check if the MHRV toolbox is set up correctly by running `mhrv_init;` in the MATLAB command window, which should print a message like the following, with no further requests:
    ```
    Initializing mhrv toolbox in /home/pier8/Documents/MATLAB/mhrv...

    Notice: Detected WFDB version (10.5.25) is newer than the tested version (10.5.24)

    ```
- **Deep Neural Network for automatic-ecg-diagnosis**: The official GitHub repository for this tool is available [here](https://github.com/antonior92/automatic-ecg-diagnosis). For the specific needs of this ECG pipeline, we added custom functions to allow this tool to be called and used by the main pipeline running on MATLAB. We integrated all the required changes in [this fork of the original project](https://github.com/hbd-polimi-ws4/automatic-ecg-diagnosis). To install this tool, download the `.zip` file from the previous GitHub page and unzip it into a path of your choice (or just clone the repository). Then, install the related Python requirements in an environment with Python 3.8 already set up, as suggested above. To do so, within a terminal opened on the path where you unzipped the tool, ensure that the virtual environment you mean to modify is active and run `pip install -r requirements.txt`.

After all the above is done, you can download the content of the present GitHub repository and unzip all the files (or clone the repository) to a path of your choice, which you will add to the MATLAB path. **To be continued with instructions for each remaining component of the pipeline (i.e., Transform and Load).**

For the execution of the **Load** operations of the ETL pipeline, you need an SQL database already set up with the appropriate OMOP CDM v5.4 tables and related constraints. If you don't have an OMOP database yet, probably, the most convenient way to configure it automatically is by relying on containers. [This repository(add link!)](LinkToOurRepoToBeAdded) is a fork of the [original project](https://github.com/SmartChartSuite/OMOP-5.4-PostgreSQL), which just changes a few specific settings for our use case. 

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
