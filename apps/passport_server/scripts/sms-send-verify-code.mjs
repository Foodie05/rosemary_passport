import Dypnsapi, { SendSmsVerifyCodeRequest } from '@alicloud/dypnsapi20170525';

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
  const request = new SendSmsVerifyCodeRequest({
    countryCode: payload.countryCode || '86',
    phoneNumber: payload.phoneNumber,
    signName: payload.signName,
    templateCode: payload.templateCode,
    templateParam: payload.templateParam,
    codeLength: payload.codeLength,
    validTime: payload.validTime,
    interval: payload.interval,
    duplicatePolicy: payload.duplicatePolicy,
    outId: payload.outId,
    schemeName: payload.schemeName,
    codeType: payload.codeType || 1,
    returnVerifyCode: false,
    autoRetry: 1,
  });

  const response = await client.sendSmsVerifyCode(request);
  const body = response?.body ?? {};
  const model = body.model ?? {};
  process.stdout.write(
    JSON.stringify({
      success: body.success === true,
      code: body.code ?? '',
      message: body.message ?? '',
      bizId: model.bizId ?? '',
      outId: model.outId ?? '',
      requestId: body.requestId ?? model.requestId ?? '',
    }),
  );
}

main().catch((error) => {
  process.stderr.write(`${error?.stack || error}`);
  process.exit(1);
});
