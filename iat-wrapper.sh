#!/bin/bash
# my textarea wrapper into tmux for Firefox's It's All Text plugin
tmux neww -n tu.$(date +%m%d/%H%M.%S) "vim $@"
