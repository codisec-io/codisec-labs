const params = new URLSearchParams(location.search);
const labId = params.get("id");

let lab = null;
let sessionId = null;
let term = null;
let ws = null;

async function loadLab() {
  const res = await fetch(`${API_BASE}/api/labs/${labId}`);
  if (!res.ok) {
    document.getElementById("lab-title").textContent = "Lab não encontrado";
    return;
  }
  lab = await res.json();
  document.title = lab.title;
  document.getElementById("lab-title").textContent = lab.title;
  document.getElementById("lab-description").textContent = lab.description;
  document.getElementById("lab-meta").innerHTML =
    `<span class="badge ${lab.category}">${lab.category}</span>
     <span class="badge ${lab.difficulty}">${lab.difficulty}</span>
     <small>⏱ ${lab.duration}</small>`;
  renderTasks();
}

function renderTasks() {
  const container = document.getElementById("tasks-container");
  container.innerHTML = lab.tasks.map(task => `
    <div class="task-card" id="task-${task.id}">
      <h4>${task.title}</h4>
      <p>${task.theory}</p>
      <ol>${task.steps.map(s => `<li>${s}</li>`).join("")}</ol>
      <button onclick="validateTask('${task.id}')" ${sessionId ? "" : "disabled"} class="btn-primary validate-btn-${task.id}">
        ✅ Validar
      </button>
      <p class="result" id="result-${task.id}"></p>
    </div>
  `).join("");
}

async function startLab() {
  const res = await fetch(`${API_BASE}/api/labs/${labId}/start`, { method: "POST" });
  const data = await res.json();
  sessionId = data.session_id;

  document.getElementById("start-btn").style.display = "none";
  document.getElementById("stop-btn").style.display = "inline-block";
  document.querySelectorAll("[class^=validate-btn-]").forEach(b => b.disabled = false);
  renderTasks(); // reativa os botões de validar

  connectTerminal();
}

async function stopLab() {
  if (!sessionId) return;
  await fetch(`${API_BASE}/api/sessions/${sessionId}/stop`, { method: "POST" });
  if (ws) ws.close();
  sessionId = null;
  document.getElementById("start-btn").style.display = "inline-block";
  document.getElementById("stop-btn").style.display = "none";
  renderTasks();
}

async function validateTask(taskId) {
  const resultEl = document.getElementById(`result-${taskId}`);
  resultEl.textContent = "Validando...";
  const res = await fetch(`${API_BASE}/api/sessions/${sessionId}/validate/${taskId}`, { method: "POST" });
  const data = await res.json();
  resultEl.textContent = (data.passed ? "✅ " : "❌ ") + data.message;
  document.getElementById(`task-${taskId}`).classList.toggle("passed", data.passed);
}

function connectTerminal() {
  term = new Terminal({ theme: { background: "#000000" } });
  term.open(document.getElementById("terminal"));

  ws = new WebSocket(`${WS_BASE}/ws/terminal/${sessionId}`);
  ws.binaryType = "arraybuffer";

  ws.onmessage = (event) => {
    const text = new TextDecoder("utf-8").decode(event.data);
    term.write(text);
  };
  term.onData((data) => {
    if (ws.readyState === WebSocket.OPEN) ws.send(data);
  });
}

document.getElementById("start-btn").addEventListener("click", startLab);
document.getElementById("stop-btn").addEventListener("click", stopLab);

loadLab();
