import Captcha, {
  VerifyIntelligentCaptchaRequest,
} from '@alicloud/captcha20230305';

async function readStdinJson() {
  let data = '';
  for await (const chunk of process.stdin) {
    data += chunk;
  }
  return JSON.parse(data || '{}');
}

async function main() {
  const payload = await readStdinJson();
  const client = new Captcha.default({
    accessKeyId: payload.accessKeyId,
    accessKeySecret: payload.accessKeySecret,
    endpoint: payload.endpoint || 'captcha.cn-shanghai.aliyuncs.com',
  });
  const request = new VerifyIntelligentCaptchaRequest({
    sceneId: payload.sceneId,
    captchaVerifyParam: payload.captchaVerifyParam,
  });

  const response = await client.verifyIntelligentCaptcha(request);
  const body = response?.body ?? {};
  const result = body.result ?? {};
  process.stdout.write(
    JSON.stringify({
      success: body.success === true,
      code: body.code ?? '',
      message: body.message ?? '',
      requestId: body.requestId ?? '',
      verifyResult: result.verifyResult === true,
      verifyCode: result.verifyCode ?? '',
      certifyId: result.certifyId ?? '',
    }),
  );
}

main().catch((error) => {
  process.stderr.write(`${error?.stack || error}`);
  process.exit(1);
});
