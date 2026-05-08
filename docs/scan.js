import * as THREE from "three";
import { OBJLoader } from "three/addons/loaders/OBJLoader.js";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";

const params = new URLSearchParams(location.search);
const scanID = params.get("id");
const errorEl = document.getElementById("error");
const titleEl = document.getElementById("title");
const statsEl = document.getElementById("stats");
const videoEl = document.getElementById("video");
const arLinkEl = document.getElementById("ar-link");
const viewerEl = document.getElementById("viewer");
const resetBtn = document.getElementById("reset-camera");

const BRAND = 0x0c3b1c;

function showError(message) {
    errorEl.hidden = false;
    errorEl.textContent = message;
}

function durationLabel(seconds) {
    const total = Math.round(seconds || 0);
    return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

function appendStat(label, value) {
    const dt = document.createElement("dt");
    dt.textContent = label;
    const dd = document.createElement("dd");
    dd.textContent = value;
    statsEl.append(dt, dd);
}

async function load() {
    if (!scanID) {
        showError("No scan id supplied.");
        return;
    }
    let manifest;
    try {
        const res = await fetch("./scans.json", { cache: "no-cache" });
        if (!res.ok) throw new Error(`scans.json (${res.status})`);
        const data = await res.json();
        const scans = Array.isArray(data) ? data : (data.scans || []);
        manifest = scans.find(s => s.id === scanID);
        if (!manifest) {
            showError(`Scan "${scanID}" not found in library.`);
            return;
        }
    } catch (err) {
        showError(`Couldn't load library: ${err.message}`);
        return;
    }

    titleEl.textContent = manifest.name || manifest.id;
    document.title = `${manifest.name || manifest.id} · LiDAR Capture`;

    appendStat("Captured", new Date(manifest.createdAt).toLocaleString());
    appendStat("Duration", durationLabel(manifest.durationSeconds));
    appendStat("Vertices", (manifest.vertexCount || 0).toLocaleString());
    appendStat("Triangles", (manifest.triangleCount || 0).toLocaleString());
    appendStat("Mesh chunks", manifest.meshAnchorCount ?? "—");

    if (manifest.videoFile) {
        videoEl.src = "./" + manifest.videoFile;
    } else {
        videoEl.parentElement.removeChild(videoEl);
    }

    if (manifest.usdzFile) {
        const a = document.createElement("a");
        a.className = "btn";
        a.rel = "ar";
        a.href = "./" + manifest.usdzFile;
        const img = document.createElement("img");
        img.src = "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==";
        img.alt = "";
        img.style.display = "none";
        const label = document.createElement("span");
        label.textContent = "View in AR";
        a.append(img, label);
        arLinkEl.appendChild(a);
    }

    if (manifest.meshFile) {
        try {
            await loadMesh("./" + manifest.meshFile);
        } catch (err) {
            showError(`Mesh failed to load: ${err.message}`);
        }
    } else {
        viewerEl.innerHTML = '<div style="color:var(--text-dim);padding:32px;text-align:center">No mesh in this scan.</div>';
    }
}

async function loadMesh(url) {
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.setClearColor(0x06090a, 1);
    viewerEl.appendChild(renderer.domElement);

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x06090a);

    const camera = new THREE.PerspectiveCamera(60, 1, 0.05, 1000);
    camera.position.set(2, 2, 2);

    scene.add(new THREE.AmbientLight(0xffffff, 0.6));
    const key = new THREE.DirectionalLight(0xffffff, 1.0);
    key.position.set(3, 5, 2);
    scene.add(key);
    const rim = new THREE.DirectionalLight(BRAND, 0.6);
    rim.position.set(-4, 2, -3);
    scene.add(rim);

    const grid = new THREE.GridHelper(20, 20, 0x1a552c, 0x102018);
    grid.material.opacity = 0.35;
    grid.material.transparent = true;
    scene.add(grid);

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;

    const loader = new OBJLoader();
    const object = await loader.loadAsync(url);

    const material = new THREE.MeshStandardMaterial({
        color: 0xc9d8cd,
        roughness: 0.85,
        metalness: 0.05,
        flatShading: true,
        side: THREE.DoubleSide
    });
    object.traverse(child => {
        if (child.isMesh) {
            child.material = material;
            if (child.geometry && !child.geometry.attributes.normal) {
                child.geometry.computeVertexNormals();
            }
        }
    });
    scene.add(object);

    const box = new THREE.Box3().setFromObject(object);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());
    object.position.sub(center);
    grid.position.y = -size.y / 2;

    const radius = Math.max(size.x, size.y, size.z);
    const initialPosition = new THREE.Vector3(radius * 1.3, radius * 0.9, radius * 1.3);
    const initialTarget = new THREE.Vector3(0, 0, 0);

    function frameCamera() {
        camera.position.copy(initialPosition);
        controls.target.copy(initialTarget);
        controls.update();
    }
    frameCamera();
    resetBtn.addEventListener("click", frameCamera);

    function resize() {
        const w = viewerEl.clientWidth;
        const h = viewerEl.clientHeight;
        renderer.setSize(w, h, false);
        camera.aspect = w / h;
        camera.updateProjectionMatrix();
    }
    resize();
    new ResizeObserver(resize).observe(viewerEl);

    function tick() {
        controls.update();
        renderer.render(scene, camera);
        requestAnimationFrame(tick);
    }
    tick();
}

load();
