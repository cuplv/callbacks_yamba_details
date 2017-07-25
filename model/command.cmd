
set on_failure_script_quits "1"
set default_trace_plugin 4
set traces_show_defines "0"
set traces_show_defines_with_next "0"
read_model
flatten_hierarchy
encode_variables -n
build_boolean_model
echo "Verifying property..."
check_invar_ic3 -n 0 -k 40 -g
echo "SUCCESS"
quit
EOF
        