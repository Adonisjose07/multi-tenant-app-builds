import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const PACKAGE_ID_REGEX = /^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$/;
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const MIN_IMAGE_BYTES = 64;

/**
 * Validates an Android applicationId / package name against strict identifier rules
 * to prevent command/Gradle injection.
 * @param {string} appId
 * @returns {string}
 */
export function validatePackageId(appId) {
  if (typeof appId !== 'string' || !PACKAGE_ID_REGEX.test(appId.trim())) {
    throw new Error(
      `Invalid Android package ID "${appId}". Must match ${PACKAGE_ID_REGEX}`
    );
  }
  return appId.trim();
}

/**
 * Checks whether a hostname resolves to a private, loopback, or link-local address.
 * @param {string} hostname
 * @returns {boolean}
 */
function isPrivateOrLoopbackHost(hostname) {
  const host = hostname.toLowerCase().replace(/^\[|\]$/g, '');
  if (
    host === 'localhost' ||
    host.endsWith('.localhost') ||
    host.endsWith('.local') ||
    host.endsWith('.internal') ||
    host === '::1' ||
    host === '0:0:0:0:0:0:0:1' ||
    host === '0.0.0.0' ||
    host.startsWith('fe80:') ||
    host.startsWith('fc00:') ||
    host.startsWith('fd00:')
  ) {
    return true;
  }

  const ipv4Match = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (ipv4Match) {
    const [, a, b] = ipv4Match.map(Number);
    if (a === 127 || a === 10 || a === 0) return true;
    if (a === 169 && b === 254) return true;
    if (a === 192 && b === 168) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 100 && b >= 64 && b <= 127) return true;
  }

  return false;
}

/**
 * Validates a logo URL to enforce HTTPS and block SSRF to internal/loopback/metadata hosts.
 * @param {string} urlStr
 * @returns {URL}
 */
export function validateLogoUrl(urlStr) {
  if (typeof urlStr !== 'string' || !urlStr.trim()) {
    throw new Error('Logo URL must be a non-empty string');
  }
  let parsed;
  try {
    parsed = new URL(urlStr.trim());
  } catch {
    throw new Error(`Invalid Logo URL: "${urlStr}"`);
  }

  if (parsed.protocol !== 'https:') {
    throw new Error(
      `Logo URL must use HTTPS protocol (received "${parsed.protocol}")`
    );
  }

  if (isPrivateOrLoopbackHost(parsed.hostname)) {
    throw new Error(
      `Logo URL hostname "${parsed.hostname}" is forbidden (SSRF protection)`
    );
  }

  return parsed;
}

/**
 * Verifies PNG, JPEG, or WebP magic bytes and size bounds.
 * @param {Buffer | Uint8Array} buffer
 * @returns {'png' | 'jpeg' | 'webp'}
 */
export function verifyImageMagicBytes(buffer) {
  if (!buffer || typeof buffer.length !== 'number') {
    throw new Error('Image buffer is empty or invalid');
  }
  if (buffer.length < MIN_IMAGE_BYTES) {
    throw new Error(
      `Image buffer is too small (${buffer.length} bytes < ${MIN_IMAGE_BYTES} bytes)`
    );
  }
  if (buffer.length > MAX_IMAGE_BYTES) {
    throw new Error(
      `Image buffer exceeds maximum allowed size (${buffer.length} bytes > ${MAX_IMAGE_BYTES} bytes)`
    );
  }

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47
  ) {
    return 'png';
  }

  // JPEG: FF D8 FF
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return 'jpeg';
  }

  // WebP: "RIFF" .... "WEBP"
  if (
    buffer[0] === 0x52 &&
    buffer[1] === 0x49 &&
    buffer[2] === 0x46 &&
    buffer[3] === 0x46 &&
    buffer[8] === 0x57 &&
    buffer[9] === 0x45 &&
    buffer[10] === 0x42 &&
    buffer[11] === 0x50
  ) {
    return 'webp';
  }

  throw new Error(
    'Unsupported or corrupted image format: magic bytes must match PNG, JPEG, or WebP'
  );
}

/**
 * Generates a synthetic google-services.json string for white-label builds
 * when a custom Firebase secret is not provided.
 * @param {string} packageName
 * @returns {string}
 */
export function generateSyntheticFirebaseJson(
  packageName = 'com.multitenant.driver'
) {
  const validPkg = validatePackageId(packageName);
  const payload = {
    project_info: {
      project_number: '100000000000',
      project_id: 'multitenant-whitelabel-mock',
      storage_bucket: 'multitenant-whitelabel-mock.appspot.com',
    },
    client: [
      {
        client_info: {
          mobilesdk_app_id: '1:100000000000:android:1000000000000001',
          android_client_info: {
            package_name: validPkg,
          },
        },
        oauth_client: [],
        api_key: [
          {
            current_key: 'AIzaSyA00000000000000000000000000000000',
          },
        ],
        services: {
          appinvite_service: {
            other_platform_oauth_client: [],
          },
        },
      },
    ],
    configuration_version: '1',
  };
  return JSON.stringify(payload, null, 2);
}

/**
 * Writes android/app/google-services.json ensuring at least one client entry
 * matches the target appId so com.google.gms.google-services never fails on custom package IDs.
 * @param {string} appDir
 * @param {string} appId
 * @param {string} [firebaseJsonRaw]
 * @returns {string} Path to the written google-services.json
 */
export function injectFirebaseConfig(
  appDir,
  appId = 'com.multitenant.driver',
  firebaseJsonRaw = ''
) {
  const validPkg = validatePackageId(appId || 'com.multitenant.driver');
  const targetPath = path.join(appDir, 'android', 'app', 'google-services.json');
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });

  const trimmedRaw = typeof firebaseJsonRaw === 'string' ? firebaseJsonRaw.trim() : '';
  if (!trimmedRaw) {
    const synthetic = generateSyntheticFirebaseJson(validPkg);
    fs.writeFileSync(targetPath, synthetic, 'utf8');
    return targetPath;
  }

  let parsed;
  try {
    parsed = JSON.parse(trimmedRaw);
  } catch (err) {
    throw new Error(`Invalid FIREBASE_GOOGLE_SERVICES_JSON: ${err.message}`);
  }

  if (!Array.isArray(parsed.client) || parsed.client.length === 0) {
    parsed.client = JSON.parse(generateSyntheticFirebaseJson(validPkg)).client;
  } else {
    const hasMatch = parsed.client.some(
      (c) => c?.client_info?.android_client_info?.package_name === validPkg
    );
    if (!hasMatch) {
      const clonedClient = JSON.parse(JSON.stringify(parsed.client[0]));
      clonedClient.client_info = clonedClient.client_info || {};
      clonedClient.client_info.android_client_info =
        clonedClient.client_info.android_client_info || {};
      clonedClient.client_info.android_client_info.package_name = validPkg;
      parsed.client.push(clonedClient);
    }
  }

  fs.writeFileSync(targetPath, JSON.stringify(parsed, null, 2), 'utf8');
  return targetPath;
}

const MIPMAP_SIZES = {
  'mipmap-mdpi': '48x48',
  'mipmap-hdpi': '72x72',
  'mipmap-xhdpi': '96x96',
  'mipmap-xxhdpi': '144x144',
  'mipmap-xxxhdpi': '192x192',
};

/**
 * Downloads a tenant logo URL and applies it to assets/brand/logo.png and Android mipmap launcher icons.
 * @param {string} appDir
 * @param {string} logoUrl
 */
export async function downloadAndApplyLogo(appDir, logoUrl) {
  const parsedUrl = validateLogoUrl(logoUrl);
  const response = await fetch(parsedUrl.toString(), {
    signal: AbortSignal.timeout(15000),
    redirect: 'error',
  });

  if (!response.ok) {
    throw new Error(
      `Failed to download logo from ${parsedUrl.toString()}: HTTP ${response.status}`
    );
  }

  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);
  verifyImageMagicBytes(buffer);

  const brandDir = path.join(appDir, 'assets', 'brand');
  fs.mkdirSync(brandDir, { recursive: true });
  const downloadedLogoPath = path.join(brandDir, 'logo.png');
  fs.writeFileSync(downloadedLogoPath, buffer);

  const resDir = path.join(appDir, 'android', 'app', 'src', 'main', 'res');
  if (fs.existsSync(resDir)) {
    for (const [folder, size] of Object.entries(MIPMAP_SIZES)) {
      const mipmapDir = path.join(resDir, folder);
      if (!fs.existsSync(mipmapDir)) continue;
      const targetIcon = path.join(mipmapDir, 'ic_launcher.png');
      try {
        execFileSync('convert', [
          downloadedLogoPath,
          '-resize',
          size,
          targetIcon,
        ]);
      } catch {
        fs.copyFileSync(downloadedLogoPath, targetIcon);
      }
    }
  }

  return downloadedLogoPath;
}

function parseCliArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (token.startsWith('--')) {
      const key = token.slice(2);
      const next = argv[i + 1];
      if (next !== undefined && !next.startsWith('--')) {
        args[key] = next;
        i++;
      } else {
        args[key] = 'true';
      }
    }
  }
  return args;
}

async function runCli() {
  const args = parseCliArgs(process.argv.slice(2));
  const appDir = path.resolve(args['app-dir'] || process.cwd());
  const rawAppId =
    args['app-id'] || process.env.ANDROID_APP_ID || 'com.multitenant.app';
  const appId = validatePackageId(rawAppId);
  const logoUrl = (args['logo-url'] ?? process.env.BRAND_LOGO_URL ?? '').trim();
  const requireFirebase =
    args['require-firebase'] === 'true' ||
    process.env.REQUIRE_FIREBASE === 'true';

  if (requireFirebase) {
    const firebaseRaw = process.env.FIREBASE_GOOGLE_SERVICES_JSON || '';
    const outPath = injectFirebaseConfig(appDir, appId, firebaseRaw);
    console.log(
      `[apply-brand-assets] Configured Firebase config for package "${appId}" at ${outPath}`
    );
  }

  if (logoUrl) {
    const savedLogo = await downloadAndApplyLogo(appDir, logoUrl);
    console.log(`[apply-brand-assets] Applied custom brand logo: ${savedLogo}`);
  } else {
    console.log(
      '[apply-brand-assets] No custom logo URL provided; keeping default icons.'
    );
  }
}

const currentFilePath = fileURLToPath(import.meta.url);
if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(currentFilePath)
) {
  runCli().catch((err) => {
    console.error(`[apply-brand-assets] ERROR: ${err.message}`);
    process.exit(1);
  });
}
