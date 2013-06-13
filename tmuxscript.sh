#!/bin/bash

## Things you can change. 
#debug=true
session_name="rax"
max_win_panes="8"
window_number="0"
script_command="cd /tmp/tmux-test; touch"

## Do not edit below this line.
current_panes="1"
declare -A layout_array=(['4x4']='4492,96x11,0,0[96x2,0,0{48x2,0,0,17,47x2,49,0,24},96x2,0,3{48x2,0,3,18,47x2,49,3,23},96x2,0,6{48x2,0,6,19,47x2,49,6,22},96x2,0,9{48x2,0,9,20,47x2,49,9,21}]' )

function window_check(){
        if [ $debug ]; then
           echo "Current Panes ($current_panes) is equal to Max Window Panes ($max_win_panes)! Time for a new window!"
        fi
        
        set_layout
        tmux set-window-option -t :$window_number synchronize-panes on
 
        export window_number=$((window_number+1))
        tmux new-window -t $session_name:$window_number
        export current_panes=1
        export new_window=true 

        tmux select-window -t $session_name:$window_number
        launch_all_zig

        if [ $debug ]; then        
           echo "window_number => $window_number"
           echo "current_panes => $current_panes"
        fi
}

function launch_all_zig(){
    if [ "$1" == "first" ]; then
        tmux send-keys -t $session_name:0.0 "$script_command ${raxinfo[$i]}" C-m
    else
        tmux send-keys "$script_command ${raxinfo[$i]}" C-m
    fi
}

function set_layout(){

    if [ "$1" == "tiled" ]; then
        layout_setup="tiled"
    else
        case $max_win_panes in 
            8) layout_setup=${layout_array[4x4]} ;;
        esac
    fi
    
    tmux select-layout -t $session_name:$window_number $layout_setup >/dev/null 2>&1
}

function usage(){
    echo "Usage:"
    echo
    echo "$0 [-l External List] [-s External Script]"
    echo 
    echo "If no options are passed, $0 will look for 'list' within the current directory, and will execute as"
    echo "defined in the \$script_command variable at the top of the script."
    echo
    echo "Each value in 'list' (or what is provided with the -l option) will be the last argument for what is defined as \$script command"
    echo "Ex: ping 1.2.3.4, where ping is the \$script_command variable and '1.2.3.4' is a value within 'list'"
    echo
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

OPTERR=0
while getopts "s:l:"  OPTION; do 
    case "$OPTION" in
        s) external_script="${OPTARG}";;
        l) external_list="${OPTARG}"; total_panes=${#raxinfo[@]};;
        ?) usage;; 
    esac
done


if [ -n "$external_list" ]; then 
    if [ -e "$external_list" ]; then  
        raxinfo=($(cat $external_list)); 
    else 
        echo "$external_list doesn't exist!"
        exit 1
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

tmux has-session -t $session_name >/dev/null 2>&1

# If the tmux session named $session_name doesn't exist...
if [ $? -eq 1 ]; then 
    tmux new-session -s rax -d 
fi

if [ $debug ]; then 
    echo "window_number => $window_number"
    echo "current_panes => $current_panes"
fi

total_panes=${#raxinfo[@]}
for i in $(seq 1 $((total_panes -1))); do
    if [[ $current_panes -eq 1 ]]; then
        launch_all_zig "first"
    fi
    

    if [[ $window_number -eq 0 ]] && [[ $current_panes -eq $((max_win_panes)) ]]; then
        window_check
    elif [[ $current_panes -gt $((max_win_panes)) ]]; then
        window_check
    fi


    if [ -z $new_window ]; then
        tmux split-window -t $session_name:$window_number.0 -h -l 2
        launch_all_zig
    fi

    while [ $? -eq 1 ]; do
        window_number=$((window_number+1))
        tmux new-window -t $session_name:$window_number
        launch_all_zig
        current_panes=0
    done
   
    if [ $debug ]; then 
        echo -e "i => $i\t$window_number.$current_panes"
    fi

    let  current_panes++
    unset new_window
done

set_layout
tmux set-window-option -t :$window_number  synchronize-panes on >/dev/null 2>&1
tmux attach -d -t $session_name
