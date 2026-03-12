# Visor de catálogos PDF (Flask)

Aplicación Flask para navegar carpetas de catálogos PDF y visualizarlos en modo libro a pantalla completa con búsqueda de texto.

## Características

- Exploración de carpetas anidadas desde una ruta base configurable.
- Home visual con carpetas y PDFs en formato tarjetas grandes.
- Visor PDF a pantalla completa.
- Navegación de páginas con flechas y gesto táctil (swipe).
- Búsqueda de texto en el PDF con navegación entre ocurrencias (arriba/abajo).
- Botón Inicio y Atrás en el visor.
- Logo configurable en la cabecera de la home.

## Requisitos

- Python 3.10+

## Instalación

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Configuración

Edita `config.py`:

- `BASE_CATALOG_PATH`: ruta base donde están tus carpetas de catálogos.
- `HOME_LOGO`: imagen dentro de `static/` para mostrar en cabecera.
- `HOST`, `PORT`, `DEBUG`: parámetros del servidor Flask.

Ejemplo:

```python
BASE_CATALOG_PATH = Path("/mnt/catalogos")
HOME_LOGO = "images/mi_logo.png"
```

## Ejecución

```bash
python app.py
```

Abre en navegador: `http://localhost:5000`

## Estructura

- `app.py`: rutas Flask y navegación segura en carpetas/PDF.
- `templates/home.html`: explorador visual.
- `templates/viewer.html`: visor con controles.
- `static/js/viewer.js`: renderizado PDF + búsqueda + swipe.
- `static/css/styles.css`: estilos responsive.
