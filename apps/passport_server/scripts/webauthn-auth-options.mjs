import { generateAuthenticationOptions } from '@simplewebauthn/server';

const readStdin = async () => {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
};

const input = await readStdin();

const options = await generateAuthenticationOptions({
  rpID: input.rpID,
  userVerification: 'preferred',
  allowCredentials: (input.allowCredentialIDs || []).map((id) => ({
    id,
    type: 'public-key',
  })),
});

process.stdout.write(JSON.stringify(options));
