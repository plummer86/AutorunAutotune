#!/bin/bash

API_SECRET=`echo -n ${API_SECRET}|sha1sum|cut -f1 -d '-'|cut -f1 -d ' '`
# If a token is set pass it directly, no hash required.
# https://openaps.readthedocs.io/en/latest/docs/While%20You%20Wait%20For%20Gear/nightscout-setup.html?highlight=API_SECRET#switching-from-api-secret-to-token-based-authentication-for-your-rig
if [[ -n "${API_TOKEN}" ]]; then
   API_SECRET="$API_TOKEN"
fi

echo "Connecting to: $NIGHTSCOUT_HOST"

if [ -e $SETTINGS_DIRECTORY/profile.json ]
   then
     echo "Found existing profile.json"
   else
     echo "Getting profile: $PROFILE"
     python3 get_profile.py --nightscout "$NIGHTSCOUT_HOST" --token "$API_SECRET" write --directory "$SETTINGS_DIRECTORY" --name "$PROFILE"

     if [ $? -eq 0 ]
     then
       echo "Successfully retrived profile from nightscout"
     else
       echo "ERROR: Failed to get profile from nightscout" 1>&2
       exit 1
     fi
fi

echo "Running autotune"

echo oref0-autotune --dir=/usr/src/autot/myopenaps --ns-host=$NIGHTSCOUT_HOST --start-days-ago=$DAYS --categorize-uam-as-basal=$UAM_BASAL --tune-insulin-curve=$TUNE
oref0-autotune --dir=/usr/src/autot/myopenaps --ns-host=$NIGHTSCOUT_HOST --start-days-ago=$DAYS --categorize-uam-as-basal=$UAM_BASAL --tune-insulin-curve=$TUNE
if [ $? -eq 0 ]
then
  echo "Autotune successful"
  if [ "$TUNE" == "false" ]
  then
    echo "Skipping profile update"
    exit 0
  fi
else
  echo "ERROR: Autotune failed!" 1>&2
  exit 1 
fi

echo "Uploading profile:" $(pwd)/myopenaps/autotune/profile.json
oref0-upload-profile ./myopenaps/autotune/profile.json $NIGHTSCOUT_HOST $API_SECRET
if [ $? -eq 0 ]
then
  echo "Upload successful"
else
  echo "ERROR: upload failed!" 1>&2
  exit 1 
fi

echo "triggering updated profile"
python3 profile_trigger.py --site=$NIGHTSCOUT_HOST --api_key=$API_SECRET
if [ $? -eq 0 ]
then
  echo "trigger successful"
else
  echo "ERROR: trigger failed!" 1>&2
  exit 1 
fi
