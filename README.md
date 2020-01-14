# OXID 6 module porting script

Helper script for porting oxid 4/5 modules to oxid 6. __Please note__: depending on the options you set (see below), file contents may be changed by the script! So to make sure, better have a backup somewhere :)

## Usage

`sh oxid6-port_modules.sh`

You also can use the following env variables:

`env ESHOP_PATH="/var/www/html" env OLD_MODULE_NAME= env FIX_CODESNIFFER=yes env RUN_TESTS=yes env RUN_CODESNIFFER=yes env AUTO_REPLACE_OLD_CLASSNAMES=yes env MODULE_NAME="pc/foo" sh oxid6-port_modules.sh` or edit the variables at the top of the script.

## Options

Here is a list of (env) variables you can use:

* __MODULE_NAME__: the path/name of your module, e.g. "myvendor/myplugin" - mandatory!
* __ESHOP_PATH__: the base path to your OXID 6 installation, e.g. "/var/www/html" - mandatory!
* __RUN_TESTS__: auto-run tests in the module folder, if any?
* __RUN_CODESNIFFER__: run PHPCS for the module
* __FIX_CODESNIFFER__: if the script should try to auto-correct PHPCS warnings and errors with [PHPCBF](https://github.com/squizlabs/PHP_CodeSniffer/wiki/Fixing-Errors-Automatically#using-the-php-code-beautifier-and-fixer), set this to "yes" (files may be changed by the script!)
* __AUTO_REPLACE_OLD_CLASSNAMES__: try to replace e.g. "oxRegistry" instances in the module files with "\OxidEsales\Eshop\Core\Registry" etc. (files may be changed by the script!)
* __OLD_MODULE_NAME__: if you keep the old version of the module as a reference, you can set the name here, e.g. "myvendor/myplugin-OLD" (_Note_: if you use a folder with the ending "-ORIG", e.g. "myvendor/myplugin-ORIG", it will be automatically found/used) - optional, will be used for some file comparisons, e.g. if all new files have namespaces.

## Changelog

* 2020-01-10  First release

## License

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

## Copyright

Proud Sourcing GmbH | www.proudcommerce.com
