# Spiky

## Description

A MATLAB package for neural data analysis

## Usage

Open the +config/Config.yaml file and change the corresponding fields to match your setup.

- `fdirCode`: the path to the code directory.
- `fdirData`: the path to the data directory containing all session folders.
- `fdirDataCloud`: the path to the data directory on the server.
- `fdirDataRemoteRaw`: the path to the raw data directory on the recording computer.
- `fdirDataRemoteLog`: the path to the log data directory on the recording computer.
- `fdirDataRemoteMinos`: the path to the Minos data directory on the Unity computer.
- `fdirConda`: the path to the conda environment directory.
- `envKilosort4`: the name of the conda environment for Kilosort4.
- `channelConfig`: channel names for all analog and digital channels.

## Data structure

After each recording, the data should be put in a folder `fdirData/SessionName`. The 
electrophysiological data goes into the `Raw` subfolder and the behavioral data goes to the `Minos` 
folder.

The preprocessing produces the following files. To load these files, create a `spiky.ephys.Session` 
object by calling
```
session = spiky.ephys.Session(SessionName);
```
and use the corresponding methods of the session object:
```
info = session.getInfo();
spikes = session.getSpikes();
minos = session.getMinos();
```

- `SessionName.spiky.ephys.SessionInfo.mat`: the general information about the session.
  - `.Session`: the `spiky.ephys.Session` object.
  - `.NChannels`: the total number of channels including ADC channels.
  - `.Fs`: sampling frequency.
  - `.FsLfp`: sampling frequency of LFP.
  - `.NSamples`: number of samples.
  - `.NSamplesLfp`: number of samples of LFP.
  - `.Duration`: total duration in seconds.
  - `.Precision`: format of the binary data.
  - `.FpthDat`: path(s) to the raw binary files.
  - `.FpthLfp`: path to the (usally resampled) LFP file.
  - `.ChannelGroups`: `spiky.ephys.ChannelGroup` objects for all probes plus ADC.
    - `.Name`: name of the group.
    - `.NChannels`: number of channels in the group.
    - `.ChannelType`: type of the channels in the group, e.g. `Neural` or `Adc`.
    - `.ChannelNames`: names of the channels in the group for ADC channels.
    - `.Probe`: probe.
    - `.BitVolts`: bit to voltage conversion factor.
    - `.ToMv`: conversion factor to mV.
  - `.EventsGroups`: `spiky.ephys.EventsGroup` objects for all probes plus ADC and network.
    - `.Name`: name of the group.
    - `.Type`: type of the events in the group, e.g. `Neural` or `Adc` or `Net`.
    - `.Events`: `spiky.ephys.RecEvent` objects for all events.
    - `.TsRange`: original timestamp range of the events.
    - `.Sync`: `spiky.core.Sync` object for synchronization from the first probe to the group. Use 
    the `spiky.core.Sync.Inv` function to convert timestamps from the group to the first probe.
  - `.Options`: options used during the preprocessing.
- `SessionName.spiky.ephys.SpikeInfo.mat`: the spike data.
  - `.Spikes`: `spiky.core.Spikes` objects for all units.
    - `.Neuron`: neuron metadata.
      - `.Session`: the `spiky.minos.Session` object.
      - `.Group`: channel group.
      - `.Id`: zero-indexed unit ID from kilosort.
      - `.Region`: brain region.
      - `.Ch`: channel number of maximum amplitude in all channels.
      - `.ChInGroup`: channel number of maximum amplitude in the group.
    - `.Time`: spike times in seconds.
  - `.Options`: options used during the preprocessing.
- `SessionName.spiky.minos.MinosInfo.mat`: the behavioral data.
  - `.Session`: the `spiky.minos.Session` object.
  - `.Vars`: `spiky.core.Parameter` objects for all variables in the global settings.
    - `.Name`: name of the variable.
    - `.Type`: the original .NET type of the variable.
    - `.Values`: `spiky.core.TimeTable` object for the values of the variable at each time point.
    - `.Time`: time points of the values, same as `.Values.Time`.
    - `.Data`: the values of the variable, same as `.Values.Data`.
  - `.Paradigms`: `spiky.minos.Paradigm` objects for all paradigms.
    - `.Name`: name of the paradigm.
    - `.Periods`: `spiky.core.Periods` object for the beginning and end of each play.
    - `.Trials`: `spiky.core.TimeTable` object for the trials.
      - `.Time`: time points of the trials.
      - `.Data`: a table containing the `TrialInfo` struct for each trial and all `TrialEvent` 
      timestamps. If photodiode is available, the timestamps of each event is corrected to the 
      photodiode timestamps.
    - `.Vars`: `spiky.core.Parameter` objects for all variables in the paradigm.
  - `.Sync`: `spiky.core.Sync` object for synchronization from the first probe to the behavioral 
  data. Use the `spiky.core.Sync.Inv` function to convert timestamps from the behavioral data to 
  the first probe.
  - `.Eye`: `spiky.minos.EyeData` object for the eye tracking data
    - `.Data`: `spiky.core.TimeTable` object containing the pupil size and gaze position of each 
    eye and the convergence.
    - `.Fixations`: `spiky.core.Periods` object for the fixations.
    - `.Saccades`: `spiky.core.Periods` object for the saccades.
    - `.Blinks`: `spiky.core.Periods` object for the blinks.
  - `.Player`: `spiky.core.TimeTable` object containing the player position and orientation.
  - `.Display`: `spiky.core.TimeTable` object containing the camera position and orientation.
  - `.Input`: `spiky.core.TimeTable` object containing the input from the controller.
  - `.ExperimenterInput`: `spiky.core.TimeTable` object containing the input from the experimenter 
  keyboard.
  - `.Reward`: `spiky.core.TimeTable` object containing the reward times.

## License

This project is licensed under the [MIT License](LICENSE).
