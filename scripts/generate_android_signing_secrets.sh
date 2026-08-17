#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"

output_mode=""
output_path="${project_root}/android/keystore.p12"
secrets_path="${project_root}/android/signing-secrets.env.secret"
key_alias="${ANDROID_KEY_ALIAS:-dploygo-upload}"
distinguished_name="${ANDROID_KEY_DNAME:-CN=DployGo Upload,OU=Mobile,O=DployGo,C=IT}"
force=false

usage() {
  cat <<'EOF'
Generate an Android upload keystore and the four GitHub Actions secrets used
by the release workflow.

Usage:
  ./scripts/generate_android_signing_secrets.sh --set-github [options]
  ./scripts/generate_android_signing_secrets.sh --print [options]

Output modes (choose exactly one):
  --set-github       Store the values with `gh secret set` without displaying them.
  --print            Print NAME=value lines. Treat the terminal output as sensitive.

Options:
  --alias NAME       Key alias (default: dploygo-upload).
  --dname NAME       Certificate distinguished name.
  --output PATH      Keystore path (default: android/keystore.p12).
  --force            Replace an existing keystore at the output path.
  -h, --help         Show this help.

Environment overrides:
  ANDROID_KEY_ALIAS
  ANDROID_KEY_DNAME
  ANDROID_KEYSTORE_PASSWORD

PKCS#12 uses one password for the store and private key, so the generated
ANDROID_KEYSTORE_PASSWORD and ANDROID_KEY_PASSWORD values are identical.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

while (($# > 0)); do
  case "$1" in
    --set-github|--print)
      [[ -z "${output_mode}" ]] || fail "Choose only one output mode."
      output_mode="$1"
      shift
      ;;
    --alias)
      (($# >= 2)) || fail "--alias requires a value."
      key_alias="$2"
      shift 2
      ;;
    --dname)
      (($# >= 2)) || fail "--dname requires a value."
      distinguished_name="$2"
      shift 2
      ;;
    --output)
      (($# >= 2)) || fail "--output requires a value."
      output_path="$2"
      shift 2
      ;;
    --force)
      force=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "${output_mode}" ]] || fail "Choose --set-github or --print."
[[ -n "${key_alias}" ]] || fail "The key alias cannot be empty."
[[ -n "${distinguished_name}" ]] || fail "The distinguished name cannot be empty."

require_command keytool
require_command openssl
require_command base64
require_command tr

if [[ "${output_mode}" == "--set-github" ]]; then
  require_command gh
  (
    cd "${project_root}"
    gh auth status >/dev/null
  )
fi

if [[ "${output_path}" != /* ]]; then
  output_path="${PWD}/${output_path}"
fi

if [[ -e "${output_path}" && "${force}" != true ]]; then
  fail "${output_path} already exists. Back it up or pass --force to replace it."
fi
if [[ "${output_mode}" == "--set-github" && -e "${secrets_path}" && "${force}" != true ]]; then
  fail "${secrets_path} already exists. Back it up or pass --force to replace it."
fi

keystore_password="${ANDROID_KEYSTORE_PASSWORD:-}"
if [[ -z "${keystore_password}" ]]; then
  keystore_password="$(openssl rand -hex 32)"
fi

if ((${#keystore_password} < 12)); then
  fail "ANDROID_KEYSTORE_PASSWORD must contain at least 12 characters."
fi

output_dir="$(dirname "${output_path}")"
mkdir -p "${output_dir}"
temp_dir="$(mktemp -d "${output_path}.tmp.XXXXXX")"
temp_keystore="${temp_dir}/keystore.p12"

cleanup() {
  rm -f "${temp_keystore}"
  rmdir "${temp_dir}" 2>/dev/null || true
}
trap cleanup EXIT

keytool -genkeypair \
  -keystore "${temp_keystore}" \
  -storetype PKCS12 \
  -storepass "${keystore_password}" \
  -keypass "${keystore_password}" \
  -alias "${key_alias}" \
  -keyalg RSA \
  -keysize 4096 \
  -sigalg SHA256withRSA \
  -validity 10000 \
  -dname "${distinguished_name}" \
  -noprompt

keytool -list \
  -keystore "${temp_keystore}" \
  -storetype PKCS12 \
  -storepass "${keystore_password}" \
  -alias "${key_alias}" >/dev/null

if [[ -e "${output_path}" ]]; then
  rm -f "${output_path}"
fi
mv "${temp_keystore}" "${output_path}"
chmod 600 "${output_path}"
keystore_base64="$(base64 < "${output_path}" | tr -d '\r\n')"

if [[ "${output_mode}" == "--set-github" ]]; then
  umask 077
  {
    printf 'ANDROID_KEYSTORE_BASE64=%s\n' "${keystore_base64}"
    printf 'ANDROID_KEYSTORE_PASSWORD=%s\n' "${keystore_password}"
    printf 'ANDROID_KEY_ALIAS=%s\n' "${key_alias}"
    printf 'ANDROID_KEY_PASSWORD=%s\n' "${keystore_password}"
  } > "${secrets_path}"
  chmod 600 "${secrets_path}"

  (
    cd "${project_root}"
    printf '%s' "${keystore_base64}" | gh secret set ANDROID_KEYSTORE_BASE64
    printf '%s' "${keystore_password}" | gh secret set ANDROID_KEYSTORE_PASSWORD
    printf '%s' "${key_alias}" | gh secret set ANDROID_KEY_ALIAS
    printf '%s' "${keystore_password}" | gh secret set ANDROID_KEY_PASSWORD
  )
  printf 'Created %s and set four GitHub Actions secrets.\n' "${output_path}"
  printf 'Recovery values were saved to %s (mode 600).\n' "${secrets_path}" >&2
else
  printf '%s\n' 'WARNING: The following values are sensitive. Do not save them in Git.' >&2
  printf 'ANDROID_KEYSTORE_BASE64=%s\n' "${keystore_base64}"
  printf 'ANDROID_KEYSTORE_PASSWORD=%s\n' "${keystore_password}"
  printf 'ANDROID_KEY_ALIAS=%s\n' "${key_alias}"
  printf 'ANDROID_KEY_PASSWORD=%s\n' "${keystore_password}"
fi

printf 'Back up %s and its password securely; losing the upload key can block app updates.\n' "${output_path}" >&2
