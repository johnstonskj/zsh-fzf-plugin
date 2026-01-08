# -*- mode: sh; eval: (sh-set-shell "zsh") -*-
#
# Plugin Name: fzf
# Description: Zsh plugin to integrate the fzf tool into Zsh.
# Repository: https://github.com/johnstonskj/zsh-fzf-plugin
#
# Public variables:
#
# * `FZF`; plugin-defined global associative array with the following keys:
#   * `_ALIASES`; a list of all aliases defined by the plugin.
#   * `_FUNCTIONS`; a list of all functions defined by the plugin.
#   * `_PLUGIN_DIR`; the directory the plugin is sourced from.
#   * `_OLD_DEFAULT_COMMAND`; the previous value of FZF_DEFAULT_COMMAND.
#   * `_OLD_CTRL_T_COMMAND`; the previous value of FZF_CTRL_T_COMMAND.
#   * `_OLD_ALT_C_COMMAND`; the previous value of FZF_ALT_C_COMMAND.
# * `FZF_DEFAULT_COMMAND`;
# * `FZF_CTRL_T_COMMAND`; 
# * `FZF_ALT_C_COMMAND`;
#

############################################################################
# Standard Setup Behavior
############################################################################

# See https://wiki.zshell.dev/community/zsh_plugin_standard#zero-handling
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

# See https://wiki.zshell.dev/community/zsh_plugin_standard#standard-plugins-hash
declare -gA FZF
FZF[_PLUGIN_DIR]="${0:h}"
FZF[_ALIASES]=""
FZF[_FUNCTIONS]=""

# Saving the current state for any modified global environment variables.
FZF[_OLD_DEFAULT_COMMAND]="${FZF_DEFAULT_COMMAND}"
FZF[_OLD_CTRL_T_COMMAND]="${FZF_CTRL_T_COMMAND}"
FZF[_OLD_ALT_C_COMMAND]="${FZF_ALT_C_COMMAND}"

############################################################################
# Internal Support Functions
############################################################################

#
# This function will add to the `FZF[_FUNCTIONS]` list which is
# used at unload time to `unfunction` plugin-defined functions.
#
# See https://wiki.zshell.dev/community/zsh_plugin_standard#unload-function
# See https://wiki.zshell.dev/community/zsh_plugin_standard#the-proposed-function-name-prefixes
#
.fzf_remember_fn() {
    builtin emulate -L zsh

    local fn_name="${1}"
    if [[ -z "${FZF[_FUNCTIONS]}" ]]; then
        FZF[_FUNCTIONS]="${fn_name}"
    elif [[ ",${FZF[_FUNCTIONS]}," != *",${fn_name},"* ]]; then
        FZF[_FUNCTIONS]="${FZF[_FUNCTIONS]},${fn_name}"
    fi
}
.fzf_remember_fn .fzf_remember_fn

.fzf_define_alias() {
    local alias_name="${1}"
    local alias_value="${2}"

    alias ${alias_name}=${alias_value}

    if [[ -z "${FZF[_ALIASES]}" ]]; then
        FZF[_ALIASES]="${alias_name}"
    elif [[ ",${FZF[_ALIASES]}," != *",${alias_name},"* ]]; then
        FZF[_ALIASES]="${FZF[_ALIASES]},${alias_name}"
    fi
}
.fzf_remember_fn .fzf_remember_alias

#
# This function does the initialization of variables in the global variable
# `FZF`. It also adds to `path` and `fpath` as necessary.
#
fzf_plugin_init() {
    builtin emulate -L zsh
    builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd

    # Use fd (https://github.com/sharkdp/fd).
    export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

    # Use fd for listing path candidates.
    # - The first argument to the function ($1) is the base path to start traversal
    # - See the source code (completion.{bash,zsh}) for the details.
    _fzf_compgen_path() {
        fd --hidden --exclude .git . "$1"
    }

    # Use fd to generate the list for directory completion
    _fzf_compgen_dir() {
        fd --type=d --hidden --exclude .git . "$1"
    }

    local show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

    export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
    export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

    # Advanced customization of fzf options via _fzf_comprun function
    # - The first argument to the function is the name of the command.
    # - You should make sure to pass the rest of the arguments to fzf.
    _fzf_comprun() {
        local command=$1
        shift

        case "$command" in
            cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
            export|unset) fzf --preview "eval 'echo \${}'"         "$@" ;;
            ssh)          fzf --preview 'dig {}'                   "$@" ;;
            *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
        esac
    }
}
.fzf_remember_fn fzf_plugin_init

############################################################################
# Plugin Unload Function
############################################################################

# See https://wiki.zshell.dev/community/zsh_plugin_standard#unload-function
fzf_plugin_unload() {
    builtin emulate -L zsh

    # Remove all remembered functions.
    local plugin_fns
    IFS=',' read -r -A plugin_fns <<< "${FZF[_FUNCTIONS]}"
    local fn
    for fn in ${plugin_fns[@]}; do
        whence -w "${fn}" &> /dev/null && unfunction "${fn}"
    done
    
    # Remove all remembered aliases.
    local aliases
    IFS=',' read -r -A aliases <<< "${FZF[_ALIASES]}"
    local alias
    for alias in ${aliases[@]}; do
        unalias "${alias}"
    done
    
    # Remove the global data variable.
    unset FZF

    # Reset global environment variables .
    FZF_DEFAULT_COMMAND="${FZF[_OLD_DEFAULT_COMMAND]}"
    FZF_ALT_C_COMMAND="${FZF[_OLD_ALT_C_COMMAND]}"
    FZF_CTRL_T_COMMAND="${FZF[_OLD_CTRL_T_COMMAND]}"

    # Remove this function.
    unfunction fzf_plugin_unload
}

############################################################################
# Initialize Plugin
############################################################################

fzf_plugin_init

if [[ ! -f "$(xdg_config_for fzf)/fzf-git.sh/fzf-git.sh" ]]; then
    git submodule init
    git submodule update
else
    source "$(xdg_config_for fzf)/fzf-git.sh/fzf-git.sh"
fi

true
