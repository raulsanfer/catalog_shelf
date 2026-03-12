from __future__ import annotations

from pathlib import Path
from urllib.parse import quote

from flask import Flask, abort, render_template, send_from_directory

app = Flask(__name__)
app.config.from_object("config")

BASE_PATH = Path(app.config["BASE_CATALOG_PATH"]).resolve()


def _safe_relative_path(raw_path: str = "") -> Path:
    requested = (BASE_PATH / raw_path).resolve()
    if BASE_PATH != requested and BASE_PATH not in requested.parents:
        abort(404)
    return requested


def _build_breadcrumbs(relative_path: str) -> list[dict[str, str]]:
    breadcrumbs = [{"label": "Inicio", "path": ""}]
    if not relative_path:
        return breadcrumbs

    parts = [p for p in relative_path.split("/") if p]
    for i in range(len(parts)):
        breadcrumbs.append(
            {
                "label": parts[i],
                "path": "/".join(parts[: i + 1]),
            }
        )
    return breadcrumbs


@app.route("/")
@app.route("/browse/")
@app.route("/browse/<path:relative_path>")
def home(relative_path: str = ""):
    current_path = _safe_relative_path(relative_path)
    if not current_path.exists() or not current_path.is_dir():
        abort(404)

    folders = []
    files = []

    for entry in sorted(current_path.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower())):
        if entry.is_dir():
            rel = entry.relative_to(BASE_PATH).as_posix()
            folders.append(
                {
                    "name": entry.name,
                    "path": rel,
                }
            )
            continue

        if entry.suffix.lower() != ".pdf":
            continue

        rel = entry.relative_to(BASE_PATH).as_posix()
        files.append(
            {
                "name": entry.name,
                "path": rel,
                "url_path": quote(rel),
            }
        )

    parent_path = None
    if relative_path:
        parent_path = str(Path(relative_path).parent).replace("\\", "/")
        if parent_path == ".":
            parent_path = ""

    return render_template(
        "home.html",
        folders=folders,
        files=files,
        current_path=relative_path,
        parent_path=parent_path,
        breadcrumbs=_build_breadcrumbs(relative_path),
        home_logo=app.config["HOME_LOGO"],
    )


@app.route("/catalog-file/<path:file_path>")
def serve_pdf(file_path: str):
    abs_file = _safe_relative_path(file_path)
    if not abs_file.exists() or not abs_file.is_file() or abs_file.suffix.lower() != ".pdf":
        abort(404)

    return send_from_directory(BASE_PATH, abs_file.relative_to(BASE_PATH).as_posix())


@app.route("/viewer/<path:file_path>")
def viewer(file_path: str):
    abs_file = _safe_relative_path(file_path)
    if not abs_file.exists() or not abs_file.is_file() or abs_file.suffix.lower() != ".pdf":
        abort(404)

    rel_folder = abs_file.parent.relative_to(BASE_PATH).as_posix()
    if rel_folder == ".":
        rel_folder = ""

    return render_template(
        "viewer.html",
        file_name=abs_file.name,
        file_path=abs_file.relative_to(BASE_PATH).as_posix(),
        pdf_url=f"/catalog-file/{quote(abs_file.relative_to(BASE_PATH).as_posix())}",
        back_to_folder=rel_folder,
    )


if __name__ == "__main__":
    app.run(
        host=app.config["HOST"],
        port=app.config["PORT"],
        debug=app.config["DEBUG"],
    )
