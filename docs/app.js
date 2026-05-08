const grid = document.getElementById("grid");
const empty = document.getElementById("empty");

const cubeSVG = `
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round">
    <path d="M12 2 3 6.5v11L12 22l9-4.5v-11Z"/>
    <path d="m3 6.5 9 4.5 9-4.5"/>
    <path d="M12 11v11"/>
</svg>`;

function durationLabel(seconds) {
    const total = Math.round(seconds || 0);
    const m = Math.floor(total / 60);
    const s = total % 60;
    return `${m}:${String(s).padStart(2, "0")}`;
}

function dateLabel(iso) {
    if (!iso) return "";
    try {
        return new Date(iso).toLocaleString(undefined, {
            month: "short",
            day: "numeric",
            year: "numeric",
            hour: "numeric",
            minute: "2-digit"
        });
    } catch {
        return iso;
    }
}

function numberLabel(n) {
    if (typeof n !== "number") return "—";
    return n.toLocaleString();
}

function buildCard(scan) {
    const link = document.createElement("a");
    link.className = "card";
    link.href = `./scan.html?id=${encodeURIComponent(scan.id)}`;

    const triangles = scan.triangleCount ? `${numberLabel(scan.triangleCount)} tri` : "no mesh";
    const duration = durationLabel(scan.durationSeconds);
    const date = dateLabel(scan.createdAt);

    link.innerHTML = `
        <div class="card-thumb">${cubeSVG}</div>
        <div class="card-body">
            <h3 class="card-title">${escapeHTML(scan.name || scan.id)}</h3>
            <div class="card-meta">
                <span>📐 ${triangles}</span>
                <span>⏱ ${duration}</span>
                <span>📅 ${date}</span>
            </div>
        </div>
    `;
    return link;
}

function escapeHTML(s) {
    return String(s).replace(/[&<>"']/g, c => ({
        "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[c]));
}

async function load() {
    try {
        const res = await fetch("./scans.json", { cache: "no-cache" });
        if (!res.ok) throw new Error(`scans.json not found (${res.status})`);
        const data = await res.json();
        const scans = Array.isArray(data) ? data : (data.scans || []);
        if (!scans.length) {
            empty.hidden = false;
            return;
        }
        for (const scan of scans) {
            grid.appendChild(buildCard(scan));
        }
    } catch (err) {
        empty.hidden = false;
        empty.querySelector("h3").textContent = "Couldn't load library";
        empty.querySelector("p").textContent = err.message;
    }
}

load();
