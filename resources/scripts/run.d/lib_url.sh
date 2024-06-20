#!/usr/bin/env bash

[[ "$DEBUG" -eq 1 ]] && set -x

#######################################
fatal_error() {
#######################################

  echo "-- ERROR: $( basename "$0" ): $*" >&2
  exit 2
}

#######################################
info() {
#######################################

  local prefix; prefix="--  INFO: $( basename "$0" )"

  if [ "$#" -eq 0 ]; then
    # Read from standard input if no arguments are provided
    while IFS= read -r line; do echo "${prefix}: ${line}"; done
  else
    # Print the provided arguments
    echo "${prefix}: $*"
  fi
}

#######################################
getFileFromURL() {
#######################################

  [[ -z $1 ]] && fatal_error "[${FUNCNAME[0]}] missing URL file parameter; aborting!"
  [[ -z $2 ]] && fatal_error "[${FUNCNAME[0]}] missing OUTPUT file parameter; aborting!"

  local curl_exit_status lowercase_url output remote_opts url

  url="$1"
  output="$2"
  remote_opts=()

  [[ -n "$CONNECT_TIMEOUT" ]] && remote_opts+=( '--connect-timeout' "$CONNECT_TIMEOUT" )
  [[ -n "$PROXY" ]] && remote_opts+=( '--proxy' "$PROXY" )

  lowercase_url="$( echo "$url" | tr '[:upper:]' '[:lower:]' )"

  case "$lowercase_url" in
    file://* )
      curl -sL -o "$output" "$url"
      curl_exit_status=$?
      ;;
    http://* | https://* )
      curl "${remote_opts[@]}" -sL -o "$output" "$url"
      curl_exit_status=$?
      ;;
    s3://* )
      local authorization date path signature string_to_sign; 
      date="$( date -R --utc )"
      path="${url:5}"
      printf -v string_to_sign "%s\n\n\n%s\n%s" "GET" "$date" "/$path"
      signature=$( echo -n "$string_to_sign" | openssl sha1 -binary -hmac "$S3_SK" | openssl base64 )
      authorization="AWS ${S3_AK}:${signature}"
      curl "${remote_opts[@]}" -sL -o "$output" -H "Date: ${date}" -H "Authorization: ${authorization}" "$S3_URL/${path}"
      curl_exit_status=$?
      ;;
    *)
      fatal_error "[${FUNCNAME[0]}] unknown URL scheme in $url; aborting!"
      ;;
  esac

  [[ curl_exit_status -ne 0 ]] && fatal_error "[${FUNCNAME[0]}] failed to reach $url; aborting!"
}

#######################################
isWARfile() {
#######################################
    
    [[ -z $1 ]] && fatal_error "[${FUNCNAME[0]}] missing file parameter; aborting!"

    local war_file; war_file="$1"

    case "$( file -bi "$war_file" 2>/dev/null | cut -d';' -f1 )" in
      application/java-archive )
        return 0
        ;;
      application/zip )
        ## Extract ZIP archive
        unzip -l "$war_file" | awk '{print $NF}' | grep -qE '^WEB-INF/';
        return $?
        ;;
      *)
        return 1
        ;;
    esac
}

#######################################
## Check Dependencies
#######################################

if [[ -z "$CATALINA_BASE" ]]; then
  fatal_error "CATALINA_BASE is empty or not defined; aborting!"
else
  info "CATALINA_BASE=${CATALINA_BASE}"
  if ! mkdir -p "$CATALINA_BASE" 2>/dev/null; then
    fatal_error "cannot create ${CATALINA_BASE}; aborting!"
  fi
fi

is_s3=0

if [[ -z "$BASE_URL" ]]; then
  fatal_error "BASE_URL is empty or not defined; aborting!"
else
  grep -q '^[sS]3://' <<< "$BASE_URL" && is_s3=1
fi

if [[ "$( env | grep -E '^WAR(_[0-9]+)?_URL=' | wc -w )" -eq 0 ]]; then
  fatal_error "WAR_URL is empty or not defined; aborting!"
else
  env | grep -qE '^WAR(_[0-9]+)?_URL=[sS]3://' && is_s3=1
fi

## Check for S3_* settings if s3:// resource
if [[ $is_s3 -eq 1 ]]; then
  if [[ -z "$S3_URL" ]]; then
    fatal_error "S3_URL is empty or not defined; aborting!"
  fi

  if [[ -z "$S3_AK" ]]; then
    fatal_error "S3_AK is empty or not defined; aborting!"
  fi

  if [[ -z "$S3_SK" ]]; then
    fatal_error "S3_SK is empty or not defined; aborting!"
  fi
fi

#######################################
## Download and Deploy Resources
#######################################

## Create download directory
download_dir='/app/.download'
mkdir -p "$download_dir"

## Create temporary CATALINA_BASE folder structure
tmp_base='/app/.catalina_base'
mkdir -p "$tmp_base"/{bin,conf,lib,logs,temp,webapps,work}

[[ -n "$PROXY" ]] && info "using PROXY ${PROXY} for remote connections"

## Download CATALINA_BASE archive
info "downloading ${BASE_URL}"
base_filename=$( basename "$BASE_URL" )
base_filepath="${download_dir}/${base_filename}"
getFileFromURL "$BASE_URL" "$base_filepath"

## Validate CATALINA_BASE archive
archive_content_list=''
extract_exit_status=0

case "$( file -bi "$base_filepath" 2>/dev/null | cut -d';' -f1 )" in
  application/gzip )
    ## Extract TGZ archive
    tar xzf "$base_filepath" -C "$tmp_base" 1>/dev/null 2>&1
    extract_exit_status=$?
    archive_content_list="$( tar -tf "$base_filepath" 2>/dev/null )"
    ;;
  application/zip )
    ## Extract ZIP archive
    unzip -oqq "$base_filepath" -d "$tmp_base" 1>/dev/null 2>&1
    extract_exit_status=$?
    archive_content_list="$( unzip -Z1 "$base_filepath" 2>/dev/null )"
    ;;
  *)
    fatal_error "${base_filename} doesn't exist or unknown archive format; aborting!"
    ;;
esac

if [[ $extract_exit_status -eq 0 ]]; then
  ## List content of archive
  awk -v prefix="${base_filename}: " '{print prefix $0}' <<< "$archive_content_list" | info
else
  fatal_error "failed extracting ${base_filename} file; aborting!"
fi

## Dockerize CATALINA_BASE files
if [[ "$RUN_DOCKERIZE" -eq 1 ]]; then
  while IFS= read -r -d '' tmpl_file; do
    config_file="$( dirname -- "$tmpl_file" )/$( basename -- "$tmpl_file" .tmpl )"
    info "dockerizing: ${tmpl_file} => ${config_file}"
    dockerize -template "$tmpl_file":"$config_file" && rm -f "$tmpl_file"
  done < <( find "$tmp_base" -type f -name '*.tmpl' -not -path '*/\.git/*' -print0 )
fi

## Deploy CATALINA_BASE files
if cp -rf "${tmp_base}"/* "${CATALINA_BASE}/" 2>/dev/null; then
  info "${base_filename} deployed to ${CATALINA_BASE}"
  rm -rf "$tmp_base"
  rm -f "$base_filepath"
else
  fatal_error "${base_filename} deployment to ${CATALINA_BASE} failed; aborting!"
fi

## Download and Deploy WAR file(s)
for war in $( env | grep -E '^WAR(_[0-9]+)?_URL=' | sort -n ); do

  ## Read variable names
  war_url_name=${war%%=*}
  war_number=$( echo "$war_url_name" | grep -oE '[0-9]+' )
  [[ -z "$war_number" ]] && war_name_name='WAR_NAME' || war_name_name="WAR_${war_number}_NAME"

  ## Extract values from variable names
  war_url="${!war_url_name}"
  war_name="${!war_name_name}"

  [[ -z "$war_url" ]] && fatal_error "${war_url_name} is defined but empty; aborting!"

  ## Set WAR output file name
  [[ -n "$war_name" ]] && war_filename="$war_name" || war_filename="$( basename "$war_url" )"
  [[ "$war_filename" != *.war ]] && war_filename="${war_filename}.war"
  war_filepath="${download_dir}/${war_filename}"

  ## Download WAR file
  info "downloading ${war_url} as ${war_filename}"
  getFileFromURL "$war_url" "$war_filepath"
  
  ## Verify whether WAR file
  if ! isWARfile "$war_filepath"; then
    fatal_error "${war_filename} doesn't exist or not a WAR file; aborting!"
  fi
  
  ## Deploy WAR file to webapps folder
  if mv -f "$war_filepath" "${CATALINA_BASE}/webapps/" 2>/dev/null; then
    info "${war_filename} deployed to ${CATALINA_BASE}/webapps/"
  else
    fatal_error "${war_filename} deployment to ${CATALINA_BASE}/webapps/ failed; aborting!"
  fi
done