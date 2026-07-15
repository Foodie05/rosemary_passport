import Dypnsapi, { CheckSmsVerifyCodeRequest } from '@alicloud/dypnsapi20170525';

async function readStdinJson() {
  let data = '';
  for await (const chunk of process.stdin) {
    data += chunk;
  }
  return JSON.parse(data || '{}');
}

function buildClient(payload) {
  return new Dypnsapi.default({
    accessKeyId: payload.accessKeyId,
    accessKeySecret: payload.accessKeySecret,
    endpoint: payload.endpoint || 'dypnsapi.aliyuncs.com',
    regionId: payload.regionId || 'cn-hangzhou',
  });
}

async function main() {
  const payload = await readStdinJson();
  const client = buildClient(payload);
  const request = new CheckSmsVerifyCodeRequest({
    countryCode: payload.countryCode || '86',
    phoneNumber: payload.phoneNumber,
    verifyCode: payload.verifyCode,
    outId: payload.outId,
    schemeName: payload.schemeName,
    caseAuthPolicy: payload.caseAuthPolicy || 1,
  });

  const response = await client.checkSmsVerifyCode(request);
  const body = response?.body ?? {};
  const model = body.model ?? {};
  process.stdout.write(
    JSON.stringify({
      success: body.success === true,
      code: body.code ?? '',
      message: body.message ?? '',
      verifyResult: model.verifyResult ?? '',
      outId: model.outId ?? '',
    }),
  );
}

main().catch((error) => {
  process.stdout.write(
    JSON.stringify({
      success: false,
      code: error?.code ?? error?.name ?? '',
      message: error?.message ?? `${error}`,
      statusCode: error?.statusCode ?? error?.status ?? '',
      requestId: error?.requestId ?? error?.data?.RequestId ?? '',
    }),
  );
});
