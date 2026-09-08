// Ephemeral, genuinely signed assertion for exercising the Dart verifier and
// the production SimpleWebAuthn helper together. No real credentials are used.
import { createHash, generateKeyPairSync, sign } from 'node:crypto';

const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const jwk = publicKey.export({ format: 'jwk' });
const cose = Buffer.concat([
  Buffer.from('a5010203262001215820', 'hex'), Buffer.from(jwk.x, 'base64url'),
  Buffer.from('225820', 'hex'), Buffer.from(jwk.y, 'base64url'),
]);
const challenge = Buffer.from('regression-test-challenge').toString('base64url');
const rpID = 'passport.example.invalid';
const clientData = Buffer.from(JSON.stringify({ type: 'webauthn.get', challenge, origin: `https://${rpID}` }));
const authenticatorData = Buffer.concat([
  createHash('sha256').update(rpID).digest(), Buffer.from('0500000008', 'hex'),
]);
const signature = sign('sha256', Buffer.concat([
  authenticatorData, createHash('sha256').update(clientData).digest(),
]), privateKey);
const id = Buffer.from('regression-credential').toString('base64url');
process.stdout.write(JSON.stringify({
  publicKey: cose.toString('base64url'), challenge,
  response: {
    id, rawId: id, type: 'public-key', clientExtensionResults: {},
    response: {
      clientDataJSON: clientData.toString('base64url'),
      authenticatorData: authenticatorData.toString('base64url'),
      signature: signature.toString('base64url'),
      userHandle: Buffer.from('user-id').toString('base64url'),
    },
  },
}));
