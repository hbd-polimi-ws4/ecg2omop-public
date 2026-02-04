# ecg2omop-public
Extract Transform and Load (ETL) pipeline for electrocardiography (ECG) signals processing, feature extraction, and mapping into OMOP CDM.

# Requirements, dependencies, and setup process
This pipeline has been tested on several Linux-based (Fedora and Ubuntu) systems, but it should work fine on Windows too, with no foreseen issues.

First, we need the following software installed, which shouldn't require administrator privileges on your machine (as long as unprivileged paths are chosen for the installation):
1. **MATLAB**: <ins>Only releases from R2020b to R2023a are supported</ins>, as compatibility with Python 3.8 is ensured with all these versions (check it out [here](https://uk.mathworks.com/support/requirements/python-compatibility.html)). We used **R2023a** to develop the code, and this version is the only one we tested. Including the **Parallel Computing Toolbox** in the installation is recommended for running the pipeline example script (`example.m`).
2. **Python 3.8**: <ins>The 3.8 version is strictly required</ins> as the automatic ECG diagnosis pipeline we selected can only utilize TensorFlow up to the 2.2.0 version, which isn't compatible with later Python versions. To install Python and the required packages for this pipeline, we suggest using a virtual environment manager, such as Miniconda. If you've never installed one, you can refer to the [official Miniconda installation webpage](https://www.anaconda.com/docs/getting-started/miniconda/install#linux-terminal-installer). If you prefer, to install Miniconda on Linux and familiarize yourself with the basics, you can also follow [these simplified instructions](https://github.com/pierreali-gerp/server-utilization/blob/main/02-coolToolsForYourVM/conda.md) that Pierluigi curated.

To work correctly, this ETL pipeline requires setting up some open-source components:
- [**WFDB Toolbox for MATLAB**](https://physionet.org/content/wfdb-matlab/0.10.0/): This tool provides basic functions for reading and processing Physionet waveform (including ECG) datasets and related header and annotation files. The latest version of this toolbox (0.10.0), the one that was last tested in Jan 2026, can be directly downloaded from [this link](https://physionet.org/content/wfdb-matlab/get-zip/0.10.0/). We suggest that you unzip the downloaded file into a subfolder created in the typical _MATLAB user's folder_: on Windows, where it generally gets created during MATLAB's installation, you can find it at `C:\Users\Username\Documents\MATLAB`; on Linux, you can create one yourself in `/home/username/Documents/MATLAB` and add it to the Matlab path (without subfolders). After unzipping the content, permanently add the `mcode` subfolder (which relative path from your MATLAB folder should look like `wfdb-app-toolbox-0-10-0/mcode`) to the MATLAB path (<ins>without subfolders</ins>). Full instructions and troubleshooting can be found on the official project webpage linked above.

- **MHRV Toolbox for MATLAB**: The official GitHub repository for this tool is available [here](https://github.com/physiozoo/mhrv). For the needs of this ECG pipeline, the original version required a few edits that we integrated in [our fork of the original project](https://github.com/hbd-polimi-ws4/mhrv). To install this tool, you need to download the `.zip` file from the previous GitHub page (or clone the repository), unzip it in a folder, and permanently add this folder (without subfolders) to the MATLAB path. Afterwards, we must allow MHRV to interact with the WFDB libraries it needs. To do so, create a `bin` folder and a `wfdb` subfolder within it (i.e., create the path `bin/wfdb` inside the `mhrv` folder), move (`cd`) to the path where you previously unzipped the WFDB Toolbox and look for the `wfdb-app-toolbox-0-10-0/mcode/nativelibs` subfolder. Here, you find the WFDB libraries compiled for different OSs: open the folder corresponding to your OS and copy <ins>its content</ins> to the `bin/wfdb` path previously created within the `mhrv` base path. You can check if the MHRV toolbox is set up correctly by running `mhrv_init;` in the MATLAB command window, which should print a message like the following, with no further requests:
    ```
    Initializing mhrv toolbox in /home/pier8/Documents/MATLAB/mhrv...

    Notice: Detected WFDB version (10.5.25) is newer than the tested version (10.5.24)

    ```

- **Deep Neural Network for automatic-ecg-diagnosis**: The official GitHub repository for this tool is available [here](https://github.com/antonior92/automatic-ecg-diagnosis). For the specific needs of this ECG pipeline, we added custom functions to allow this tool to be called and used by the main pipeline running on MATLAB. We integrated all the required changes in [this fork of the original project](https://github.com/hbd-polimi-ws4/automatic-ecg-diagnosis). To install this tool, download the `.zip` file from the previous GitHub page and unzip it into a path of your choice (or just clone the repository). Then, install the related Python requirements in an environment with Python 3.8 already set up, as suggested above. To do so, within a terminal opened on the path where you unzipped the tool, ensure that the virtual environment you mean to modify is active and run `pip install -r requirements.txt`.

- **OMOP-5.4-PostgreSQL**: The original GitHub repository of this project is available [here](https://github.com/SmartChartSuite/OMOP-5.4-PostgreSQL). For our users' convenience, we just added a few clarifications in the original `docker-compose.yml` file, which we provide in [this fork](https://github.com/hbd-polimi-ws4/OMOP-5.4-PostgreSQL). For the execution of the **Load** operations of the ETL pipeline (performed by the `03-Load/MAINload` function), you need an SQL database already set up and running with the appropriate OMOP CDM v5.4 tables and related constraints. If you don't have an OMOP CDM database to play with, probably, the fastest and most automatable way to test our ECG pipeline is by relying on a pre-built container: the project mentioned above, provides a handy way to do this.
    >:warning: Currently, this modality is meant only for testing, not for production, since we haven't had the chance, yet, to test the above container extensively.

    To build the `OMOP-5.4-PostgreSQL` and start a container from it, you need a container runtime supporting the `compose` functionality. Popular options are *Docker* or *Podman*. In this brief guide, we assume you we'll be using Docker, but the same instructions would be applicable to Podman, with minimal changes.
    1. To begin with, check the following software is installed on your system:
        - `docker`: [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/) is the only viable option for Windows or Mac, while [Docker Engine](https://docs.docker.com/engine/install/) is a lighter version, suggested for Linux (we are going to use the CLI, anyway, that's why the Desktop version is not needed);
        - `docker-compose`: It should come with Docker Desktop, but it must be installed separately if you opted for Docker Engine.
        - `pgadmin4`: This is a GUI-based tool you can use to view, manage, and query PostgreSQL servers. On Linux, you can generally install this from the graphical app centers of many distros (e.g., Ubuntu's *Ubuntu Software* and Fedora's *Software*), as it usually comes packaged as a Snap or Flatpak app. For other platforms, you can download the official version from [pgAdmin website](https://www.pgadmin.org/).
    2. Clone [our fork](https://github.com/hbd-polimi-ws4/OMOP-5.4-PostgreSQL) of the *OMOP-5.4-PostgreSQL* project or download the repo as a `.zip` file and unzip it.
    3. To download the OMOP CDM standard vocabularies, register to [OHDSI's Athena](https://athena.ohdsi.org/search-terms/start) and log in. Then, click on Download, select all the vocabularies that do not require a license, and click on *Download vocabularies*. When the vocabularies are ready to be downloaded, you will receive an email with the download link. Create a `vocab` subfolder in the directory where you unzipped (or cloned) the *OMOP-5.4-PostgreSQL* repository. Unzip the archive containing the downloaded vocabularies and copy all the `.csv` files into the `vocab` subfolder you've just created.
    4. Read the content of the `docker-compose.yml` file in the repository. In OSs using SELinux, such as Fedora, modify the `.yml` file as suggested there.
    5. Open a terminal (or a Powershell, on Windows), move to the base folder of the *OMOP-5.4-PostgreSQL* repository (i.e., where the `docker-compose.yml` file is) and run:
        ```
        docker compose up
        ```
        Starting up the container will require some time (5-15 minutes, depending on the hardware of your PC), because the vocabularies in the `vocab` subfolder are imported automatically on container start.
    6. Once the import process has been completed, we can attach to the Postgresql server running on the container and interact with it through a GUI. Open pgadmin4 GUI. On the main screen, right-click on the *Server* icon, then *Register*, then *Server*. As server name in the *General* tab, specify `omop54`. In the *Connection* tab, specify `localhost` (or `127.0.0.1`) as *host* and `password` as the *password* of the Postgres DB you wish to connect to (you can change the default credentials from the `docker-compose.yml` file, if you wish). By clicking on *Save*, pgadmin will connect to the Postgresql server running on the Docker container.
    7. *Docker basics. How do we check if the container is running?*
        ```
        docker ps
        ```

        If the container doesn't show, try:

        ```
        docker ps --all
        ```
        If it doesn't show, again, it has been removed.

        *How do we stop a container that is running?* **Note:** a container is stopped also if the PC is powered off (but it is <ins>not</ins> *removed*, by default, so it can be restarted, as shown below, when the PC is switched back on).
        ```
        docker stop <container_name> #use "docker ps" to retrieve this
        ```
        *How do we start a container that has been stopped?* **Note:** if a container is stopped but it has not been removed, running `docker compose up` will result in an error. If this the case, you can choose whether you prefer to restart the container (with the command that follows) or to remove it and recreate it through `docker compose up`.
        ```
        docker start <container_name> #use "docker ps --all" to retrieve this
        ```
        *How do we remove a container (together with its local database)?* **Note:** You can only remove containers that have already been stopped.
        ```
        docker rm <container_name> #use "docker ps --all" to retrieve this
        ```
    8. *Optional. How can I perform a backup should I ever need it?* You can backup your `omop54` DB from pgadmin so that, if the container gets removed, the next time you start it the vocabularies and all the data you imported previously won't need to be loaded again. On Linux, you need to install a `postgresql` package to make this work. First, you need to tell pgadmin where is `pg_dump` and the other utilities it needs to perform the backup: File -> Preferences -> Binary paths -> type in `/usr/bin` (i.e., the path of the version of `postgresql` installed on the system; to see which version you have, run: `dnf info postgresql`). Then, you can create the backup through pgadmin: right-click on the DB -> backup -> tar
    
        *To restore a backup*, start the container without re-importing the vocabularies and setting the correct *constraints*: just comment all the lines of the `volume` section of `docker-compose.yml` and set the `CONSTRAINTS` parameter to "false" before running `docker compose up` as previously.  If you don't set the CONSTRAINTS to false, the restore procedure will fail. When the container is running, open pgadmin, connect to the postgresql server running on the container as before, right-click on the `omop54` DB and choose *Restore*, providing the previously created backup as input for the procedure.

After all the above is done, you can download the content of the present GitHub repository and unzip all the files (or clone the repository) to a path of your choice. Then, take a look to the `example.m` script you can find in the base path of the repo, change everything that you need in the first section, and run it to test the ECG pipeline. It will download for you all the PhysioNet repositories that were considered to develop it.

# ETL pipeline structure explanation

## Extract (E): ECG data import, processing, and feature-extraction functions
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

## Transform (T): Map the extracted information to OMOP CDM table attributes and standart concepts
**MAINtransform**: The main unit of the Transform step, responsible for transforming the tables created by the MAINextraction procedure and map the relevant information into OMOP CDM standard tables. It returns the requested set of standard tables that will then be imported into an OMOP SQL database during the Load step.

## Load (L): Load the obtained OMOP CDM tables to a database
**MAINload**: The main unit of the Load step, responsible for loading the OMOP CDM tables obtained at the end of the Transform step into a PostegreSQL OMOP CDM database that has been already configured with the OMOP CDM schema and standard vocabularies. This function also performs some (*basic*, at the moment) checks on whether the same records have been already uploaded to the database and inserts only available "new" ones.