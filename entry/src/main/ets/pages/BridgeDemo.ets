import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { MockSensorService } from '../services/MockSensorService';
import { createWearableSchemeHandler } from '../services/SchemeHandlerFactory';
import { BridgePushMessage, BridgeInboundSummary, BridgePayloadKind } from '../model/BridgeMessage';

@Entry
@Component
struct BridgeDemo {
  private controller: webview.WebviewController = new webview.WebviewController();
  private sensor: MockSensorService = new MockSensorService();
  private nativePort: webview.WebMessagePort | null = null;
  private ports: webview.WebMessagePort[] = [];
  private pushTimer: number = -1;
  private schemeHandler: webview.WebSchemeHandler = createWearableSchemeHandler(this.sensor);
  private static schemesRegistered: boolean = false;

  aboutToAppear(): void {
    if (BridgeDemo.schemesRegistered) {
      return;
    }
    try {
      const scheme: webview.WebCustomScheme =
        { schemeName: 'wearable', isSupportCORS: true, isSupportFetch: true };
      webview.WebviewController.customizeSchemes([scheme]);
      BridgeDemo.schemesRegistered = true;
    } catch (err) {
      const e = err as BusinessError;
      console.error(`[scheme] customizeSchemes failed code=${e.code} msg=${e.message}`);
    }
  }

  private pushLiveValues(): void {
    if (this.nativePort === null) {
      return;
    }
    try {
      const snap: BridgePushMessage = this.sensor.push();

      const hrMsg: webview.WebMessageExt = new webview.WebMessageExt();
      hrMsg.setType(webview.WebMessageType.NUMBER);
      hrMsg.setNumber(snap.heartRate);
      this.nativePort.postMessageEventExt(hrMsg);

      const labelMsg: webview.WebMessageExt = new webview.WebMessageExt();
      labelMsg.setType(webview.WebMessageType.STRING);
      labelMsg.setString(`live:${snap.label} • ${snap.steps} steps`);
      this.nativePort.postMessageEventExt(labelMsg);
    } catch (err) {
      const e = err as BusinessError;
      console.error(`[bridge] push failed code=${e.code} msg=${e.message}`);
    }
  }

  private echoAck(detail: string): void {
    if (this.nativePort === null) {
      return;
    }
    try {
      const ack: webview.WebMessageExt = new webview.WebMessageExt();
      ack.setType(webview.WebMessageType.STRING);
      ack.setString(`ack:${detail}`);
      this.nativePort.postMessageEventExt(ack);
    } catch (err) {
      const e = err as BusinessError;
      console.error(`[bridge] ack failed code=${e.code} msg=${e.message}`);
    }
  }

  private summarize(result: webview.WebMessageExt): BridgeInboundSummary {
    try {
      const type: webview.WebMessageType = result.getType();
      switch (type) {
        case webview.WebMessageType.STRING:
          return { kind: BridgePayloadKind.String, detail: `string="${result.getString()}"` };
        case webview.WebMessageType.NUMBER:
          return { kind: BridgePayloadKind.Number, detail: `number=${result.getNumber()}` };
        case webview.WebMessageType.ARRAY_BUFFER:
          return {
            kind: BridgePayloadKind.ArrayBuffer,
            detail: `arrayBuffer byteLength=${result.getArrayBuffer().byteLength}`
          };
        case webview.WebMessageType.ERROR: {
          const err: Error = result.getError();
          return { kind: BridgePayloadKind.Error, detail: `error ${err.name}: ${err.message}` };
        }
        default:
          return { kind: BridgePayloadKind.String, detail: `unhandled type=${type}` };
      }
    } catch (err) {
      const e = err as BusinessError;
      return { kind: BridgePayloadKind.Error, detail: `parse failed code=${e.code}` };
    }
  }

  private handleInbound(result: webview.WebMessageExt): void {
    const summary: BridgeInboundSummary = this.summarize(result);
    console.info(`[bridge] inbound ${summary.kind} ${summary.detail}`);
    this.echoAck(summary.detail);
  }

  private openChannel(): void {
    if (this.nativePort !== null) {
      try {
        this.nativePort.close();
      } catch (err) {
        const e = err as BusinessError;
        console.error(`[bridge] stale port close failed code=${e.code} msg=${e.message}`);
      }
      this.nativePort = null;
    }
    try {
      this.ports = this.controller.createWebMessagePorts(true);
      this.controller.postMessage('__init_port__', [this.ports[0]], '*');
      this.nativePort = this.ports[1];
      this.nativePort.onMessageEventExt((result: webview.WebMessageExt) => {
        this.handleInbound(result);
      });

      if (this.pushTimer === -1) {
        this.pushTimer = setInterval(() => {
          this.pushLiveValues();
        }, 1000);
      }
    } catch (err) {
      const e = err as BusinessError;
      console.error(`[bridge] channel open failed code=${e.code} msg=${e.message}`);
    }
  }

  private teardown(): void {
    if (this.pushTimer !== -1) {
      clearInterval(this.pushTimer);
      this.pushTimer = -1;
    }
    try {
      if (this.nativePort !== null) {
        this.nativePort.close();
        this.nativePort = null;
      }
      this.controller.clearWebSchemeHandler();
    } catch (err) {
      const e = err as BusinessError;
      console.error(`[bridge] teardown failed code=${e.code} msg=${e.message}`);
    }
  }

  aboutToDisappear(): void {
    this.teardown();
  }

  build() {
    Column() {
      Web({ src: $rawfile('index.html'), controller: this.controller })
        .geolocationAccess(false)
        .fileAccess(true)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .width('100%')
        .height('100%')
        .onControllerAttached(() => {
          try {
            this.controller.setWebSchemeHandler('wearable', this.schemeHandler);
          } catch (err) {
            const e = err as BusinessError;
            console.error(`[scheme] setWebSchemeHandler failed code=${e.code} msg=${e.message}`);
          }
        })
        .onPageEnd(() => {
          this.openChannel();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
