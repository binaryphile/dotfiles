gdb <<END &>/dev/null
attach $$
call (void *) unbind_variable("TMOUT")
detach
quit
END
