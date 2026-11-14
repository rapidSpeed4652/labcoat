// ============================================================
// RETRO-REFLECTOR — Main Entry Point & Game Loop
// ============================================================
import * as THREE from 'three';
import { PointerLockControls } from 'three/addons/controls/PointerLockControls.js';
import { Player } from './player.js';
import { LaserSystem } from './laser.js';
import { EntityManager } from './entities.js';
import { buildAct1 } from './levels/act1.js';
import { buildAct2 } from './levels/act2.js';
import { buildAct3 } from './levels/act3.js';
import { UIManager } from './ui.js';
import { AudioManager } from './audio.js';
import { GameState } from './state.js';

// ---- Globals ----
const clock = new THREE.Clock();
let renderer, scene, camera, controls;
let player, laserSystem, entityManager, uiManager, audioManager, gameState;
let currentLevel = null;

// ---- Initialize ----
async function init() {
  // Renderer
  renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: 'high-performance' });
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.3;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  document.getElementById('game-container').appendChild(renderer.domElement);

  // Scene
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x000000);
  scene.fog = new THREE.FogExp2(0x000000, 0.06);

  // Camera
  camera = new THREE.PerspectiveCamera(70, window.innerWidth / window.innerHeight, 0.1, 200);
  camera.position.set(0, 1.7, 0);

  // Pointer Lock Controls
  controls = new PointerLockControls(camera, renderer.domElement);

  // Systems
  gameState = new GameState();
  uiManager = new UIManager(gameState);
  audioManager = new AudioManager();
  player = new Player(camera, controls, gameState, audioManager);
  laserSystem = new LaserSystem(scene, camera, gameState, audioManager);
  entityManager = new EntityManager(scene, gameState, audioManager, player);

  // Update loading
  uiManager.setLoadingProgress(50);

  // Resize handler
  window.addEventListener('resize', onResize);

  // Setup input
  setupInput();

  // Preload
  await audioManager.init();
  uiManager.setLoadingProgress(100);

  // Show title after short delay
  setTimeout(() => {
    document.getElementById('loading-screen').classList.add('hidden');
    document.getElementById('title-screen').classList.remove('hidden');
  }, 800);
}

function setupInput() {
  // Title screen click
  document.getElementById('start-btn').addEventListener('click', startGame);
  document.getElementById('title-screen').addEventListener('click', startGame);

  // Restart
  document.getElementById('restart-btn').addEventListener('click', () => restartCurrentAct());
  document.getElementById('replay-btn').addEventListener('click', () => {
    document.getElementById('ending-screen').classList.add('hidden');
    startGame();
  });

  // Pointer lock change
  document.addEventListener('pointerlockchange', () => {
    if (document.pointerLockElement === renderer.domElement) {
      gameState.paused = false;
    } else {
      if (gameState.started && !gameState.dead && !gameState.dialogueActive) {
        gameState.paused = true;
      }
    }
  });
}

function startGame() {
  document.getElementById('title-screen').classList.add('hidden');
  document.getElementById('death-screen').classList.add('hidden');
  document.getElementById('ending-screen').classList.add('hidden');
  gameState.reset();
  uiManager.showHUD();
  audioManager.startAmbient();
  loadAct(1);
}

export function loadAct(actNumber) {
  // Clean up current level
  if (currentLevel) {
    currentLevel.cleanup(scene);
  }
  entityManager.clearAll();
  laserSystem.clearMirrors();

  gameState.currentAct = actNumber;

  // Build the level
  let levelData;
  switch (actNumber) {
    case 1: levelData = buildAct1(scene, gameState); break;
    case 2: levelData = buildAct2(scene, gameState); break;
    case 3: levelData = buildAct3(scene, gameState); break;
    default: return;
  }

  currentLevel = levelData;

  // Register mirrors with laser system
  laserSystem.setMirrors(levelData.mirrors || []);
  laserSystem.setCollidables(levelData.collidables || []);

  // Register entities
  if (levelData.entities) {
    levelData.entities.forEach(e => entityManager.addEntity(e));
  }

  // Set player position
  player.setPosition(levelData.playerStart);
  player.setPortableMirrors(levelData.portableMirrorCount || 0);

  // Register interactables with player
  player.setInteractables(levelData.interactables || []);
  player.setDoors(levelData.doors || []);

  // Show act transition
  uiManager.showActTransition(levelData.actTitle, levelData.actSubtitle, () => {
    controls.lock();
    gameState.started = true;
    if (levelData.introDialogue) {
      uiManager.showDialogue(levelData.introDialogue, () => {
        gameState.dialogueActive = false;
      });
    }
    if (levelData.objective) {
      uiManager.setObjective(levelData.objective);
    }
  });
}

function restartCurrentAct() {
  document.getElementById('death-screen').classList.add('hidden');
  gameState.dead = false;
  loadAct(gameState.currentAct);
}

function onResize() {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
}

// ---- Main Game Loop ----
function animate() {
  requestAnimationFrame(animate);

  const dt = Math.min(clock.getDelta(), 0.05); // cap delta

  if (gameState.started && !gameState.paused && !gameState.dead && !gameState.dialogueActive) {
    // Update systems
    player.update(dt);
    laserSystem.update(dt, player);
    entityManager.update(dt, player, laserSystem);

    // Level-specific update
    if (currentLevel && currentLevel.update) {
      currentLevel.update(dt, player, laserSystem, entityManager, gameState, uiManager, audioManager);
    }

    // Check death
    if (gameState.health <= 0) {
      gameState.dead = true;
      controls.unlock();
      audioManager.playSound('death');
      document.getElementById('death-screen').classList.remove('hidden');
    }
  }

  // Always update UI
  uiManager.update(dt, player, laserSystem, gameState);

  // Render
  renderer.render(scene, camera);
}

// ---- Boot ----
init().then(() => {
  animate();
}).catch(err => {
  console.error('Failed to initialize:', err);
});

// Export for cross-module access
export { scene, camera, renderer, controls, player, laserSystem, entityManager, uiManager, audioManager, gameState, loadAct as switchAct };
