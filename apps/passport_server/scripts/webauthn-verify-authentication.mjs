import { verifyAuthenticationResponse } from '@simplewebauthn/server';

const readStdin = async () => {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
};

const fromBase64Url = (value) =>
  Buffer.from(value.replace(/-/g, '+').replace(/_/g, '/'), 'base64');

const input = await readStdin();

try {
  const verification = await verifyAuthenticationResponse({
    response: input.response,
    expectedChallenge: input.expectedChallenge,
    expectedOrigin: input.expectedOrigin,
    expectedRPID: input.expectedRPID,
    requireUserVerification: input.requireUserVerification === true,
    credential: {
      id: input.credential.id,
      publicKey: fromBase64Url(input.credential.publicKey),
      counter: input.credential.counter,
      transports: input.credential.transports || [],
    },
  });

  const info = verification.authenticationInfo;
  process.stdout.write(
    JSON.stringify({
      verified: verification.verified,
      authenticationInfo: info
        ? {
            newCounter: info.newCounter,
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
