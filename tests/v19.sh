#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
db_password=${TKL_TEST_DB_PASS:?TKL_TEST_DB_PASS is required}
base=https://localhost
webroot=/var/www/ibexa
cookie=/tmp/tkl-ibexa-cookie.$$
page=/tmp/tkl-ibexa-page.$$
headers=/tmp/tkl-ibexa-headers.$$
outdated=/tmp/tkl-ibexa-outdated.$$
remote_id="turnkey-v19-acceptance-$$"
content_name="TurnKey Ibexa v19 acceptance $$"

cleanup() {
    rm -f -- "$cookie" "$page" "$headers" "$outdated"
}
trap cleanup EXIT

systemctl --quiet is-active apache2.service mariadb.service postfix.service \
    multi-user.target
systemctl --quiet is-enabled apache2.service mariadb.service postfix.service
apache2ctl -t
grep -Fxq 'VERSION_CODENAME=trixie' /etc/os-release
grep -Eq '^turnkey-ibexa-19\.0' /etc/turnkey_version

commit=$(git -c safe.directory="$webroot" -C "$webroot" rev-parse HEAD)
tag=$(git -c safe.directory="$webroot" -C "$webroot" \
    describe --tags --exact-match)
[[ $tag == v4.6.32 ]]
[[ $commit == bcd755b140abbf72a19c2231360a82b3f3408a1f ]]

php_version=$(php --version | head -n 1)
[[ $php_version == 'PHP 8.4.'* ]]
for module in bcmath curl dom gd intl mbstring mysqli pdo_mysql xsl zip; do
    php -m | grep -Fxiq "$module"
done
[[ $(node --version) == v20.* ]]
[[ $(yarn --version) == 4.1.0 ]]
GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=safe.directory \
GIT_CONFIG_VALUE_0="$webroot" \
    composer --working-dir="$webroot" check-platform-reqs --no-dev
grep -Fxq '* * * * * www-data cd /var/www/ibexa && php bin/console ibexa:cron:run --quiet --env=prod' \
    /etc/cron.d/ibexa
runuser -u www-data -- sh -c \
    'cd /var/www/ibexa && php bin/console ibexa:cron:run --quiet --env=prod'

curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookie" "$base/login" >"$page"
token=$(sed -n 's/.*name="_csrf_token" value="\([^"]*\)".*/\1/p' \
    "$page" | head -n 1)
[[ -n $token ]]
curl --insecure --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" \
    --data-urlencode '_username=admin' \
    --data-urlencode "_password=$app_password" \
    --data-urlencode "_csrf_token=$token" \
    --dump-header "$headers" --output "$page" "$base/login_check"
grep -q '^HTTP/.* 302' "$headers"
grep -Fqi 'Location: https://localhost/' "$headers"
curl --insecure --fail --silent --show-error \
    --cookie "$cookie" "$base/" >"$page"
grep -Fqi 'Content structure' "$page"
grep -Fqi 'Dashboard' "$page"

export TKL_IBEXA_REMOTE_ID=$remote_id
export TKL_IBEXA_CONTENT_NAME=$content_name
(
    cd "$webroot"
    set +u
    set -a
    . ./.env
    set +a
    set -u
    php <<'PHP'
<?php
require 'vendor/autoload.php';

$kernel = new App\Kernel('prod', false);
$kernel->boot();
$repository = $kernel->getContainer()->get('ibexa.api.repository');
$repository->getPermissionResolver()->setCurrentUserReference(
    $repository->getUserService()->loadUser(14)
);
$contentService = $repository->getContentService();
$folderType = $repository->getContentTypeService()
    ->loadContentTypeByIdentifier('folder');
$create = $contentService->newContentCreateStruct($folderType, 'eng-GB');
$create->remoteId = getenv('TKL_IBEXA_REMOTE_ID');
$create->setField('name', getenv('TKL_IBEXA_CONTENT_NAME'));
$location = $repository->getLocationService()->newLocationCreateStruct(2);
$draft = $contentService->createContent($create, [$location]);
$published = $contentService->publishVersion($draft->versionInfo);
if ($published->contentInfo->remoteId !== getenv('TKL_IBEXA_REMOTE_ID')) {
    throw new RuntimeException('Published content remote ID did not match');
}
PHP
)

curl --insecure --fail --silent --show-error --location \
    --user "admin:$app_password" \
    --header 'Accept: application/vnd.ibexa.api.Content+json' \
    "$base/api/ibexa/v2/content/objects?remoteId=$remote_id" >"$page"
grep -Fq "\"_remoteId\":\"$remote_id\"" "$page"
grep -Fq "\"Name\":\"$content_name\"" "$page"
grep -Fq '"status":"PUBLISHED"' "$page"
MYSQL_PWD=$db_password mariadb --user=root --batch --skip-column-names \
    ibexa --execute \
    "SELECT COUNT(*) FROM ezcontentobject WHERE remote_id='$remote_id'" |
    grep -Fxq 1

dpkg-query -W adminer webmin-apache webmin-mysql webmin-phpini postfix \
    >/dev/null
curl --insecure --fail --silent --show-error --head \
    https://127.0.0.1:12321/ >/dev/null
curl --insecure --fail --silent --show-error --head \
    https://127.0.0.1:12322/ >/dev/null
ss -ltn | grep -Eq '127\.0\.0\.1:25[[:space:]]'

lock_before=$(sha256sum "$webroot/composer.lock")
candidate=$(git ls-remote --tags --refs \
    https://github.com/ibexa/oss-skeleton.git 'refs/tags/v4.6.*' |
    awk '$2 ~ /^refs\/tags\/v4\.6\.[0-9]+$/ {sub("refs/tags/", "", $2); print $2}' |
    sort -V | tail -n 1)
[[ -n $candidate ]]
[[ $(printf '%s\n%s\n' "$tag" "$candidate" | sort -V | tail -n 1) == \
    "$candidate" ]]
GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=safe.directory \
GIT_CONFIG_VALUE_0="$webroot" \
COMPOSER_NO_INTERACTION=1 \
    composer --working-dir="$webroot" outdated --direct --locked \
    --format=json >"$outdated"
GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=safe.directory \
GIT_CONFIG_VALUE_0="$webroot" \
    composer --working-dir="$webroot" show --locked ibexa/oss \
    --format=json >"$page"
grep -Fq 'ibexa/oss' "$page"
grep -Fq 'v4.6.32' "$page"
GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=safe.directory \
GIT_CONFIG_VALUE_0="$webroot" \
    composer --working-dir="$webroot" audit --locked --no-dev \
    --abandoned=ignore --format=summary
[[ $(sha256sum "$webroot/composer.lock") == "$lock_before" ]]

cat >"$result" <<EOF
package_source=Official Ibexa Open Source v4.6 LTS tag $tag at commit $commit; PHP, MariaDB, Apache, Composer, Node.js and Yarn from Debian Trixie
installed_version=Ibexa Open Source $tag ($commit); $php_version; MariaDB $(mariadb --version | head -n 1); Node.js $(node --version); Yarn $(yarn --version)
runtime_checks=normal init; Apache, MariaDB and Postfix supervision; installed and executed Ibexa scheduler command; firstboot administrator HTTPS login; repository API content create and publish; authenticated REST read; direct MariaDB persistence; Adminer and Webmin HTTPS endpoints
updater_command=Follow the Ibexa 4.6 supervised Composer update procedure; query the official oss-skeleton v4.6 tags and run composer outdated --direct --locked before maintenance
updater_result=official maintained v4.6 tag candidate $candidate discovered without changing composer.lock; Composer advisory audit reported no known vulnerability advisories
updater_channel=https://github.com/ibexa/oss-skeleton.git v4.6 release tags and https://repo.packagist.org locked Composer dependencies
integrity_evidence=installed Git tag and commit matched the build pins; Composer lock platform requirements passed; official v4.6 release discovery and Composer audit completed without mutating the lock file
EOF
