import { generateAuthenticationOptions } from '@simplewebauthn/server';

const readStdin = async () => {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
};

const input = await readStdin();

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

const options = await generateAuthenticationOptions({
  rpID: input.rpID,
  userVerification: 'preferred',
  allowCredentials: (input.allowCredentials || input.allowCredentialIDs || [])
    .map(credentialDescriptor),
});

if (Array.isArray(options.allowCredentials)) {
  options.allowCredentials = options.allowCredentials.map(credentialDescriptor);
}

process.stdout.write(JSON.stringify(options));
