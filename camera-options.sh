declare -A camera_options=(
            [power_line_frequency]=1 # 50Hz
                      [focus_auto]=0 # Off
                   [exposure_auto]=3 # Aperture Priority Mode
          [exposure_auto_priority]=0 # Off
  [white_balance_temperature_auto]=0 # Off
)

for k in "${!camera_options[@]}"
do
  declare v="${camera_options[$k]}"

  echo "$camera : setting $k to $v"

  if v4l2-ctl -d "$camera" -C "$k" --silent
  then v4l2-ctl -d "$camera" -c "$k=$v" --silent
  else echo "Camera doesn't have option: $k" >&2
  fi
done
