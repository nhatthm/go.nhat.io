#!/usr/bin/env bash

set -e

if [[ -z "$HOST" ]]; then
	echo "HOST is not set" >&2
	exit 1
fi

test -d build && rm -rf build
mkdir build

tmpDir=$(mktemp -d) && trap "rm -rf ${tmpDir}" EXIT

indexURLs=$(cat repositories/*.json | jq -r --arg host "$HOST" -s '.[] | "<li><a href=\"https://pkg.go.dev/\($host)/\(.path)\">\($host)/\(.path)</a></li>"' 2>/dev/null)

for repository in repositories/*.json; do
	path=$(jq -r .path <"$repository")
	repositoryURL=$(jq -r .repository <"$repository")
	buildDir="build/$path"
	gitDir="$tmpDir/$path"

	echo "Building $repository"

	mkdir "$buildDir" "$gitDir"

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

	git -C "$gitDir" clone "$repositoryURL" .

	subModules=($(find "$gitDir" -type f -name 'go.mod' | sed -E "s#$gitDir/##g" | sed -E 's#/go.mod##g' | grep -v go.mod || true))

	if [[ ${#subModules[@]} -eq 0 ]]; then
		continue
	fi

	for subModule in "${subModules[@]}"; do
		subModuleDir="$buildDir/$subModule"

		mkdir "$subModuleDir"

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
done

cat <<EOF >build/index.html
<!DOCTYPE html>
<html>
<h1>$HOST</h1>
<ul>$indexURLs</ul>
</html>
EOF
