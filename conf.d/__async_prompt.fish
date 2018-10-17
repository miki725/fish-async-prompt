status is-interactive
and begin
    function __async_prompt_setup_on_startup --on-event fish_prompt
        functions -e (status current-function)

        __async_prompt_setup
    end

    function __async_prompt_setup
        set -q async_prompt_functions
        and set -g __async_prompt_functions_internal $async_prompt_functions

        for func in (__async_prompt_config_functions)
            functions -q '__async_prompt_'$func'_orig'
            or functions -c $func '__async_prompt_'$func'_orig'

            function $func -V func
                eval 'echo $__async_prompt_'$func'_text'
            end
        end
    end

    function __async_prompt_reset --on-variable async_prompt_functions
        # Revert functions
        for func in (__async_prompt_config_functions)
            functions -q '__async_prompt_'$func'_orig'
            and begin
                functions -e $func

                # If the function is defined redaundantly, cannot override it by
                # `functions -c` so done it by create wrapper function.
                function $func -V func
                    eval '__async_prompt_'$func'_orig' $argv
                end
            end
        end

        __async_prompt_setup
    end

    function __async_prompt_sync_val --on-signal WINCH
        for func in (__async_prompt_config_functions)
            __async_prompt_var_move '__async_prompt_'$func'_text' '__async_prompt_'$func'_text_'(echo %self)
        end
    end

    function __async_prompt_var_move
        set -l dst $argv[1]
        set -l orig $argv[2]

        if set -q $orig
            set -g $dst $$orig
            set -e $orig
        end
    end

    function __async_prompt_fire --on-event fish_prompt
        set st $status

        for func in (__async_prompt_config_functions)
            __async_prompt_config_inherit_variables | __async_prompt_spawn $st 'set -U __async_prompt_'$func'_text_'(echo %self)' ('$func')'
            function '__async_prompt_'$func'_handler' --on-process-exit (jobs -lp | tail -n1)
                kill -WINCH %self
            end
        end
    end

    function __async_prompt_spawn
        begin
            set st $argv[1]
            while read line
                contains $line FISH_VERSION PWD SHLVL _ history
                and continue

                if test "$line" = status
                    echo status $st
                else
                    or echo $line (string escape -- $$line)
                end
            end
        end | fish -c 'function __async_prompt_ses
            return $argv
        end
        while read -a line
            test -z "$line"
            and continue

            if test "$line[1]" = status
                set st $line[2]
            else
                eval set "$line"
            end
        end

        not set -q st
        and true
        or __async_prompt_ses $st
        '$argv[2] &
    end

    function __async_prompt_config_inherit_variables
        if set -q async_prompt_inherit_variables
            if test "$async_prompt_inherit_variables" = all
                set -ng
            else
                for item in $async_prompt_inherit_variables
                    echo $item
                end
            end
        else
            echo status
        end
    end

    function __async_prompt_config_functions
        if set -q __async_prompt_functions_internal
            for func in $__async_prompt_functions_internal
                functions -q "$func"
                or continue

                echo $func
            end
        else
            echo fish_prompt
            echo fish_right_prompt
        end
    end
end
