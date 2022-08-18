#!/usr/bin/env bash

set -e

NO_COLOR="\033[0m"
OK_COLOR="\033[32;01m"
ERROR_COLOR="\033[31;01m"
WARN_COLOR="\033[33;01m"

if [[ -z "$HOST" ]]; then
	echo -e "${ERROR_COLOR}HOST is not set${NO_COLOR}" >&2
	exit 1
fi

test -d build && rm -rf build
mkdir build

tmpDir=$(mktemp -d) && trap "rm -rf ${tmpDir}" EXIT

git config --global advice.detachedHead false

echo -e "${OK_COLOR}Build repositories${NO_COLOR}"
echo

for repository in repositories/*.json; do
	echo -e "${WARN_COLOR}Read${NO_COLOR}: $repository"

	path=$(jq -r .path <"$repository")
	repositoryURL=$(jq -r .repository <"$repository")
	gitRef=$(jq -r '.ref // "master"' <"$repository")
	buildDir="build/$path"
	gitDir="$tmpDir/$path"

	echo -e "${WARN_COLOR}Create${NO_COLOR}: ${buildDir}"
	echo -e "${WARN_COLOR}Create${NO_COLOR}: ${gitDir}"

	mkdir "$buildDir" "$gitDir"

	echo -e "${WARN_COLOR}Write${NO_COLOR}: $buildDir/index.html"

	cat <<EOF >"$buildDir/index.html"
<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
        <meta http-equiv="refresh" content="0; url=https://pkg.go.dev/$HOST/$path/">
        <meta name="go-import" content="$HOST/$path git $repositoryURL">
        <meta name="go-source" content="$HOST/$path $repositoryURL $repositoryURL/tree/master{/dir} $repositoryURL/blob/master{/dir}/{file}#L{line}">
    </head>
    <body>
        Nothing to see here; <a href="https://pkg.go.dev/$HOST/$path/">see the package on pkg.go.dev</a>.
    </body>
</html>
EOF

	echo -e "${WARN_COLOR}Clone${NO_COLOR}: ${repositoryURL}@${gitRef}"
	git -C "$gitDir" clone --quiet "$repositoryURL" .
	(cd "$gitDir" && git checkout "$gitRef")

	subModules=($(find "$gitDir" -type f -name 'go.mod' | sed -E "s#$gitDir/##g" | sed -E 's#/go.mod##g' | grep -v go.mod || true))

	if [[ ${#subModules[@]} -eq 0 ]]; then
		echo "No submodules found"
		echo

		continue
	fi

	for subModule in "${subModules[@]}"; do
		subModuleDir="$buildDir/$subModule"

		echo -e "${WARN_COLOR}Create${NO_COLOR}: ${subModuleDir}"

		mkdir "$subModuleDir"

		echo -e "${WARN_COLOR}Write${NO_COLOR}: $subModuleDir/index.html"

		cat <<EOF >"$subModuleDir/index.html"
<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
        <meta http-equiv="refresh" content="0; url=https://pkg.go.dev/$HOST/$path/$subModule/">
        <meta name="go-import" content="$HOST/$path git $repositoryURL">
        <meta name="go-source" content="$HOST/$path $repositoryURL $repositoryURL/tree/master{/dir} $repositoryURL/blob/master{/dir}/{file}#L{line}">
    </head>
    <body>
        Nothing to see here; <a href="https://pkg.go.dev/$HOST/$path/">see the package on pkg.go.dev</a>.
    </body>
</html>
EOF
	done

	echo
done

echo -e "${OK_COLOR}Build index.html${NO_COLOR}"

indexURLs=$(cat repositories/*.json | jq -r --arg host "$HOST" -s '.[] | "<li><a href=\"https://pkg.go.dev/\($host)/\(.path)\">\($host)/\(.path)</a></li>"' 2>/dev/null)

echo -e "${WARN_COLOR}Write${NO_COLOR}: index.html"

cat <<EOF >build/index.html
<!DOCTYPE html>
<html>
<h1>$HOST</h1>
<ul>$indexURLs</ul>
</html>
EOF
