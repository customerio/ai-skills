#!/usr/bin/env bash
# Print GCE deploy candidates and default bulk-deploy groups from local source.

set -euo pipefail

repo=""
deploy_root="$HOME/code/deploy"
names_only=false

usage() {
  echo "Usage: $0 --repo <services|edge> [--deploy-root <path>] [--names-only]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --deploy-root)
      deploy_root="${2:-}"
      shift 2
      ;;
    --names-only)
      names_only=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

case "$repo" in
  services)
    source_path="$deploy_root/cmds/deploy/deploy.go"
    groups=("core:services" "extra:extraServices" "rare:rareServices" "queue:allQueues")
    ;;
  edge)
    source_path="$deploy_root/cmds/deploy-edge/deploy-edge.go"
    groups=("core:services" "extra:extraServices")
    ;;
  *)
    usage
    exit 2
    ;;
esac

[[ -f "$source_path" ]] || {
  echo "could not read $source_path" >&2
  exit 1
}

read_slice() {
  local slice_name="$1"
  awk -v name="$slice_name" '
    $0 ~ "^[[:space:]]*" name "[[:space:]]*=[[:space:]]*\\[\\]string\\{" { in_slice = 1; next }
    in_slice && /^[[:space:]]*}/ { exit }
    in_slice {
      sub(/[[:space:]]*\/\/.*/, "", $0)
      while (match($0, /"[^"]+"/)) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        $0 = substr($0, RSTART + RLENGTH)
      }
    }
  ' "$source_path"
}

read_custom_playbooks() {
  awk '
    /^func hasCustomPlaybook\(/ { in_function = 1 }
    in_function && /^[[:space:]]*default:/ { exit }
    in_function {
      while (match($0, /"[^"]+"/)) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        $0 = substr($0, RSTART + RLENGTH)
      }
    }
  ' "$source_path"
}

configured_services() {
  local template_dir="$deploy_root/gce/roles/load_service/templates"
  [[ -d "$template_dir" ]] || {
    echo "could not read $template_dir" >&2
    return 1
  }

  find "$template_dir" -maxdepth 1 -type f -name '*.json.j2' -exec basename {} .json.j2 \; | sort
}

join_csv() {
  paste -sd, -
}

declare -a labels values
for group in "${groups[@]}"; do
  label="${group%%:*}"
  slice_name="${group#*:}"
  slice_values="$(read_slice "$slice_name")"
  [[ -n "$slice_values" ]] || {
    echo "could not find Go string slice '$slice_name' in $source_path" >&2
    exit 1
  }
  labels+=("$label")
  values+=("$slice_values")
done

if [[ "$repo" == "services" ]]; then
  configured="$(configured_services)"
  custom_playbook="$(read_custom_playbooks)"
  [[ -n "$custom_playbook" ]] || {
    echo "could not find hasCustomPlaybook switch in $source_path" >&2
    exit 1
  }
  individual_candidate="$(printf '%s\n%s\n' "$configured" "$custom_playbook" | sort -u)"

  if [[ "$names_only" == true ]]; then
    printf '%s\n' "$individual_candidate" | join_csv
    exit 0
  fi

  labels+=("configured" "custom-playbook" "individual-candidate")
  values+=("$configured" "$custom_playbook" "$individual_candidate")
elif [[ "$names_only" == true ]]; then
  printf '%s\n' "${values[@]}" | join_csv
  exit 0
fi

echo "source: $source_path"
for index in "${!labels[@]}"; do
  count="$(printf '%s\n' "${values[index]}" | sed '/^$/d' | wc -l | tr -d ' ')"
  echo "${labels[index]} ($count):"
  printf '%s\n' "${values[index]}" | sed '/^$/d' | sed 's/^/  /'
done

if [[ "$repo" == "services" ]]; then
  echo "note: individual-candidate lists services with deploy configuration; confirm the matching services-repo build target before recommending a PR deploy."
else
  total="$(printf '%s\n' "${values[@]}" | sed '/^$/d' | wc -l | tr -d ' ')"
  echo "total: $total"
fi
