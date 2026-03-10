# -*- mode: sh; eval: (sh-set-shell "zsh") -*-
#
# @name: fzf
# @brief: Integrate the fzf tool into Zsh.
# @repository: https://github.com/johnstonskj/zsh-fzf-plugin
# @version: 0.1.1
# @license: MIT AND Apache-2.0
#
# ### Public variables
#
# * `FZF_DEFAULT_COMMAND`;
# * `FZF_CTRL_T_COMMAND`; 
# * `FZF_ALT_C_COMMAND`;
#

############################################################################
# @section Lifecycle
# @description Plugin lifecycle functions.
#

#
# This function does the initialization of variables in the global variable
# `FZF`. It also adds to `path` and `fpath` as necessary.
#
fzf_plugin_init() {
    builtin emulate -L zsh

    # Use fd (https://github.com/sharkdp/fd).
    @zplugins_envvar_save fzf FZF_DEFAULT_COMMAND
    export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"

    @zplugins_envvar_save fzf FZF_CTRL_T_COMMAND
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

    @zplugins_envvar_save fzf FZF_ALT_C_COMMAND
    export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

    # Use fd for listing path candidates.
    # - The first argument to the function ($1) is the base path to start traversal
    # - See the source code (completion.{bash,zsh}) for the details.
    _fzf_compgen_path() {
        fd --hidden --exclude .git . "$1"
    }
    @zplugins_remember_fn fzf _fzf_compgen_path

    # Use fd to generate the list for directory completion
    _fzf_compgen_dir() {
        fd --type=d --hidden --exclude .git . "$1"
    }
    @zplugins_remember_fn fzf _fzf_compgen_dir

    local show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

    @zplugins_envvar_save fzf FZF_CTRL_T_OPTS
    export FZF_CTRL_T_OPTS="--preview '${show_file_or_dir_preview}'"

    @zplugins_envvar_save fzf FZF_ALT_C_OPTS
    export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

    # Advanced customization of fzf options via _fzf_comprun function
    # - The first argument to the function is the name of the command.
    # - You should make sure to pass the rest of the arguments to fzf.
    _fzf_comprun() {
        local command=$1
        shift

        case "$command" in
            cd)           fzf --preview 'eza --tree --color=always    {} | head -200' "$@" ;;
            export|unset) fzf --preview "eval 'echo \${}'"            "$@" ;;
            ssh)          fzf --preview 'dig {}'                      "$@" ;;
            *)            fzf --preview "${show_file_or_dir_preview}" "$@" ;;
        esac
    }
    @zplugins_remember_fn fzf _fzf_comprun
}

# @internal
fzf_plugin_unload() {
    builtin emulate -L zsh

    @zplugins_envvar_restore fzf FZF_DEFAULT_COMMAND
    @zplugins_envvar_restore fzf FZF_CTRL_T_COMMAND
    @zplugins_envvar_restore fzf FZF_ALT_C_COMMAND
    @zplugins_envvar_restore fzf FZF_CTRL_T_OPTS
    @zplugins_envvar_restore fzf FZF_ALT_C_OPTS
}

# Do this during load time.

if [[ ! -f "$(xdg_config_for fzf)/fzf-git.sh/fzf-git.sh" ]]; then
    git submodule init
    git submodule update
    source "$(xdg_config_for fzf)/fzf-git.sh/fzf-git.sh"
else
    source "$(xdg_config_for fzf)/fzf-git.sh/fzf-git.sh"
fi
