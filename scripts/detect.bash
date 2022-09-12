[[ $- == *i* ]] && echo interactive || echo non-interactive
[[ $(shopt login_shell) == *on ]] && echo login || echo non-login
Detected=1
