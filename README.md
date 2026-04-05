# ECE532: IncidentIQ

This project is hosted open-source under the [MIT License](LICENSE).

## Repository Structure

| Directory                          | Description                                                                                                     |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| [`incident_iq/`](incident_iq/)     | Vivado project files, including the constraint file, block design files, SDK files, and the `.xdc` project file |
| [`src/rtl/`](src/rtl/)             | RTL design files (imported into Vivado rather than copied, to keep the project directory clean)                 |
| [`src/verif/`](src/verif/)         | Simulation/verification files                                                                                   |
| [`fw_sdk/`](fw_sdk/)               | SDK projects, importable via the SDK interface                                                                  |
| [`sw/`](sw/)                       | Bluetooth and SD card processing scripts                                                                        |
| [`sw/visualizer/`](sw/visualizer/) | Visualizer source code                                                                                          |
| [`systemrdl/`](systemrdl/)         | SystemRDL files. See the [overview](systemrdl/systemrdl-crash-course.pdf) for usage instructions                |
