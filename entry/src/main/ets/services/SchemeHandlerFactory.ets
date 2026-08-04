import { webview, WebNetErrorList } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { MockSensorService } from './MockSensorService';

const CORS_ORIGIN: string = 'Access-Control-Allow-Origin';

function toArrayBuffer(text: string): ArrayBuffer {
  const bytes: Uint8Array = new util.TextEncoder().encodeInto(text);
  const out: ArrayBuffer = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(out).set(bytes);
  return out;
}

function serveJson(handler: webview.WebResourceHandler, json: string): void {
  try {
    const response: webview.WebSchemeHandlerResponse = new webview.WebSchemeHandlerResponse();
    response.setStatus(200);
    response.setStatusText('OK');
    response.setMimeType('application/json');
    response.setEncoding('utf-8');
    response.setHeaderByName(CORS_ORIGIN, '*', false);
    response.setHeaderByName('Cache-Control', 'no-store', false);
    handler.didReceiveResponse(response);
    handler.didReceiveResponseBody(toArrayBuffer(json));
    handler.didFinish();
  } catch (err) {
    const e = err as BusinessError;
    console.error(`[scheme] serveJson failed code=${e.code} msg=${e.message}`);
  }
}

function serveNotFound(handler: webview.WebResourceHandler, path: string): void {
  try {
    const response: webview.WebSchemeHandlerResponse = new webview.WebSchemeHandlerResponse();
    response.setStatus(404);
    response.setStatusText('Not Found');
    response.setMimeType('application/json');
    response.setEncoding('utf-8');
    response.setHeaderByName(CORS_ORIGIN, '*', false);
    handler.didReceiveResponse(response);
    // completeIfNoResponse=false: the 404 header above is used, then the request fails.
    handler.didFail(WebNetErrorList.ERR_FILE_NOT_FOUND, false);
    console.info(`[scheme] 404 for path="${path}"`);
  } catch (err) {
    const e = err as BusinessError;
    console.error(`[scheme] serveNotFound failed code=${e.code} msg=${e.message}`);
  }
}

export function createWearableSchemeHandler(sensor: MockSensorService): webview.WebSchemeHandler {
  const schemeHandler: webview.WebSchemeHandler = new webview.WebSchemeHandler();

  schemeHandler.onRequestStart(
    (request: webview.WebSchemeHandlerRequest, handler: webview.WebResourceHandler): boolean => {
      const url: string = request.getRequestUrl();
      if (url.includes('/sensor') || url.endsWith('sensor')) {
        serveJson(handler, sensor.snapshotJson());
      } else {
        serveNotFound(handler, url);
      }
      return true;
    }
  );

  schemeHandler.onRequestStop((request: webview.WebSchemeHandlerRequest) => {
    console.info(`[scheme] onRequestStop url=${request.getRequestUrl()}`);
  });

  return schemeHandler;
}
