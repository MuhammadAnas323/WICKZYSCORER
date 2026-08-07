const functions = require('firebase-functions');
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
