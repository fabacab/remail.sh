#!/bin/bash -
#
# File:        remail.sh
#
# Description: A simple Cypherpunk message preprocessor that makes it
#              simpler to chain Type I anonymous remailers together.
#
# Examples:    Use remail.sh to prepare a multihop anonymous email in
#              a Cypherpunk remailer system. Usage is simple:
#
#                  ./remail.sh message.txt recipient@example.com \
#                      mixmaster@remailer1.com \
#                      mixmaster@remailer2.com
#
#              You can chain an arbitrary number of remailers; you're
#              not limited to just two.
#
# License:     GPL3
#
###############################################################################
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
###############################################################################

# DEBUGGING
set -e
set -C # noclobber

# TRAP SIGNALS
trap 'cleanup' QUIT EXIT

# For security reasons, explicitly set the internal field separator
# to newline, space, tab
OLD_IFS=$IFS
IFS='
 	'

function cleanup () {
    if [ $DEBUG -eq 0 ]; then
        rm -f "$EMAIL"
        rm -f "$EMAIL.next"
    fi
    IFS="$OLD_IFS"
}

function usage () {
    echo "Usage:"
    echo
    echo "  $PROGRAM [options] <message> <recipient_email> <remailer_1> [remailer_2 [remailer_N]]"
    echo
    echo "$PROGRAM takes at least three parameters:"
    echo " <message>         path to a file containing the message text to mail"
    echo " <recipient_email> the email address of the ultimate recipient"
    echo " <remailer_1>      the email address of the first remailer"
    echo
    echo "You can use any number of additional remailers after the first one"
    echo "and $PROGRAM will successively wrap your message in layers for each"
    echo "of the remailers you specify, effectively creating a remailer chain."
    echo
    echo "Options:"
    echo " -e, --encrypt-message   Also encrypts the original <message> text to"
    echo "                         the intended recipient with their PGP key."
    echo "                         For this to work, you must have already"
    echo "                         imported their PGP key to your keyring."
    echo
    echo " -n, --no-encrypt        Turns off PGP/GPG encryption to remailers."
    echo "                         Useful for debugging purposes (but see the"
    echo "                         --debug option), or if all the remailers you"
    echo "                         chose support unencrypted messages. This is"
    echo "                         very rarely what you actually want to do."
    echo
    echo " --debug                 Adds an extra recipient decryption key for"
    echo "                         encrypted messages to a remailer. Useful for"
    echo "                         debugging remailer chain problems. The debug"
    echo "                         PGP key is the one for <recipient_email>, so"
    echo "                         always address debug messages to yourself."
    echo
    echo "                         This will also print a bunch more output to"
    echo "                         your terminal at each step of the encryption"
    echo "                         chain, showing the content to be encrpyted."
    echo
    echo "                         Again, DO NOT use this for preparing actual"
    echo "                         emails that you would like to anonymize."
    echo
    echo " -V, --version           Prints the running version and exits."
    echo
    echo " -?, --help, --usage     Prints this help information and exits."
}

function version () {
    echo "$PROGRAM version $VERSION"
}

# Helper functions.
function addDirectives () {
    printf "::\n"
    for directive in "$@"; do
        addHeader "$directive"
    done
    printf "\n"
}
function addHeaders () {
    printf "##\n"
    for header in "$@"; do
        addHeader "$header"
    done
    printf "\n"
}
function addHeader () {
    printf "%s\n" "$1"
}

# Internal variables and initializations.
readonly PROGRAM=`basename "$0"`
readonly VERSION=0.1
readonly EMAIL=".remailer-toemail"

# RETURN VALUES/EXIT STATUS CODES
readonly E_MISSING_ARG=253
readonly E_BAD_OPTION=254
readonly E_UNKNOWN=255

# Options
ENCRYPT_MESSAGE=0
NO_ENCRYPT=0
DEBUG=0

# Process command-line arguments.
if [ $# -lt 3 ]; then
    usage
    exit $E_MISSING_ARG;
fi
while test $# -gt 0; do
    if [ x"$1" == x"--" ]; then
        # detect argument termination
        shift
        break
    fi
    case $1 in
        --encrypt-message | -e )
            shift
            ENCRYPT_MESSAGE=1
            ;;

        --no-encrypt | -n )
            shift
            NO_ENCRYPT=1
            ;;

        --debug )
            shift
            DEBUG=1
            ;;

        --version | -V )
            version
            exit
            ;;

        -? | --usage | --help )
            usage
            exit
            ;;

        -* )
            echo "Unrecognized option: $1" >&2
            usage
            exit $E_BAD_OPTION
            ;;

        * )
            break
            ;;
    esac
done

MSG_FILE="$1"
RCPT_TO="$2"
shift; shift

if [ ! -r "$MSG_FILE" ]; then
    echo "$PROGRAM: $MSG_FILE is not readable" 1>&2
    exit $E_BAD_OPTION;
fi

# Prepare message directives.
declare -a directives
directives[0]="Anon-To: $RCPT_TO"
if [ $DEBUG -eq 1 ]; then
    directives[1]="Latent-Time: +0:00"
fi
addDirectives "${directives[@]}" > "$EMAIL"

# Prepare message itself.
if [ "$ENCRYPT_MESSAGE" -eq 1 ]; then
    gpg2 --encrypt --armor -r "$RCPT_TO" < "$MSG_FILE" >> "$EMAIL"
else
    cat "$MSG_FILE" >> "$EMAIL"
fi

# Encrypt the messages in reverse order, like an onion!
for ((i=$#; i > 0; i--)); do
    let x="$i-1" || true # `let` may return non-zero, but continue anyway
    THIS_REMAILER="${!i}"
    NEXT_REMAILER="${!x}"

    declare -a recipient_opts
    recipient_opts[0]="-r $THIS_REMAILER"
    if [ $DEBUG -eq 1 ]; then
        recipient_opts[1]="-r $RCPT_TO"
    fi

    if [ $NO_ENCRYPT -eq 0 ]; then
        if [ $DEBUG -eq 1 ]; then
            echo "================================="
            cat "$EMAIL"
            echo "================================="
        fi
        gpg2 --encrypt --armor "${recipient_opts[@]}" < "$EMAIL" >| "$EMAIL.next"
        addDirectives "Encrypted: PGP" | cat - "$EMAIL.next" >| "$EMAIL"
    fi

    # Do we have another remailer in the chain?
    # (We don't if the "next remailer" is just the program name, position $0.)
    if [ $NEXT_REMAILER -a "$NEXT_REMAILER" != "$0" ]; then
        declare -a directives
        directives[0]="Anon-To: $THIS_REMAILER"
        if [ $DEBUG -eq 1 ]; then
            directives[1]="Latent-Time: +0:00"
        fi
        addDirectives "${directives[@]}" | cat - "$EMAIL" >| "$EMAIL.next"
        mv -f "$EMAIL.next" "$EMAIL"
    fi
done

cat "$EMAIL"
