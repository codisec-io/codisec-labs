let allLabs = [];

async function loadLabs() {
  const res = await fetch(`${API_BASE}/api/labs`);
  allLabs = await res.json();
  renderLabs();
}

function renderLabs() {
  const category = document.getElementById("filter-category").value;
  const difficulty = document.getElementById("filter-difficulty").value;

  const filtered = allLabs.filter(l =>
    (!category || l.category === category) &&
    (!difficulty || l.difficulty === difficulty)
  );

  const grid = document.getElementById("lab-grid");
  if (filtered.length === 0) {
    grid.innerHTML = "<p>Nenhum lab encontrado com esses filtros.</p>";
    return;
  }

  grid.innerHTML = filtered.map(lab => `
    <div class="lab-card" onclick="location.href='lab.html?id=${lab.id}'">
      <span class="badge ${lab.category}">${lab.category}</span>
      <span class="badge ${lab.difficulty}">${lab.difficulty}</span>
      <h3>${lab.title}</h3>
      <p>${lab.description}</p>
      <small>⏱ ${lab.duration}</small>
    </div>
  `).join("");
}

document.getElementById("filter-category").addEventListener("change", renderLabs);
document.getElementById("filter-difficulty").addEventListener("change", renderLabs);

loadLabs();
