#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2020-02-07 15:01:31 +0000 (Fri, 07 Feb 2020)
#
#  https://github.com/harisekhon/bash-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

# Script to generate Status.md containing the headers and status badges of the Top N rated by stars GitHub repos across all CI platforms on a single page
#
# Usage:
#
#   without arguments queries for all non-fork repos for your $USER and iterate them up to $top_N to generate the page
#
# github_generate_status_page.sh
#
#  with arguments will query those repo's README.md at the top level
#
# github_generate_status_page.sh  HariSekhon/DevOps-Python-tools  HariSekhon/DevOps-Perl-tools
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(dirname "$0")"

top_N=20

repolist="$*"

USER="${GITHUB_USER:-${USERNAME:-${USER}}}"

get_repos(){
    page=1
    while true; do
        echo "fetching repos page $page" >&2
        if ! output="$("$srcdir/github_api.sh" "/users/$USER/repos?page=$page&per_page=100")"; then
            echo "ERROR" >&2
            exit 1
        fi
        # use authenticated requests if you are hitting the API rate limit - this is automatically done above now if USER/PASSWORD GITHUB_USER/GITHUB_PASSWORD/GITHUB_TOKEN environment variables are detected
        # eg. CURL_OPTS="-u harisekhon:$GITHUB_TOKEN" ...
        # shellcheck disable=SC2086
        if [ -z "$(jq '.[]' <<< "$output")" ]; then
            break
        elif jq -r '.message' <<< "$output" >&2 2>/dev/null; then
            exit 1
        fi
        jq -r '.[] | select(.fork | not) | [.full_name, .stargazers_count] | @tsv' <<< "$output"
        ((page+=1))
    done
}

if [ -z "$repolist" ]; then
    repolist="$(get_repos | grep -v spark-apps | sort -k2nr | awk '{print $1}' | head -n "$top_N")"
fi

#echo "$repolist" >&2

# make portable between linux and mac
head(){
    if [ "$(uname -s)" = Darwin ]; then
        # from brew's coreutils package (installed by 'make')
        ghead "$@"
    else
        command head "$@"
    fi
}

{
cat <<EOF
# GitHub Status Page

generated by \`${0##*/}\` in [HariSekhon/DevOps-Bash-tools](https://github.com/HariSekhon/DevOps-Bash-tools)

EOF

for repo in $repolist; do
    echo "getting repo $repo" >&2
    echo ---
    curl -sS "https://raw.githubusercontent.com/$repo/master/README.md" |
    sed -n '1,/^[^\[[:space:]<=-]/ p' |
    head -n -1 |
    #perl -ne 'print unless /=============/;' |
    grep -v "===========" |
    sed '1 s/^[^#]/# &/' |
    # \\ escapes the newlines to allow them inside the sed for literal replacement since \n doesn't work
    sed "2 s|^|\\
Link:  [$repo](https://github.com/$repo)\\
\\
|"
    echo
done
} | tee "STATUS.md"
