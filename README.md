# Zephyr-box

This project strives to make containerized development with Nordic/ST chips, Zephyr-RTOS and VS Code as smooth as possible.
It also provides an environment for running CI-jobs.

## Usage

1. Install `Dev Containers` extension.
   (There should also be a recommendation pop-up window prompting to install recommended extensions)
2. Clone this repository to an empty directory so that there are no siblings.
3. Open it in VSCode.
4. When get prompted to `Reopen in Container`, do so.
   In case prompt does not come, call `Dev Container: Reopen in container` Action.
5. Wait until setup is complete. Should you see prompts to Reload Window, don't do that just yet.
   First time it may take a while, because the image is built or downloaded and then setup scripts are run.
6. Reload Window (either through prompt or just close and open it).
   It's needed for some extensions and to select newly installed python venv for tasks.
7. Enjoy! Or not.

You can also run bash in Docker by `run_in_docker.sh` script without additional arguments.
Then you can also attach to running container with VSCode, but you won't have docker extensions and some other configurations.
If you want to run a specific command, you may also do `run_in_docker.sh west update` for example.
You can even build or flash from the calling context just need to ensure, that west is called from the directory containing
the `CMakeLists.txt` with `run_in_docker.sh sh -c "cd project/app && west build"` and
`run_in_docker.sh sh -c "cd project/app && west flash -r pyocd"`.

The container expects to be the subdirectory of a directory providing a `requirements.txt` and a `west.yml` file.

---

## Troubleshooting

1. For debugging on Windows WSL you will need:
- [USB-IP](https://github.com/MicrosoftDocs/wsl/blob/main/WSL/connect-usb.md)
- NRF command line tools on WSL and Windows
- Restaring udev: `sudo service udev restart && sudo udevadm control --reload`

2. Minicom has to be setup to use Logs. It's not done since Serial ports can be individual. Check them with `dmesg | grep tty`, `lsusb`. Usually it's something like `/dev/ttyACM0`.
Use `sudo minicom -s` to set it up, `/dev/ttyACM0` is set as default.

2. If building container does not work:
   - try adding `--no-cache` to `docker build` command.
   - try running the first time from the shell script instead of VSCode to see the logs clearly without pop-up errors.
3. If you reloaded VSCode before intitial installation was complete, no problem.
   Close VSCode, run `docker ps`, stop running containers and open VSCode again.
4. If image is build succesfully in `run_in_docker.sh`, but you have issues with VSCode,
   try running `Dev Containers: Rebuild without cache and reopen in contaier` action (not from a container).
   Also ensure that there are no modification which cause container to exit before VSCode canattach itself.
5. If you have issues with `west flash`, ensure `$LANG` is not set.
   "terminal.integrated.detectLocale": "off" has to be off, otherwise VSCode sets this ENV.
