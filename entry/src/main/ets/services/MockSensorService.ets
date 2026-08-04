import { BridgePushMessage, BridgePayloadKind } from '../model/BridgeMessage';

interface SensorSnapshot {
  heartRate: number;
  steps: number;
  label: string;
}

export class MockSensorService {
  private tick: number = 0;

  nextHeartRate(): number {
    this.tick++;
    const wave: number = Math.sin(this.tick / 4) * 12;
    return Math.round(72 + wave);
  }

  // Monotonically increasing step count, 7 steps per tick.
  nextSteps(): number {
    return 1000 + this.tick * 7;
  }

  label(): string {
    return `sample #${this.tick}`;
  }

  push(): BridgePushMessage {
    const heartRate: number = this.nextHeartRate();
    return {
      kind: BridgePayloadKind.Number,
      heartRate,
      steps: this.nextSteps(),
      label: this.label()
    };
  }

  snapshotJson(): string {
    const snapshot: SensorSnapshot = {
      heartRate: this.nextHeartRate(),
      steps: this.nextSteps(),
      label: this.label()
    };
    return JSON.stringify(snapshot);
  }
}
