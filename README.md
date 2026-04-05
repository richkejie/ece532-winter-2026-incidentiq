# ECE532: IncidentIQ

This project is hosted open-source under the [MIT License](LICENSE).

See our [`report`](doc/final-project-group-report) for an explanation of our project.

## Authors

- Bence Suranyi
- [Maanik Gogna](https://www.linkedin.com/in/maanikgogna/)
- [Darrian Shue](https://www.linkedin.com/in/darrian-shue-542230212)
- [Richard Wu](https://www.linkedin.com/in/richard-wu-5436681bb/)

## Video Demo (click on thumbnail to open video)

[![Project Demo](https://img.youtube.com/vi/5VhThBTUV0g/maxresdefault.jpg)](https://youtu.be/5VhThBTUV0g?si=I6DL9xni2X0iNleD)

## Repository Structure

| Directory                                   | Description                                                                                                     |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| [`incident_iq/`](incident_iq/)              | Vivado project files, including the constraint file, block design files, SDK files, and the `.xpr` project file |
| [`src/rtl/`](src/rtl/)                      | RTL design files (imported into Vivado rather than copied, to keep the project directory clean)                 |
| [`src/verif/`](src/verif/)                  | Simulation/verification files                                                                                   |
| [`fw_sdk/`](fw_sdk/)                        | SDK projects, importable via the SDK interface                                                                  |
| [`sw/bluetooh-and-sd`](sw/bluetooth-and-sd) | Bluetooth and SD card processing scripts                                                                        |
| [`sw/visualizer/`](sw/visualizer/)          | Visualizer source code                                                                                          |
| [`systemrdl/`](systemrdl/)                  | SystemRDL files. See the [overview](systemrdl/systemrdl-crash-course.pdf) for usage instructions                |
| [`doc/`](doc/)                              | Contains our project group report and presentation slides                                                       |
