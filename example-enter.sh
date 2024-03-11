# This bash file contains the configuration for developing in the container.

# First, we load the coonfiguration utilities.
source zephyr-box/devconfig.sh

# Specify the image to use.
use_image "zephyr-box"

# Next, we specify some ordinary mounts and add our custom bashrc extensions.
bashconfig ".dotfiles/bashrc_custom"
mountpoint "~/.ssh" "/home/user/.ssh" "ro"
mountpoint "~/.tmux.conf" "/home/user/.tmux.conf" "ro"

# Project mappings


# Here, we create and mount a volume in which we include configs and files that
# need to be modifiable.
volumemount "zephyrstore" "/home/user/.volume" "rw"
mountlink "~/.config/nvim" "zephyrstore" "/home/user/.config/nvim"
volumelink "zephyrstore" "/home/user/.local/share/nvim"

# Now, we build it.
build_and_run

