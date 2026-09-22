<?php
declare(strict_types=1);

use Doctrine\DBAL\Connection;
use Doctrine\DBAL\DriverManager;
use Symfony\Component\Dotenv\Dotenv;

function normalizedBaseUrl(string $url): string
{
    $url = rtrim(trim($url), '/');
    $parts = parse_url($url);

    if (!$parts || !in_array($parts['scheme'] ?? '', ['http', 'https'], true) || empty($parts['host'])) {
        throw new RuntimeException('Expected an absolute HTTP(S) URL.');
    }

    return $url;
}

function relativeSalesChannelPath(string $url, string $baseUrl): ?string
{
    $urlParts = parse_url($url);
    $baseParts = parse_url($baseUrl);

    if (!$urlParts || !$baseParts || empty($urlParts['host']) || empty($baseParts['host'])) {
        return null;
    }

    if (strcasecmp((string) $urlParts['host'], (string) $baseParts['host']) !== 0) {
        return null;
    }

    $urlPath = rtrim((string) ($urlParts['path'] ?? ''), '/');
    $basePath = rtrim((string) ($baseParts['path'] ?? ''), '/');

    if ($urlPath === $basePath) {
        return '';
    }

    if ($basePath === '') {
        return $urlPath;
    }

    if (str_starts_with($urlPath, $basePath . '/')) {
        return substr($urlPath, strlen($basePath));
    }

    return null;
}

function insertInternalDomainCopy(Connection $connection, string $sourceId, string $internalUrl): bool
{
    if ($connection->fetchOne('SELECT 1 FROM sales_channel_domain WHERE url = ?', [$internalUrl])) {
        return false;
    }

    $source = $connection->fetchAssociative(
        'SELECT * FROM sales_channel_domain WHERE id = UNHEX(?)',
        [$sourceId]
    );

    if (!$source) {
        throw new RuntimeException('Source sales-channel domain disappeared during provisioning.');
    }

    $columns = $connection->fetchAllAssociative('SHOW FULL COLUMNS FROM sales_channel_domain');
    $insert = [];

    foreach ($columns as $column) {
        $name = (string) $column['Field'];
        $extra = (string) ($column['Extra'] ?? '');

        if (stripos($extra, 'GENERATED') !== false) {
            continue;
        }

        if ($name === 'id') {
            $insert[$name] = md5("aggro-internal-domain\0" . $sourceId . "\0" . $internalUrl, true);
            continue;
        }

        if ($name === 'url') {
            $insert[$name] = $internalUrl;
            continue;
        }

        if ($name === 'is_external_storefront') {
            $insert[$name] = 0;
            continue;
        }

        $insert[$name] = $source[$name] ?? null;
    }

    $tick = chr(96);
    $quotedColumns = array_map(
        static fn (string $column): string => $tick . str_replace($tick, $tick . $tick, $column) . $tick,
        array_keys($insert)
    );
    $placeholders = array_fill(0, count($insert), '?');

    $connection->executeStatement(
        sprintf(
            'INSERT INTO sales_channel_domain (%s) VALUES (%s)',
            implode(', ', $quotedColumns),
            implode(', ', $placeholders)
        ),
        array_values($insert)
    );

    return true;
}

function ensureInternalSalesChannelDomains(
    string $projectRoot,
    string $externalBaseUrl,
    string $internalBaseUrl
): array {
    $projectRoot = rtrim($projectRoot, '/');
    $externalBaseUrl = normalizedBaseUrl($externalBaseUrl);
    $internalBaseUrl = normalizedBaseUrl($internalBaseUrl);

    $autoload = $projectRoot . '/vendor/autoload.php';
    if (!is_file($autoload)) {
        throw new RuntimeException('Shopware autoloader is missing.');
    }

    require_once $autoload;

    if (class_exists(Dotenv::class) && is_file($projectRoot . '/.env')) {
        (new Dotenv())->usePutenv()->bootEnv($projectRoot . '/.env');
    }

    $databaseUrl = $_SERVER['DATABASE_URL']
        ?? $_ENV['DATABASE_URL']
        ?? getenv('DATABASE_URL');

    if (!is_string($databaseUrl) || $databaseUrl === '') {
        throw new RuntimeException('DATABASE_URL is not available.');
    }

    $connection = DriverManager::getConnection(['url' => $databaseUrl]);
    $rows = $connection->fetchAllAssociative(
        'SELECT LOWER(HEX(id)) AS id, url FROM sales_channel_domain ORDER BY url'
    );

    $created = [];
    $matched = 0;

    foreach ($rows as $row) {
        $relativePath = relativeSalesChannelPath((string) $row['url'], $externalBaseUrl);
        if ($relativePath === null) {
            continue;
        }

        ++$matched;
        $internalUrl = $internalBaseUrl . $relativePath;

        if (insertInternalDomainCopy($connection, (string) $row['id'], $internalUrl)) {
            $created[] = $internalUrl;
        }
    }

    if ($matched === 0) {
        throw new RuntimeException(
            sprintf('No sales-channel domain matches the external base URL %s.', $externalBaseUrl)
        );
    }

    return $created;
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    try {
        $projectRoot = $argv[1] ?? '/var/www/html';
        $externalBaseUrl = $argv[2] ?? '';
        $internalBaseUrl = $argv[3] ?? 'http://shop';

        $created = ensureInternalSalesChannelDomains(
            $projectRoot,
            $externalBaseUrl,
            $internalBaseUrl
        );

        foreach ($created as $url) {
            fwrite(STDOUT, "Added internal sales-channel domain: {$url}\n");
        }

        if ($created === []) {
            fwrite(STDOUT, "Internal sales-channel domains already present.\n");
        }
    } catch (Throwable $error) {
        fwrite(STDERR, 'Internal sales-channel domain provisioning failed: ' . $error->getMessage() . "\n");
        exit(1);
    }
}
