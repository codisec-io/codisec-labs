// Único arquivo que você precisa editar ao trocar de ambiente
// (dev local vs. produção). Em produção, aponte para o domínio do backend.
const API_BASE = window.location.hostname === "localhost"
  ? "http://localhost:8000"
  : "https://api.codisec.com.br";

const WS_BASE = API_BASE.replace(/^http/, "ws");
