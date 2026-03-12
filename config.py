import os
from pathlib import Path

# Ruta base donde están las carpetas y catálogos PDF
_default_catalog = Path(__file__).resolve().parent / "catalog"
BASE_CATALOG_PATH = Path(os.environ.get("BASE_CATALOG_PATH", str(_default_catalog)))

# Logo mostrado en la cabecera de la home (ruta dentro de /static)
HOME_LOGO = "images/logo.svg"

def _get_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


# Configuración del servidor Flask
HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "5000"))
DEBUG = _get_bool("DEBUG", False)
