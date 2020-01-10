#!/bin/bash

set -o pipefail

##############################################################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# @copyright (c) ProudCommerce | 2020
# @author Stefan Moises <beffy@proudcommerce.com>
# @link www.proudcommerce.com
# @version 1.0.0
# 
# This script is based on https://docs.oxid-esales.com/developer/en/6.0/modules/tutorials/porting_tool.html
# and runs most of the mentioned steps automatically.
#
# Please check the output of the script and fix any problems you see :)
##############################################################################################################

###############################################################
# Settings - please adjust!
###############################################################
# run sub commands as sudo? No if in docker ...
RUN_AS_SUDO="no"

if [[ -z $ESHOP_PATH ]]; then
    export ESHOP_PATH="/app"
fi
# the current module version to check
if [[ -z $MODULE_NAME ]]; then
    export MODULE_NAME="oe/oepaypal"
fi
# the old, original version for OXID < 6 if available
if [[ -z $OLD_MODULE_NAME ]]; then
    if [[ -d "${MODULE_NAME}-ORIG" ]]; then
        export OLD_MODULE_NAME="${MODULE_NAME}-ORIG"
    else
        export OLD_MODULE_NAME=$MODULE_NAME
    fi
fi

if [[ -z $RUN_TESTS ]]; then
    RUN_TESTS="no"
fi

if [[ -z $FIX_CODESNIFFER ]]; then
    FIX_CODESNIFFER="no"
fi

# check code style and syntax?
if [[ -z $RUN_CODESNIFFER ]]; then
    RUN_CODESNIFFER="no"
fi
# try to auto-replace old classnames, e.g. "oxarticle"
if [[ -z $AUTO_REPLACE_OLD_CLASSNAMES ]]; then
    AUTO_REPLACE_OLD_CLASSNAMES="no"
fi
###############################################################
# Helpers
###############################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color
msg() {
  echo -e "\n${NC}---------------------------------------\n$1\n---------------------------------------${NC}\n"
}
success() {
  echo -e "\n${GREEN}---------------------------------------\n$1\n---------------------------------------${NC}\n"
}
warn() {
  echo -e "\n${YELLOW}---------------------------------------\n$1\n---------------------------------------${NC}\n"
}
error() {
  echo -e "\n${RED}---------------------------------------\n$1\n---------------------------------------${NC}\n"
}
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

msg "MODULE_NAME: ${MODULE_NAME}"

###############################################################
# Let's start ...
###############################################################
if [[ $RUN_TESTS == "yes" ]]; then
    msg "Running module tests ..."
    if [[ $RUN_AS_SUDO -ne 1 ]]; then
        echo "Patching vendor/oxid-esales/testing-library/library/Services/Library/Cache.php (removing 'sudo')"
        sed -i 's/sudo //' "$ESHOP_PATH/vendor/oxid-esales/testing-library/library/Services/Library/Cache.php"
    fi
    (cd "$ESHOP_PATH" && PARTIAL_MODULE_PATHS="$MODULE_NAME" ADDITIONAL_TEST_PATHS='' RUN_TESTS_FOR_SHOP=0 RUN_TESTS_FOR_MODULES=1 ACTIVATE_ALL_MODULES=1 vendor/bin/runtests --coverage-html="$ESHOP_PATH/coverage_report/$MODULE_NAME" AllTestsUnit)
fi
cd $SCRIPTDIR

###############################################################
msg "1. Checking file encoding for UTF-8 ..."
cd "$ESHOP_PATH/source/modules/$MODULE_NAME/"
WRONG_FILES=$(find . -type f -regex ".*/.*\.\(php\|tpl\|sql\)" -exec file -i "{}" \; | grep -v 'us-ascii' | grep -v 'utf-8')

if ! [[ -z $WRONG_FILES ]]; then
    error "Found problematic files!"
    echo -e "Found problematic files: \n$WRONG_FILES"
    echo "Hint: use something like 'iconv -f ISO-8859-1 -t UTF-8 input.php > output.php' to fix them ..."
else
    success "File encodings ok (UTF-8)!"
fi
cd $SCRIPTDIR

###############################################################
msg "2. Checking translation files charset settings (UTF-8) ..."
L1=$(find "$ESHOP_PATH/source/modules/$MODULE_NAME/" | grep '_lang.php' | wc -l)
L2=$(grep --include \*_lang.php -r 'charset' "$ESHOP_PATH/source/modules/$MODULE_NAME/" | wc -l)
L3=$(grep --include \*_lang.php -r 'charset' "$ESHOP_PATH/source/modules/$MODULE_NAME/" | grep 'UTF-8' | wc -l)

if [[ $L1 -eq $L2 && $L2 -eq $L3 ]]; then
    success "Translation encoding set correctly to UTF-8!"
else
    error "Please set translation encodings to UTF-8 in your lang files!"
    grep --include \*_lang.php -r 'charset' "$ESHOP_PATH/source/modules/$MODULE_NAME/" | grep -v -i 'UTF-8'
fi
cd $SCRIPTDIR

###############################################################
msg "3. Checking for UTF-8 files without BOM ..."
cd "$ESHOP_PATH/source/modules/$MODULE_NAME/"
WITHBOM=$(find . -type f -regex ".*/.*\.\(php\|tpl\|sql\)" -exec file "{}" \; | grep 'with\ BOM')
if ! [[ -z $WITHBOM ]]; then
    error -e "Found problematic files!"
    echo "$WITHBOM"
    echo "Hint: use something like 'tail --bytes=+4 with_bom.php > without_bom.php' to fix them ..."
else
    success "Ok, all files UTF-8 without BOM!"
fi
cd $SCRIPTDIR

###############################################################
msg "4. Checking DB layer access ..."
L1=$(grep --include \*.php -r 'oxDb' "$ESHOP_PATH/source/modules/$OLD_MODULE_NAME/" | wc -l)
L2=$(grep --include \*.php -r 'DatabaseProvider' "$ESHOP_PATH/source/modules/$MODULE_NAME/" | wc -l)
L3=$(grep --include \*.php -r 'oxDb' "$ESHOP_PATH/source/modules/$MODULE_NAME/")
if [[ $L1 -eq $L2 ]]; then
    success "Ok, all occurences of oxDb have been replaced with DatbaseProvider :)"
else
    warn "Please replace all occurences of oxDb with DatbaseProvider!!"
fi
if [[ -n $L3 ]]; then
    error "Please remove all occurences of oxDb!!"
    echo "$L3"
fi
cd $SCRIPTDIR

###############################################################
msg "5. Checking for breaking changes with select limits ..."
DBCHECK=$(grep --include \*.php -r -i -P "\-\>\s*?(select|selectLimit)\s*?\(" "$ESHOP_PATH/source/modules/$MODULE_NAME/")
if [[ -n $DBCHECK ]]; then
    warn "Please inspect all occurences of select or selectLimit:"
    echo "$DBCHECK"
    echo "Hint: see https://oxidforge.org/en/how-to-quickly-port-a-module-to-oxid-eshop-6-0.html for relevant changes."
fi
cd $SCRIPTDIR

###############################################################
msg "6. Run codesniffer now?"
if [[ $RUN_CODESNIFFER == "yes" ]]; then
    cd "$ESHOP_PATH"
    SNIFF=$(vendor/bin/phpcsoxid "source/modules/$MODULE_NAME/")
    if [[ -n $SNIFF ]]; then
        echo "$SNIFF"
        if [[ $FIX_CODESNIFFER == "yes" ]]; then
            msg "TRYING to fix all sniffer problems found, this may or may not work ..."
            FIX=$(vendor/bin/phpcbf -v "source/modules/$MODULE_NAME/")
            echo "$FIX"
        else
            warn "You should inspect all problems found ..."
        fi
    fi
fi
cd $SCRIPTDIR

###############################################################
# BC Layer checks
msg "7. Check for old, deprecated class names?"
if [[ $AUTO_REPLACE_OLD_CLASSNAMES == "yes" ]]; then
cat << 'EOF' > /tmp/bc_change.php
<?php
count($argv) > 1 || die("File name missing!\n"); $filename = $argv[1];
file_exists($filename) || die("Given file '$filename' does not exist!\n");
getenv('ESHOP_PATH') || die("Please define 'ESHOP_PATH' environment variable!\n");
$bcMapFilename = getenv('ESHOP_PATH') . '/vendor/oxid-esales/oxideshop-ce/source/Core/Autoload/BackwardsCompatibilityClassMap.php';
file_exists($bcMapFilename) || die("BC class layer map missing, please make sure file '$bcMapFilename' is available!\n");

$bcMap = array_map(function($value) { return '\\' . $value; }, require($bcMapFilename));
$contents = file_get_contents($filename);

$methodsWithFirstArgumentAsBcClass = ['oxNew', '::set', '::get', 'resetInstanceCache', 'getComponent', 'getMock', 'assertInstanceOf', 'setExpectedException', 'prophesize'];
$phpdocTags = ['var', 'param', 'return', 'mixin', 'throws', 'see'];

preg_match_all('/[^\S\n]*use[^\S\n]+[\w\\\\]*?(?P<class>\w+)[^\S\n]*;/i', $contents, $matches);
$bcMapKeysToIgnore = $matches['class'];
foreach ($bcMapKeysToIgnore as $class) {
unset($bcMap[strtolower($class)]);
}

foreach ($bcMap as $bcClass => $nsClass) {
$replaceMap = [
    '/\b((' . implode('|', $methodsWithFirstArgumentAsBcClass) . ')\s*\(\s*)["\']' . $bcClass . '["\']/i' => "$1$nsClass::class",
    '/\b(new\s+)' . $bcClass . '\b(\s*[;\()])/i' => "$1$nsClass$2",
    '/\b(catch\s+\(\s*)' . $bcClass . '(\s+\$)/i' => "$1$nsClass$2",
    '/(\@\b(' . implode('|', $phpdocTags) . ')(\s+|\s+\S+\s*\|\s*))' . $bcClass . '\b/i' => "$1$nsClass",
    '/\b(class\s+\w+\s+extends\s+)[\\\\]?' . $bcClass . '\b/i' => "$1$nsClass",
    '/\b(instanceof\s+)' . $bcClass . '\b/i' => "$1$nsClass",
    '/(?<!\\\\)\b' . $bcClass . '(\s*::\s*\$?\w+)/i' => "$nsClass$1",
    '/(?<!\\\\)\b' . $bcClass . '(\s+\$\w+\s*[,\)])/i' => "$nsClass$1",
    '/\buse\s+\\\\' . $bcClass. '\s*;/i' => "",
];

$contents = preg_replace(array_keys($replaceMap), array_values($replaceMap), $contents);
}

$contents && file_put_contents($filename, $contents) || die("There was an error while executing 'preg_replace'!\n");
EOF

    cd "$ESHOP_PATH/source/modules/$MODULE_NAME/"
    find . -type f -regex ".*/.*\.\php" | cut -c 3- | while read MODULE_FILE_NAME; do
    echo "Processing file: $MODULE_FILE_NAME";
    php /tmp/bc_change.php "$ESHOP_PATH/source/modules/$MODULE_NAME/$MODULE_FILE_NAME"
    done
fi

if ! [[ -f "$ESHOP_PATH/vendor/oxid-esales/oxideshop-ce/source/Core/Autoload/BackwardsCompatibilityClassMap.php" ]]; then
    error "BackwardsCompatibilityClassMap.php not found!"
else
    warn "The following occurences MAY contain deprecated class names, e.g. 'oxbasket' instead of 'Basket' etc, see https://github.com/OXID-eSales/oxideshop_ce/blob/v6.0.0/source/Core/Autoload/BackwardsCompatibilityClassMap.php#L12-L572"
    
    BC_CLASS_PAIRS=$(cat "$ESHOP_PATH/vendor/oxid-esales/oxideshop-ce/source/Core/Autoload/BackwardsCompatibilityClassMap.php" | grep '=>' | sed 's/\\\\/\\/g')
    BC_CLASS_LIST=$(echo "$BC_CLASS_PAIRS" | sed -r 's/.*'\''(\w+)'\''.*/\1/g')
    BC_CLASS_LIST_PIPED=$(echo "$BC_CLASS_LIST" | paste -sd "|" | sed -r 's/(.*)/\(\1\)/')
    BC_CLASS_SEARCH_PATTERN='(?<bc_match_quotes>"|'"'"'|)\b(?<!\$|\/|=|-|_|{|\?|\`|\*|:|\[|\.|,|\\|="|='"'"'|<|>|\(|\))('$BC_CLASS_LIST_PIPED')(?!\$|\/|=|-|_|}|\?|\`|\*|:|\]|\.|,|->|\\|>|<|@|\(|\))\b\k<bc_match_quotes>|(?<!\\)(?<bc_skip_quotes>["'"'"']).*?(?<!\\)\k<bc_skip_quotes>(*SKIP)(?!)|\w*(\/\*\*|\*|\/\/|\#).*(*SKIP)(?!)'
    SEARCH_FILE_LIST=$(find "$ESHOP_PATH/source/modules/$MODULE_NAME/" -type f -iregex '.*/.*\.\(php\|tpl\)' -not -iregex '.*/metadata\.php')
    #echo "$SEARCH_FILE_LIST" | xargs -n1 grep --color=always -iP -H -n "$BC_CLASS_SEARCH_PATTERN"
    # skip tests?
    SEARCH_FILE_LIST_WO_TESTS=$(find "$ESHOP_PATH/source/modules/$MODULE_NAME/" -type f -iregex '.*/.*\.\(php\|tpl\)' -not -iregex '.*/metadata\.php' -not -iregex '.*Test\.php' -not -iregex '.*/tests/.*')
    # with paging
    #echo "$SEARCH_FILE_LIST" | xargs -n1 grep --color=always -iP -H -n "$BC_CLASS_SEARCH_PATTERN" | less -r
    echo "$SEARCH_FILE_LIST_WO_TESTS" | xargs -n1 grep --color=always -iP -H -n "$BC_CLASS_SEARCH_PATTERN" #| less -r
fi
cd $SCRIPTDIR

###############################################################
msg "8. Checking for Composer compat"
cd "$ESHOP_PATH/source/modules/$MODULE_NAME/"
COMP=$(find . -name "composer.json")
if [[ -z $COMP ]]; then
    error "No composer.json found! Make sure the module is installable via Composer, see https://docs.oxid-esales.com/developer/en/6.0/modules/module_via_composer.html!"
else
    success "Ok, composer.json found, assuming Composer compat!"
fi
cd $SCRIPTDIR

###############################################################
msg "9. Checking for namespaces"
NSCHECK=$(grep --include \*.php -rL "namespace" "$ESHOP_PATH/source/modules/$MODULE_NAME/")
if [[ -n $NSCHECK ]]; then
    warn "Please inspect all occurences without namespace keyword:"
    echo "$NSCHECK"
fi

###############################################################
# check metadata version
msg "10. Checking metadata version"
MD=$(grep -i -P "sMetadataVersion\s*?=\s*?'2\.0'" "$ESHOP_PATH/source/modules/$MODULE_NAME/metadata.php")
if [[ -z $MD ]]; then
    error "Please use sMetadataVersion >= 2 in metadata.php!"
else
    success "Ok, sMetadataVersion >= 2 found in metadata.php!"
fi
cd $SCRIPTDIR

###############################################################
# check files array, too
msg "11. Checking metadata files array"
MDF=$(grep "'files'" "$ESHOP_PATH/source/modules/$MODULE_NAME/metadata.php")
if ! [[ -z $MDF ]]; then
    error "Please do not use the 'files' array any more in metadata.php!"
else
    success "Ok, no 'files' array entries found in metadata.php!"
fi
cd $SCRIPTDIR

###############################################################
msg "12. Checking metadata extend array"
warn "Please check yourself if the 'extend' array contains namespaced and new class names!"
grep -Pzo '(?s)extend.*?[\)\]]' "$ESHOP_PATH/source/modules/$MODULE_NAME/metadata.php"

###############################################################
msg "13. Checking metadata controllers array"
warn "Please check yourself if all your controller names are lowercase:"
grep -Pzo '(?s)controllers.*?[\)\]]' "$ESHOP_PATH/source/modules/$MODULE_NAME/metadata.php"

###############################################################
msg "14. Checking namespaced class counts ..."
NS1=$(grep --include \*.php --exclude \*Test.php -r '^class' "$ESHOP_PATH/source/modules/$OLD_MODULE_NAME" | wc -l)
NS2=$(grep --include \*.php --exclude \*Test.php -r '^namespace' "$ESHOP_PATH/source/modules/$MODULE_NAME" | wc -l)

if [[ $NS1 -ne $NS2 ]]; then
    warn "Namespaced count does not match old class count, please check."
fi

###############################################################
msg "15. Checking for short array syntax in metadata.php"
SA=$(grep -i 'array' "$ESHOP_PATH/source/modules/$MODULE_NAME/metadata.php" | wc -l)
if [[ -n $SA ]]; then
    warn "Old long-array syntax found, consider replacing it, see http://php.net/manual/en/language.types.array.php"
fi

cd $SCRIPTDIR
msg "DONE!"
