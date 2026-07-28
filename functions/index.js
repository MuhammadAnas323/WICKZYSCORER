const functions = require('firebase-functions');
const axios = require('axios');
const { URL } = require('url');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const AGORA_APP_ID = '12982bdfadab4b378b96d4a6cb0bf604';

/*
 * SETUP INSTRUCTIONS FOR AGORA TOKEN GENERATION:
 * 
 * Before deploying this function, you MUST set your Agora App Certificate in Firebase config:
 * 
 *   firebase functions:config:set agora.certificate="YOUR_AGORA_APP_CERTIFICATE"
 * 
 * To obtain your Agora App Certificate:
 *   1. Log into Agora Console: https://console.agora.io
 *   2. Navigate to Project Management -> Click 'Edit' on your project.
 *   3. Copy the 'App Certificate' value.
 *   4. Run the command above in your terminal, then deploy with:
 *      firebase deploy --only functions
 */
exports.generateAgoraToken = functions.https.onCall(async (data, context) => {
  const channelName = data?.channelName?.trim();
  const uid = data?.uid;

  if (!channelName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'channelName is required to generate an Agora RTC token.'
    );
  }

  // Read certificate from Firebase Functions config
  const appCertificate = functions.config()?.agora?.certificate || process.env.AGORA_CERTIFICATE;

  if (!appCertificate) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Agora App Certificate is not configured in Firebase Functions config. Set it using: firebase functions:config:set agora.certificate="YOUR_APP_CERTIFICATE"'
    );
  }

  const numericUid = (typeof uid === 'number' && !isNaN(uid)) ? uid : 0;
  const role = RtcRole.PUBLISHER;
  const expirationTimeInSeconds = 3600;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  try {
    const token = RtcTokenBuilder.buildTokenWithUid(
      AGORA_APP_ID,
      appCertificate,
      channelName,
      numericUid,
      role,
      privilegeExpiredTs
    );

    return { token };
  } catch (error) {
    console.error('Error generating Agora token:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to generate Agora token: ${error.message || error}`
    );
  }
});

const VALID_EXTENSIONS = ['.m3u8', '.mpd', '.mp4'];
const FETCH_TIMEOUT_MS = 15000;
const MAX_RESPONSE_SIZE = 2 * 1024 * 1024;

function isValidUrl(string) {
  try {
    const url = new URL(string);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}

function normalizeUrl(base, href) {
  try {
    return new URL(href, base).toString();
  } catch {
    return null;
  }
}

function extractStreamUrls(html, pageUrl) {
  const found = [];
  const seen = new Set();

  const patterns = [
    // <video src="...">
    /<video[^>]*\ssrc=["']([^"']+\.(?:m3u8|mpd|mp4)[^"']*)["']/gi,
    // <source src="...">
    /<source[^>]*\ssrc=["']([^"']+\.(?:m3u8|mpd|mp4)[^"']*)["']/gi,
    // <video><source> nested
    /<video[^>]*>[\s\S]*?<source[^>]*\ssrc=["']([^"']+\.(?:m3u8|mpd|mp4)[^"']*)["']/gi,
    // og:video / og:video:url
    /<meta[^>]+content=["']([^"']+\.(?:m3u8|mpd|mp4)[^"']*)["'][^>]+property=["'](?:og:video(?::url)?|twitter:player)["']/gi,
    // JSON-LD structured data
    /"contentUrl"\s*:\s*"([^"']+\.(?:m3u8|mpd|mp4)[^"']*)"/gi,
    /"url"\s*:\s*"([^"']+\.(?:m3u8|mpd|mp4)[^"']*)"/gi,
    /"embedUrl"\s*:\s*"([^"']+\.(?:m3u8|mpd|mp4)[^"']*)"/gi,
    // Plain URL references in the page (e.g. in scripts, configs)
    /(?:https?:\/\/[^"'\s<>]+\.(?:m3u8|mpd|mp4)(?:[^"'\s<>]*)?)/gi,
    // HLS player initialization
    /["'](?:file|url|source|src)["']\s*[:=]\s*["']([^"']+\.(?:m3u8|mpd|mp4)[^"']*)["']/gi,
  ];

  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(html)) !== null) {
      const rawUrl = match[1] || match[0];
      if (!rawUrl) continue;

      const normalized = normalizeUrl(pageUrl, rawUrl);
      if (normalized && !seen.has(normalized)) {
        seen.add(normalized);
        const ext = VALID_EXTENSIONS.find(e => normalized.toLowerCase().endsWith(e));
        found.push({
          url: normalized,
          format: ext ? ext.substring(1) : 'unknown',
        });
      }
    }
  }

  return found;
}

exports.resolveVideoSource = functions.https.onCall(async (data, context) => {
  const url = data?.url?.trim();

  if (!url) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'A URL is required.'
    );
  }

  if (!isValidUrl(url)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'The provided URL is not valid. Only HTTP and HTTPS URLs are supported.'
    );
  }

  try {
    const response = await axios.get(url, {
      timeout: FETCH_TIMEOUT_MS,
      maxContentLength: MAX_RESPONSE_SIZE,
      responseType: 'text',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      },
      validateStatus: (status) => status < 400,
    });

    const html = response.data;
    if (!html || typeof html !== 'string') {
      return {
        success: false,
        message: 'The page returned no content.',
      };
    }

    const streams = extractStreamUrls(html, url);

    if (streams.length === 0) {
      return {
        success: false,
        message: 'No public stream URL found on the page.',
        detail: 'Searched in video tags, source tags, meta tags, JSON-LD, and script configs.',
      };
    }

    return {
      success: true,
      message: `Found ${streams.length} public stream URL(s).`,
      streams: streams,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    if (error.code === 'ECONNABORTED' || error.message?.includes('timeout')) {
      throw new functions.https.HttpsError(
        'deadline-exceeded',
        'The request to the URL timed out. The page may be too slow or unreachable.'
      );
    }

    if (error.response) {
      const status = error.response.status;
      if (status === 403) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'The page blocked the request (HTTP 403). It may require authentication.'
        );
      }
      if (status === 404) {
        throw new functions.https.HttpsError(
          'not-found',
          'The page was not found (HTTP 404).'
        );
      }
      throw new functions.https.HttpsError(
        'unavailable',
        `The page returned HTTP ${status}.`
      );
    }

    if (error.code === 'ENOTFOUND' || error.code === 'EAI_AGAIN') {
      throw new functions.https.HttpsError(
        'unavailable',
        'Could not reach the server. The domain may not exist or is unreachable.'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      'An unexpected error occurred while resolving the video source.'
    );
  }
});
