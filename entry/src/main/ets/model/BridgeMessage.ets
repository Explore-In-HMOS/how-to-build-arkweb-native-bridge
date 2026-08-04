export enum BridgePayloadKind {
  String = 'string',
  Number = 'number',
  ArrayBuffer = 'arrayBuffer',
  Error = 'error'
}

export interface BridgePushMessage {
  kind: BridgePayloadKind;
  heartRate: number;
  steps: number;
  label: string;
}

export interface BridgeInboundSummary {
  kind: BridgePayloadKind;
  detail: string;
}
