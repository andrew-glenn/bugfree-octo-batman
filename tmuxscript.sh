#!/bin/bash

## Things you can change. 
#debug=true
session_name="raxauto"
max_win_panes="12"
window_number="0"
script_command="touch"

## Do not edit below this line.
current_panes="1"
#declare -A layout_array=(['4x4']='4492,96x11,0,0[96x2,0,0{48x2,0,0,17,47x2,49,0,24},96x2,0,3{48x2,0,3,18,47x2,49,3,23},96x2,0,6{48x2,0,6,19,47x2,49,6,22},96x2,0,9{48x2,0,9,20,47x2,49,9,21}]' )

text $TMUX
if [ $? -eq 0 ]; then
    echo "You're in a TMUX session. This isn't advised."
    echo "Bad things may happen if you continue. "
    echo "Please exit your tmux session and try again."
    exit 1
fi

function window_check(){
        set_layout
        tmux set-window-option -t :$window_number synchronize-panes on
 
        export window_number=$((window_number+1))
        tmux new-window -t $session_name:$window_number
        export current_panes=1
        export new_window=true 

        tmux select-window -t $session_name:$window_number
        launch_all_zig
}

function launch_all_zig(){
    if [ "$1" == "first" ]; then
        [ $i -eq 1 ]; i=0
        tmux send-keys -t $session_name:0.0 "$script_command ${raxinfo[$i]}" C-m
    else
        tmux send-keys "$script_command ${raxinfo[$i]}" C-m
    fi
}

function set_layout(){

    if [ "$1" == "tiled" ]; then
        layout_setup="tiled"
    fi
    
    tmux select-layout -t $session_name:$window_number $layout_setup >/dev/null 2>&1
}

function usage(){
    echo "Usage:"
    echo
    echo "$0 [-l External List] [-s External Script] [-t]"
    echo 
    echo "If no options are passed, $0 will look for 'list' within the current directory, and will execute as"
    echo "defined in the \$script_command variable at the top of the script."
    echo
    echo "Each value in 'list' (or what is provided with the -l option) will be the last argument for what is defined as \$script command"
    echo "Ex: ping 1.2.3.4, where ping is the \$script_command variable and '1.2.3.4' is a value within 'list'"
    echo
    echo "-t is used for nested tmux windows"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

OPTERR=0
while getopts "tsn:l:"  OPTION; do 
    case "$OPTION" in
        s) external_script="${OPTARG}";;
        l) external_list="${OPTARG}"; total_panes=${#raxinfo[@]};;
        n) custom_session_name="${OPTARG}";;
        t) this_tmux_window=true;;
        ?) usage;; 
    esac
done


if [ -n "$external_list" ]; then 
    if [ -e "$external_list" ]; then  
        raxinfo=($(cat $external_list)); 
    else
        raxinfo=$external_list
    fi
fi

if [ -n "$external_script" ]; then
    if [ -e "$external_script" ]; then
        script_command="$external_script"
    else
        echo "$external_script doesn't exist, or isn't executable!"
        exit 1
    fi
fi

if test $custom_session_name; then
    session_name=$custom_session_name
fi


if ! test $this_tmux_window; then 
    tmux has-session -t $session_name >/dev/null 2>&1
fi

# If the tmux session named $session_name doesn't exist...
if [ $? -eq 1 ]; then 
    tmux new-session -s $session_name -d 
fi

total_panes=${#raxinfo[@]}
for i in $(seq 0 $((total_panes -1))); do
    if [[ $current_panes -eq 1 ]]; then
        launch_all_zig "first"
        first_post=true
    fi
    

    if [[ $window_number -eq 0 ]] && [[ $current_panes -eq $((max_win_panes)) ]]; then
        window_check
    elif [[ $current_panes -gt $((max_win_panes)) ]]; then
        window_check
    fi


    if [ -z $new_window ] && [ ! $first_post ]; then
        tmux split-window -t $session_name:$window_number.0 -h -l 2
        launch_all_zig
    fi

    while [ $? -eq 1 ]; do
        if $this_tmux_window; then 
            break
        fi
        window_number=$((window_number+1))
        tmux new-window -t $session_name:$window_number
        launch_all_zig
        current_panes=0
    done
   
    let  current_panes++
    unset new_window first_post
done

set_layout "tiled"
tmux set-window-option -t :$window_number  synchronize-panes on >/dev/null 2>&1
tmux attach -d -t $session_name
