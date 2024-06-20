#!/usr/bin/env bash

[[ "$DEBUG" -eq 1 ]] && set -x

## Set Timezone
if [[ -n "$TZ" ]]; then
  [[ -w /etc/timezone  ]] && echo "${TZ}" > /etc/timezone
  [[ -w /etc/localtime ]] && ln -svf "/usr/share/zoneinfo/${TZ}" /etc/localtime
fi

## Vanilla or Extended
if [[ $RUN_VANILLA -eq 1 ]]; then

  unset CATALINA_BASE
  echo "--  INFO: running vanilla Tomcat"

else

  ## Run.d scripts path
  scripts_run_d='/run.d'

  ## Post-depolyment scripts path
  post_deployment_prefix=''
  [[ -n "$CATALINA_HOME" ]] && post_deployment_prefix="$CATALINA_HOME"
  [[ -n "$CATALINA_BASE" ]] && post_deployment_prefix="$CATALINA_BASE"
  scripts_post_deployment="${post_deployment_prefix}/post_deployment/scripts"

  ## Define all scripts to run
  scripts_all=(
    "$scripts_run_d"
  )
  [[ $RUN_POSTDEPLOYMENT -eq 1 ]] && scripts_all+=( "$scripts_post_deployment" )

  ## Iterate through all scripts
  for scripts_dir in "${scripts_all[@]}"; do
    if [[ -d "$scripts_dir" ]]; then
      echo "--  INFO: processing scripts in ${scripts_dir}"
      for script in "$scripts_dir"/*.sh; do
        if [[ -f "$script" ]]; then
          bash "$script"
          exit_status=$?
          if [[ $exit_status -ne 0 ]]; then
            echo "-- ERROR: ${script} exited with non-zero status (${exit_status}); aborting!" >&2
            exit $exit_status
          fi
        fi
      done
    fi
  done

fi

#######################################
## Launch Tomcat Catalina
#######################################

exec "$@"