import { verifyRegistrationResponse } from '@simplewebauthn/server';

const readStdin = async () => {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
};

const toBase64Url = (buffer) =>
  Buffer.from(buffer)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');

const input = await readStdin();

try {
  const verification = await verifyRegistrationResponse({
    response: input.response,
    expectedChallenge: input.expectedChallenge,
    expectedOrigin: input.expectedOrigin,
    expectedRPID: input.expectedRPID,
  });

  const info = verification.registrationInfo;
  process.stdout.write(
    JSON.stringify({
      verified: verification.verified,
      registrationInfo: info
        ? {
            credentialID: info.credential.id,
            credentialPublicKey: toBase64Url(info.credential.publicKey),
            counter: info.credential.counter,
            transports: info.credential.transports || [],
            deviceType: info.credentialDeviceType,
            backedUp: info.credentialBackedUp,
          }
        : null,
    }),
  );
} catch (error) {
  process.stdout.write(
    JSON.stringify({
      verified: false,
      errorCode: error?.name || 'WebAuthnVerificationError',
      errorMessage: error?.message || 'WebAuthn verification failed',
    }),
  );
}
