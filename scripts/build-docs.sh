#!/usr/bin/env bash
# Builds the DocC documentation site, styled to match https://transitmatters.github.io/architecture/.
#
# Usage: scripts/build-docs.sh [output-dir]    (default: .build/docs-site)
#
# Warnings, such as broken symbol links or undocumented parameters, fail the build.
set -euo pipefail

cd "$(dirname "$0")/.."

OUTPUT="${1:-.build/docs-site}"
# GitHub Pages serves the site at https://transitmatters.github.io/transitmatters-swift/.
BASE_PATH="transitmatters-swift"

swift package --allow-writing-to-directory "$OUTPUT" generate-documentation \
    --target TransitMatters \
    --output-path "$OUTPUT" \
    --transform-for-static-hosting \
    --hosting-base-path "$BASE_PATH" \
    --experimental-enable-custom-templates \
    --source-service github \
    --source-service-base-url https://github.com/transitmatters/transitmatters-swift/blob/main \
    --checkout-path "$PWD" \
    --warnings-as-errors

# theme-settings.json can name fonts but not load them, and DocC has no favicon setting, so patch
# each page's <head>: load Roboto from Google Fonts like MkDocs Material does, and use the Labs flask.
fonts='<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Roboto:ital,wght@0,300;0,400;0,500;0,700;1,400;1,700&family=Roboto+Mono:wght@400;700&display=fallback">'
find "$OUTPUT" -name index.html -print0 | FONTS="$fonts" xargs -0 perl -pi -e '
    s{<link rel="icon" href="([^"]*)/favicon\.ico">}{<link rel="icon" type="image/png" href="$1/images/TransitMatters/favicon.png">};
    s{</head>}{$ENV{FONTS}</head>};
'

# The site root has no content of its own; send visitors to the landing page.
cat > "$OUTPUT/index.html" <<EOF
<!doctype html>
<html lang="en-US">
<meta charset="utf-8">
<title>TransitMatters Swift</title>
<meta http-equiv="refresh" content="0; url=documentation/transitmatters/">
<link rel="canonical" href="https://transitmatters.github.io/$BASE_PATH/documentation/transitmatters/">
<a href="documentation/transitmatters/">TransitMatters Swift documentation</a>
</html>
EOF

echo "Built $OUTPUT"
