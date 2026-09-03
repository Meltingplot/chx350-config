if(global.door_left_open == false && global.door_right_open == false && global.door_right_switch_checked == true && global.door_right_switch_checked == true)
  M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/automatic.g"
else
  M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/default.g"