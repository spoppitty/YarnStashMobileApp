const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const logger = require('firebase-functions/logger');

const ravelryApiKey = defineSecret('RAVELRY_API_KEY');
const ravelryApiSecret = defineSecret('RAVELRY_API_SECRET');

const defaultBaseUrl = 'https://api.ravelry.com';
const maxPageSize = 50;

exports.ravelryYarnCatalog = onCall(
  {
    region: 'us-central1',
    invoker: 'public',
    secrets: [ravelryApiKey, ravelryApiSecret],
    timeoutSeconds: 30,
  },
  async (request) => {
    const data = request.data || {};
    switch (data.action) {
      case 'searchYarns':
        return searchYarns(data);
      case 'getYarn':
        return getYarn(data);
      default:
        throw new HttpsError(
          'invalid-argument',
          'Unsupported Ravelry catalog action.',
        );
    }
  },
);

async function searchYarns(data) {
  const query = cleanString(data.query);
  if (!query) {
    return {yarns: []};
  }

  const page = positiveInt(data.page, 1);
  const pageSize = Math.min(positiveInt(data.pageSize, 20), maxPageSize);
  const response = await getRavelryJson('/yarns/search.json', {
    query,
    page: page.toString(),
    page_size: pageSize.toString(),
  });

  return {yarns: Array.isArray(response.yarns) ? response.yarns : []};
}

async function getYarn(data) {
  const id = positiveInt(data.id, 0);
  if (id < 1) {
    throw new HttpsError('invalid-argument', 'A valid yarn id is required.');
  }

  const response = await getRavelryJson(`/yarns/${id}.json`);
  if (!response.yarn || typeof response.yarn !== 'object') {
    throw new HttpsError(
      'not-found',
      'Ravelry returned an unexpected yarn payload.',
    );
  }

  return {yarn: response.yarn};
}

async function getRavelryJson(path, queryParameters = {}) {
  const apiKey = cleanString(ravelryApiKey.value());
  const apiSecret = cleanString(ravelryApiSecret.value());
  if (!apiKey || !apiSecret) {
    throw new HttpsError(
      'failed-precondition',
      'Ravelry API credentials are not configured.',
    );
  }

  const url = new URL(path, `${defaultBaseUrl}/`);
  for (const [key, value] of Object.entries(queryParameters)) {
    url.searchParams.set(key, value);
  }

  let response;
  try {
    response = await fetch(url, {
      headers: {
        Accept: 'application/json',
        Authorization: basicAuthHeader(apiKey, apiSecret),
      },
    });
  } catch (error) {
    logger.error('Ravelry request failed before receiving a response.', error);
    throw new HttpsError(
      'unavailable',
      'Unable to reach the Ravelry API.',
    );
  }

  if (response.status === 401 || response.status === 403) {
    throw new HttpsError(
      'permission-denied',
      'Ravelry rejected the configured API credentials.',
    );
  }

  if (!response.ok) {
    logger.warn('Ravelry returned a non-success status.', {
      status: response.status,
      path,
    });
    throw new HttpsError(
      'unavailable',
      `Ravelry catalog request failed (${response.status}).`,
    );
  }

  const json = await response.json();
  if (!json || typeof json !== 'object' || Array.isArray(json)) {
    throw new HttpsError(
      'internal',
      'Ravelry returned an unexpected response.',
    );
  }

  return json;
}

function basicAuthHeader(username, password) {
  const token = Buffer.from(`${username}:${password}`).toString('base64');
  return `Basic ${token}`;
}

function cleanString(value) {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function positiveInt(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
