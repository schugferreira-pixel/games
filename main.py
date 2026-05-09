import os
import zipfile
from concurrent.futures import ThreadPoolExecutor
from threading import Lock

PASTA_ORIGEM = "scripts"
PASTA_DESTINO = "zips"

os.makedirs(PASTA_DESTINO, exist_ok=True)

arquivos_lua = []

# procura todos os .lua
for root, dirs, files in os.walk(PASTA_ORIGEM):

    for file in files:

        if file.endswith(".lua"):

            arquivos_lua.append(
                os.path.join(root, file)
            )

TOTAL = len(arquivos_lua)

print(f"Arquivos encontrados: {TOTAL}\n")

contador = 0
lock = Lock()

def zipar(caminho_arquivo):

    global contador

    nome = os.path.basename(caminho_arquivo)
    nome_zip = os.path.splitext(nome)[0] + ".zip"

    caminho_zip = os.path.join(PASTA_DESTINO, nome_zip)

    try:

        with zipfile.ZipFile(
            caminho_zip,
            "w",
            compression=zipfile.ZIP_STORED
        ) as zipf:

            zipf.write(caminho_arquivo, arcname=nome)

    except:
        pass

    with lock:

        contador += 1

        # mesma linha
        print(
            f"\rCompactando: {contador}/{TOTAL}",
            end="",
            flush=True
        )

with ThreadPoolExecutor(max_workers=8) as executor:

    executor.map(zipar, arquivos_lua)

print("\nFinalizado.")
