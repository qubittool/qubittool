#!/bin/bash
# Validate all qubittool.com links in GitHub Pages HTML files against sitemap

set -eo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
HTML_DIR="$SCRIPT_DIR"

SITEMAP_FILES=(
  "$MAIN_REPO/public/sitemap-tools-en.xml"
  "$MAIN_REPO/public/sitemap-tools-zh.xml"
  "$MAIN_REPO/public/sitemap-blog-en.xml"
  "$MAIN_REPO/public/sitemap-glossary-en.xml"
  "$MAIN_REPO/public/sitemap-pages-en.xml"
  "$MAIN_REPO/public/sitemap-quiz-en.xml"
)

HTML_FILES=(
  "index.html"
  "json-tools.html"
  "text-tools.html"
  "image-tools.html"
  "pdf-tools.html"
  "dev-tools.html"
  "calculator-tools.html"
  "ai-directory.html"
  "blog.html"
  "glossary.html"
)

SKIP_PATHS=(
  "/"
  "/blog"
  "/glossary"
  "/en/blog"
  "/en/glossary"
)

# --- Step 1: Build sitemap path set ---
declare -A sitemap_paths

for sitemap in "${SITEMAP_FILES[@]}"; do
  if [[ ! -f "$sitemap" ]]; then
    echo -e "${YELLOW}Warning: Sitemap not found: $sitemap${NC}"
    continue
  fi
  while IFS= read -r url; do
    path="${url#https://qubittool.com}"
    [[ -z "$path" ]] && path="/"
    sitemap_paths["$path"]=1
  done < <(grep -oE '<loc>https://qubittool\.com[^<]*</loc>' "$sitemap" | sed 's/<loc>//;s/<\/loc>//')
done

echo "Loaded ${#sitemap_paths[@]} paths from sitemaps."
echo ""

# --- Step 2: Extract and check links from HTML files ---
total=0
valid=0
invalid=0
declare -a invalid_entries=()

for html_file in "${HTML_FILES[@]}"; do
  filepath="$HTML_DIR/$html_file"
  if [[ ! -f "$filepath" ]]; then
    continue
  fi

  while IFS= read -r link; do
    # Extract path from full URL
    path="${link#https://qubittool.com}"
    [[ -z "$path" ]] && path="/"

    # Check if this path should be skipped
    skip=false
    for sp in "${SKIP_PATHS[@]}"; do
      if [[ "$path" == "$sp" ]]; then
        skip=true
        break
      fi
    done
    $skip && continue

    total=$((total + 1))

    # Normalize: strip /en/ or /zh/ prefix for sitemap comparison
    normalized="$(echo "$path" | sed -E 's/^\/(en|zh)\//\//')"

    # Check against sitemap
    if [[ -n "${sitemap_paths[$normalized]+_}" ]]; then
      valid=$((valid + 1))
    else
      invalid=$((invalid + 1))
      invalid_entries+=("$html_file -> $link (path: $normalized)")
    fi
  done < <(grep -oE 'href="https://qubittool\.com[^"]*"' "$filepath" | sed 's/^href="//;s/"$//' | sort -u)
done

# --- Step 3: Report ---
echo "========================================="
echo " Link Validation Report"
echo "========================================="
echo ""

if [[ $invalid -gt 0 ]]; then
  echo -e "${RED}Invalid links (not found in sitemap):${NC}"
  echo ""
  for entry in "${invalid_entries[@]}"; do
    echo -e "  ${RED}✗${NC} $entry"
  done
  echo ""
fi

echo -e "${GREEN}✓ Valid: $valid${NC}"
if [[ $invalid -gt 0 ]]; then
  echo -e "${RED}✗ Invalid: $invalid${NC}"
else
  echo -e "${GREEN}✗ Invalid: 0${NC}"
fi
echo "  Total links checked: $total"
echo ""

if [[ $invalid -gt 0 ]]; then
  echo -e "${RED}FAILED: $invalid link(s) not found in sitemap.${NC}"
  exit 1
else
  echo -e "${GREEN}PASSED: All links are valid.${NC}"
  exit 0
fi
