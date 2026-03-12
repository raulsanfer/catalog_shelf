import * as pdfjsLib from "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.3.136/pdf.min.mjs";

pdfjsLib.GlobalWorkerOptions.workerSrc =
  "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.3.136/pdf.worker.min.mjs";

const shell = document.querySelector(".viewer-shell");
const pdfUrl = shell?.dataset?.pdfUrl;

const canvas = document.getElementById("pdfCanvas");
const ctx = canvas.getContext("2d");
const pageCounter = document.getElementById("pageCounter");
const prevPageBtn = document.getElementById("prevPage");
const nextPageBtn = document.getElementById("nextPage");
const searchInput = document.getElementById("searchInput");
const searchNextBtn = document.getElementById("searchNext");
const searchPrevBtn = document.getElementById("searchPrev");
const searchStatus = document.getElementById("searchStatus");
const bookStage = document.getElementById("bookStage");
const matchHint = document.getElementById("matchHint");

let pdfDoc = null;
let currentPage = 1;
let renderedScale = 1;
let pageTexts = [];
let matches = [];
let currentMatchIndex = -1;
let touchStartX = 0;

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function renderPage(pageNumber) {
  if (!pdfDoc) return;

  const page = await pdfDoc.getPage(pageNumber);
  const viewport = page.getViewport({ scale: 1 });

  const stageWidth = Math.max(bookStage.clientWidth - 24, 320);
  const stageHeight = Math.max(bookStage.clientHeight - 24, 220);

  const scaleToFit = Math.min(stageWidth / viewport.width, stageHeight / viewport.height);
  renderedScale = Math.max(scaleToFit, 0.5);

  const scaledViewport = page.getViewport({ scale: renderedScale });
  const outputScale = window.devicePixelRatio || 1;

  canvas.width = Math.floor(scaledViewport.width * outputScale);
  canvas.height = Math.floor(scaledViewport.height * outputScale);

  canvas.style.width = `${Math.floor(scaledViewport.width)}px`;
  canvas.style.height = `${Math.floor(scaledViewport.height)}px`;

  ctx.setTransform(outputScale, 0, 0, outputScale, 0, 0);
  await page.render({
    canvasContext: ctx,
    viewport: scaledViewport,
  }).promise;

  pageCounter.textContent = `Página ${currentPage} de ${pdfDoc.numPages}`;
}

async function goToPage(pageNumber, animate = true) {
  if (!pdfDoc) return;
  const clamped = Math.max(1, Math.min(pdfDoc.numPages, pageNumber));
  if (clamped === currentPage) return;

  currentPage = clamped;
  if (animate) {
    canvas.classList.remove("page-turn");
    void canvas.offsetWidth;
    canvas.classList.add("page-turn");
  }

  await renderPage(currentPage);
}

async function extractAllText() {
  if (!pdfDoc) return;

  pageTexts = [];
  for (let pageNum = 1; pageNum <= pdfDoc.numPages; pageNum += 1) {
    const page = await pdfDoc.getPage(pageNum);
    const textContent = await page.getTextContent();
    const joined = textContent.items.map((item) => item.str).join(" ").toLowerCase();
    pageTexts.push(joined);
  }
}

function showMatchHint(text) {
  matchHint.textContent = text;
  matchHint.classList.remove("hidden");
  setTimeout(() => {
    matchHint.classList.add("hidden");
  }, 1400);
}

function computeMatches(term) {
  matches = [];
  currentMatchIndex = -1;

  const normalized = term.trim().toLowerCase();
  if (!normalized || !pageTexts.length) {
    searchStatus.textContent = "0/0";
    return;
  }

  const pattern = new RegExp(escapeRegExp(normalized), "g");

  pageTexts.forEach((text, idx) => {
    let match = pattern.exec(text);
    while (match) {
      matches.push({ page: idx + 1 });
      match = pattern.exec(text);
    }
  });

  searchStatus.textContent = `0/${matches.length}`;
}

async function goToMatch(delta) {
  if (!matches.length) {
    showMatchHint("Sin resultados");
    return;
  }

  currentMatchIndex += delta;

  if (currentMatchIndex >= matches.length) currentMatchIndex = 0;
  if (currentMatchIndex < 0) currentMatchIndex = matches.length - 1;

  const target = matches[currentMatchIndex];
  await goToPage(target.page);
  searchStatus.textContent = `${currentMatchIndex + 1}/${matches.length}`;
  showMatchHint(`Resultado ${currentMatchIndex + 1} en página ${target.page}`);
}

async function init() {
  if (!pdfUrl) return;

  const loadingTask = pdfjsLib.getDocument(pdfUrl);
  pdfDoc = await loadingTask.promise;

  await renderPage(currentPage);
  extractAllText();
}

prevPageBtn.addEventListener("click", async () => {
  await goToPage(currentPage - 1);
});

nextPageBtn.addEventListener("click", async () => {
  await goToPage(currentPage + 1);
});

searchInput.addEventListener("keydown", async (event) => {
  if (event.key === "Enter") {
    computeMatches(searchInput.value);
    await goToMatch(1);
  }
});

searchNextBtn.addEventListener("click", async () => {
  if (!matches.length) computeMatches(searchInput.value);
  await goToMatch(1);
});

searchPrevBtn.addEventListener("click", async () => {
  if (!matches.length) computeMatches(searchInput.value);
  await goToMatch(-1);
});

searchInput.addEventListener("input", () => {
  computeMatches(searchInput.value);
});

window.addEventListener("resize", async () => {
  await renderPage(currentPage);
});

bookStage.addEventListener("touchstart", (event) => {
  touchStartX = event.changedTouches[0].screenX;
});

bookStage.addEventListener("touchend", async (event) => {
  const touchEndX = event.changedTouches[0].screenX;
  const diff = touchEndX - touchStartX;

  if (Math.abs(diff) < 40) return;

  if (diff < 0) {
    await goToPage(currentPage + 1);
  } else {
    await goToPage(currentPage - 1);
  }
});

init();
