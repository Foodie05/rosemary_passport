import { generateRegistrationOptions } from '@simplewebauthn/server';

const readStdin = async () => {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
};

const input = await readStdin();
const userID = Uint8Array.from(Buffer.from(input.userID, 'utf8'));

const credentialDescriptor = (credential) => {
  if (typeof credential === 'string') {
    return {
      id: credential,
      type: 'public-key',
      transports: [],
    };
  }
  return {
    id: credential.id,
    type: credential.type || 'public-key',
    transports: Array.isArray(credential.transports) ? credential.transports : [],
  };
};

const options = await generateRegistrationOptions({
  rpName: input.rpName,
  rpID: input.rpID,
  userID,
  userName: input.userName,
  userDisplayName: input.userDisplayName,
  attestationType: 'none',
  authenticatorSelection: {
    residentKey: 'preferred',
    userVerification: 'preferred',
  },
  excludeCredentials: (input.excludeCredentials || input.excludeCredentialIDs || [])
    .map(credentialDescriptor),
});

if (Array.isArray(options.excludeCredentials)) {
  options.excludeCredentials = options.excludeCredentials.map(credentialDescriptor);
}

process.stdout.write(JSON.stringify(options));
