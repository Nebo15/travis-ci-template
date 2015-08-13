#!/bin/bash
# Defaults
BASE_DIR=$(pwd)
SCRIPTS_DIR="${BASE_DIR}/.travis/scripts"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
APPLICATION='MBank'
DEFAULT_DISTRIBUTION='development'
BUILD_NUMBER=${TRAVIS_JOB_NUMBER:-0}
DEFAULT_CONFIGURATION='Debug'

# Getting options
usage() {
    echo -e "Usage: setenv.sh [-a application] [-d distribution] [-e environment]
      [-a AppName]                         - Application target name. Currently available: MBank for Best Wallet, BankVRN for Voronezh Wallet. Default: 'MBank'.
      [-d appstore|enterprise|development] - Distribution type:
                                             * 'appstore' - to upload new version to the AppStore;
                                             * 'enterprise' - to upload new version to build storage;
                                             * 'development' - to use in iPhone simulator/developer device.
                                             Default: 'development'.
      [-e master|stage|develop]            - Environment. Default is current branch name in Git." 1>&2;
    exit 1;
}

while getopts ":a:d:e:h" o; do
    case "${o}" in
        a)
            APPLICATION=${OPTARG}
            echo "[I] Options: APPLICATION='${APPLICATION}'"
            ;;
        d)
            DISTRIBUTION=${OPTARG}
            echo "[I] Options: DISTRIBUTION='${DISTRIBUTION}'"
            ;;
        e)
            BRANCH=${OPTARG}
            echo "[I] Options: BRANCH='${BRANCH}'"
            ;;
        h)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# Helper functions
containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 1; done
  return 0
}

# Get environment name
case "${BRANCH}" in
    "master" | "stage")
        ENVIRONMENT=$BRANCH
    ;;
    *)
        ENVIRONMENT="default"
    ;;
esac

# Filtering distribution types
case "${DISTRIBUTION}" in
    "appstore")
        DISTRIBUTION="appstore"
        CONFIGURATION='Release'
        ENVIRONMENT="master"
    ;;
    "enterprise")
        DISTRIBUTION="enterprise"
        CONFIGURATION='Release'
    ;;
    *)
        CONFIGURATION=$DEFAULT_CONFIGURATION
        DISTRIBUTION=$DEFAULT_DISTRIBUTION
    ;;
esac

echo "[I] Distribution method is set to '${DISTRIBUTION}'."
echo "[I] Current branch '${BRANCH}' is mapped to '${ENVIRONMENT}' environment for '${APPLICATION}' application."

APPLICATION_SETTING_PLIST="${BASE_DIR}/.travis/distributions/${DISTRIBUTION}/${APPLICATION}/app.plist"
if [[ ! -f "${APPLICATION_SETTING_PLIST}" ]]
then
    echo "[E] Can't find appplication settings file '${APPLICATION_SETTING_PLIST}'"
    exit 1
fi

TARGETS_SETTING_DIR="${BASE_DIR}/.travis/distributions/${DISTRIBUTION}/${APPLICATION}/${ENVIRONMENT}/"
if [[ ! -d "${TARGETS_SETTING_DIR}" ]]
then
    echo "[E] Can't find environment settings directory: '${TARGETS_SETTING_DIR}'"
    echo "[E] Probably you are trying to build in environment that is not valid for current deployment!"
    exit 1
fi

# Getting global settings
DEVEOPMENT_TEAM=$(/usr/libexec/PlistBuddy -c "Print:DevelopmentTeam" "${APPLICATION_SETTING_PLIST}" 2> /dev/null)
if [[ $? != 0 ]]
then
    echo "[E] Can't get development team id from application configuration plist '${APPLICATION_SETTING_PLIST}'."
    exit 1
fi
WORKSPACE=$(/usr/libexec/PlistBuddy -c "Print:Workspace" "${APPLICATION_SETTING_PLIST}" 2> /dev/null)
if [[ $? != 0 ]]
then
    echo "[E] Can't get workspace name from application configuration plist '${APPLICATION_SETTING_PLIST}'."
    exit 1
fi
PROJECT=$(/usr/libexec/PlistBuddy -c "Print:Project" "${APPLICATION_SETTING_PLIST}" 2> /dev/null)
if [[ $? != 0 ]]
then
    echo "[E] Can't get project name from application configuration plist '${APPLICATION_SETTING_PLIST}'."
    exit 1
fi
PATH_PREFIX=$(/usr/libexec/PlistBuddy -c "Print:PathPrefix" "${APPLICATION_SETTING_PLIST}" 2> /dev/null)
if [[ $? != 0 ]]
then
    echo "[I] There are no path prefix. Default value is 'MBank'."
    PATH_PREFIX="MBank"
fi
echo "[I] Configuration '${CONFIGURATION}'."

# Getting static paths
RESOURCES_PATH="${PATH_PREFIX}/Resources"
LOCALIZAION_INFO_PLIST_FILES=$(find "${RESOURCES_PATH}/Localization" -type f -name "InfoPlist.strings")
echo " ~  Resetting display names from last git commit."
git checkout HEAD -- $LOCALIZAION_INFO_PLIST_FILES & wait

# Things that allow apps to work together
BUNDLE_IDS=()
GROUP_IDS=()
ENTITLEMENTS_PLIST_PATHS=()

# Settings that need to be extracted for future use
MAIN_PROVISIONING_PROFILE_NAME=""
MAIN_SERVER_ID=""
MAIN_BUNDLE_ID=""

# Configuring
echo "[I] Setting development team to '${DEVEOPMENT_TEAM}'."
${SCRIPTS_DIR}/xcode/set-team-settings.sh -p "${PROJECT}" -d "${DEVEOPMENT_TEAM}" >> /dev/null

for TARGET_SETTING_PLIST in `find ${TARGETS_SETTING_DIR} -type f -name "*.plist"`
do
    TMP=$(basename $TARGET_SETTING_PLIST)
    TARGET_NAME="${TMP%.*}"

    echo "[I] Changing settings for '${TARGET_NAME}' target of '${APPLICATION}' application."

    # Display name
    DISPLAY_NAME_SUFFIX=$(/usr/libexec/PlistBuddy -c "Print:DisplayNameSuffix" "${TARGET_SETTING_PLIST}" 2> /dev/null)
    if [[ $? == 0 ]]
    then
        echo " ~  Adding suffix '${DISPLAY_NAME_SUFFIX}' for Display Name."
        sed -i '' -e 's#\("CFBundleDisplayName"[^=]*=[^"]*\)"\([^"]*\)";#\1"\2 '$DISPLAY_NAME_SUFFIX'";#g' $LOCALIZAION_INFO_PLIST_FILES
    fi

    # Server ID
    SERVER_ID=$(/usr/libexec/PlistBuddy -c "Print:ServerID" "${TARGET_SETTING_PLIST}"  2> /dev/null)
    if [[ $? == 0 ]]
    then
        PREFIX_HEADERS_PATH=$(${SCRIPTS_DIR}/xcode/target-settings.sh -p "${PROJECT}" -t "${TARGET_NAME}" -c "${CONFIGURATION}" -k "GCC_PREFIX_HEADER")
        echo " ~  Setting Server ID to '${SERVER_ID}'"
        sed -i '' -e 's#kAPIServerName kAPIServerName.*#kAPIServerName kAPIServerName'${SERVER_ID}'#g' "${BASE_DIR}/${PREFIX_HEADERS_PATH}"
    fi

    # Save entitlement for later use
    ENTITLEMENTS_PLIST_PATHS+=($(${SCRIPTS_DIR}/xcode/target-settings.sh -p "${PROJECT}" -t "${TARGET_NAME}" -c "${CONFIGURATION}" -k "CODE_SIGN_ENTITLEMENTS"))

    # Hacking into plist path
    INFO_PLIST_PATH=$(${SCRIPTS_DIR}/xcode/target-settings.sh -p "${PROJECT}" -t "${TARGET_NAME}" -c "${CONFIGURATION}" -k "INFOPLIST_FILE")
    INFO_PLIST_PATH=${INFO_PLIST_PATH/'$(SRCROOT)'/${BASE_DIR}}

    # Set bundle id
    BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print:BundleID" "${TARGET_SETTING_PLIST}" 2> /dev/null)
    if [[ $? != 0 ]]
    then
        echo "[E] Can't get bundle id from target configuration plist '${TARGET_SETTING_PLIST}'."
        exit 1
    fi
    echo " ~  Setting Bundle ID to '${BUNDLE_ID}'"
    BUNDLE_IDS+=($BUNDLE_ID)
    /usr/libexec/PlistBuddy -c "Set:CFBundleIdentifier '${BUNDLE_ID}'" "${INFO_PLIST_PATH}"

    # Generating Application ID
    APP_ID="${DEVEOPMENT_TEAM}.${BUNDLE_ID}"

    # Searching for profile for this app
    PROFILE_FOUND=false
    while IFS= read -d $'\0' -r PROVISIONING_PROFILE ; do
        PROFILE_PLIST_CONTENTS=$(security cms -D -i "${PROVISIONING_PROFILE}")
        PROFILE_NAME=$(/usr/libexec/PlistBuddy -c 'Print :Name' /dev/stdin <<< $PROFILE_PLIST_CONTENTS)
        PROFILE_ID=$(/usr/libexec/PlistBuddy -c 'Print :UUID' /dev/stdin <<< $PROFILE_PLIST_CONTENTS)
        PROFILE_APP_ID=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' /dev/stdin <<< $PROFILE_PLIST_CONTENTS)
        PROFILE_TEAM_NAME=$(/usr/libexec/PlistBuddy -c 'Print :TeamName' /dev/stdin <<< $PROFILE_PLIST_CONTENTS)
        PROFILE_DEVICES=$(/usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' /dev/stdin <<< $PROFILE_PLIST_CONTENTS 2> /dev/null)

        if [[ $PROFILE_NAME == *'iOSTeam'* ]]
        then
            continue
        fi

        # if [[ $? != 0 ]]
        # then
        #     echo " ~  Found non-enterprise distribution certificate for '${PROFILE_NAME}' (${PROFILE_ID}). Please remove it. Skipping."
        #     continue
        # fi


        if [[ "${PROFILE_APP_ID}" == "${APP_ID}" ]]
        then
            PROFILE_FOUND=true
            echo " ~  Found profile for '${PROFILE_NAME}' (${PROFILE_ID}). Using it's values as default."

            PROVISIONING_PROFILE_NAME=$PROFILE_NAME
            PROVISIONING_PROFILE_ID=$PROFILE_ID
            echo " ~~  Setting default provisioning profile to '${PROVISIONING_PROFILE_NAME}' ('${PROVISIONING_PROFILE_ID}')"

            CODE_SIGN_IDENTITY="iPhone Distribution: ${PROFILE_TEAM_NAME}"
            echo " ~~  Setting default code sign identity to '${CODE_SIGN_IDENTITY}'. This is unsafe generated value."

            echo " ~  Searching for application group ids in provisioning profile."
            i=0
            while true
            do
                PROFILE_GROUP_ID=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.security.application-groups:${i}" /dev/stdin <<< $PROFILE_PLIST_CONTENTS 2> /dev/null)
                if [[ $? != 0 ]]
                then
                    break
                fi

                containsElement "${PROFILE_GROUP_ID}" "${GROUP_IDS[@]}"
                if [[ $? == 0 ]]
                then
                    echo " ~~  Found new Group ID '${PROFILE_GROUP_ID}'."
                    GROUP_IDS+=($PROFILE_GROUP_ID)
                else
                    echo " ~~  Found duplicated Group ID '${PROFILE_GROUP_ID}'."
                fi
                PROFILE_APP_GROUPS+=($TMP)
                i+=1
            done

            break
        fi
    done < <(find ~/Library/MobileDevice/Provisioning\ Profiles -type f -iname "*.mobileprovision" -print0)

    if [[ $PROFILE_FOUND == false ]]
    then
        echo "[E] Can't find valid provisioning profile for '${APP_ID}' application ID."
        exit 1
    fi

    # Save group id for later use
    DEFINED_GROUP_ID=$(/usr/libexec/PlistBuddy -c "Print:GroupID" "${TARGET_SETTING_PLIST}" 2> /dev/null)
    if [[ $? == 0 ]]
    then
        echo " ~  Application group ID is explicitly added in target settings plist: '${DEFINED_GROUP_ID}'."

        containsElement "${DEFINED_GROUP_ID}" "${GROUP_IDS[@]}"
        if [[ $? == 0 ]]
        then
            echo " ~~  Found new Group ID '${DEFINED_GROUP_ID}'."
            GROUP_IDS+=($DEFINED_GROUP_ID)
        else
            echo " ~~  Found duplicated Group ID '${DEFINED_GROUP_ID}'."
        fi
    fi

    # Setting provisioning profile
    DEFINED_PROVISIONING_PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print:ProvisioningProfileName" "${TARGET_SETTING_PLIST}" 2> /dev/null)
    if [[ $? == 0 ]]
    then
        PROVISIONING_PROFILE_NAME=$DEFINED_PROVISIONING_PROFILE_NAME
        echo " ~  Provisioning profile name is explicitly set in target settings plist: '${PROVISIONING_PROFILE_NAME}'."
    fi
    DEFINED_PROVISIONING_PROFILE_ID=$(/usr/libexec/PlistBuddy -c "Print:ProvisioningProfileID" "${TARGET_SETTING_PLIST}" 2> /dev/null)
    if [[ $? == 0 ]]
    then
        PROVISIONING_PROFILE_ID=$DEFINED_PROVISIONING_PROFILE_ID
        echo " ~  Provisioning profile name is explicitly set in target settings plist: '${PROVISIONING_PROFILE_ID}'."
    fi
    echo " ~  Resulting provisioning profile is '${PROVISIONING_PROFILE_NAME}' ('${PROVISIONING_PROFILE_ID}')"
    ${SCRIPTS_DIR}/xcode/target-settings.sh -p "${PROJECT}" -t "${TARGET_NAME}" -k "PROVISIONING_PROFILE" -v "${PROVISIONING_PROFILE_ID}" >> /dev/null

    # Setting code sign identity
    DEFINED_CODE_SIGN_IDENTITY=$(/usr/libexec/PlistBuddy -c "Print:CodeSignIdentity" "${TARGET_SETTING_PLIST}" 2> /dev/null)
    if [[ $? == 0 ]]
    then
        CODE_SIGN_IDENTITY=$DEFINED_CODE_SIGN_IDENTITY
        echo " ~  Code signing identity is explicitly set in target settings plist: '${CODE_SIGN_IDENTITY}'."
    fi
    echo " ~  Resulting code sign identity is '${CODE_SIGN_IDENTITY}'"
    ${SCRIPTS_DIR}/xcode/target-settings.sh -p "${PROJECT}" -t "${TARGET_NAME}" -k "CODE_SIGN_IDENTITY" -v "${CODE_SIGN_IDENTITY}" >> /dev/null
    ${SCRIPTS_DIR}/xcode/target-settings.sh -p "${PROJECT}" -t "${TARGET_NAME}" -k "CODE_SIGN_IDENTITY[sdk=iphoneos*]" -v "${CODE_SIGN_IDENTITY}" >> /dev/null

    # Setting build version
    BUILD_VERSION_SHORT=$(/usr/libexec/PlistBuddy -c "Print:CFBundleShortVersionString" "${INFO_PLIST_PATH}")
    BUILD_VERSION="${BUILD_VERSION_SHORT}.${BUILD_NUMBER}"
    echo " ~  Setting build version to '${BUILD_VERSION}'"
    /usr/libexec/PlistBuddy -c "Set:CFBundleVersion '${BUILD_VERSION}'" "${INFO_PLIST_PATH}"

    # Saving main settings for future use
    if [[ "${TARGET_NAME}" == "${APPLICATION}" ]]
    then
        MAIN_PROVISIONING_PROFILE_NAME=$PROVISIONING_PROFILE_NAME
        MAIN_SERVER_ID=$SERVER_ID
        MAIN_BUNDLE_ID=$BUNDLE_ID
    fi
done

# Changing entitlements
for ENTITLEMENTS_PLIST_FILE in "${ENTITLEMENTS_PLIST_PATHS[@]}"
do
    echo "[I] Editing entitlements file '${ENTITLEMENTS_PLIST_FILE}'."

    # Remove old data
    /usr/libexec/PlistBuddy -c "Delete:com.apple.security.application-groups" "${ENTITLEMENTS_PLIST_FILE}"
    /usr/libexec/PlistBuddy -c "Add:com.apple.security.application-groups array" "${ENTITLEMENTS_PLIST_FILE}"
    /usr/libexec/PlistBuddy -c "Delete:keychain-access-groups" "${ENTITLEMENTS_PLIST_FILE}"
    /usr/libexec/PlistBuddy -c "Add:keychain-access-groups array" "${ENTITLEMENTS_PLIST_FILE}"

    # Set Application Group
    for GROUP_ID in "${GROUP_IDS[@]}"
    do
        echo " ~  Adding '${GROUP_ID}' to application groups"
        /usr/libexec/PlistBuddy -c "Add:com.apple.security.application-groups: string '${GROUP_ID}'" "${ENTITLEMENTS_PLIST_FILE}"
    done

    # Share keychains between all targets
    for BUNDLE_ID in "${BUNDLE_IDS[@]}"
    do
        echo " ~  Adding '${BUNDLE_ID}' to keychain access group"
        /usr/libexec/PlistBuddy -c "Add:keychain-access-groups: string '\$(AppIdentifierPrefix)${BUNDLE_ID}'" "${ENTITLEMENTS_PLIST_FILE}"
    done
done
