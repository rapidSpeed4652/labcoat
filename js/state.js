// ============================================================
// RETRO-REFLECTOR — Game State
// ============================================================

export class GameState {
  constructor() {
    this.reset();
  }

  reset() {
    this.started = false;
    this.paused = false;
    this.dead = false;
    this.dialogueActive = false;
    this.currentAct = 1;
    this.health = 100;
    this.laserHeat = 0;         // 0-100
    this.laserOverheated = false;
    this.laserFiring = false;
    this.portableMirrors = 0;
    this.entitiesBanished = 0;
    this.keysCollected = new Set();
    this.doorsOpened = new Set();
    this.triggersActivated = new Set();
    this.actCompleted = [false, false, false];
    this.totalPlayTime = 0;

    // Act 3 specific
    this.reflectorsAligned = 0;
    this.shutterClosed = false;
  }
}
