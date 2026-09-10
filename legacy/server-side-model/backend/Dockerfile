FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Nota: o cliente docker-py dentro deste container fala com o Docker do HOST
# via socket montado em /var/run/docker.sock (ver docker-compose.yml).
# Isso é intencional: os containers de cada lab sobem como "irmãos" deste
# container, não "filhos" dentro dele (evita Docker-in-Docker).

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
