// Dev page: toggle Tutorial steps and Reset. Writes go through the background
// script, like the rest of the extension, so the app sees the same state.
(async function () {
  const api = globalThis.browser || globalThis.chrome;
  const boxes = document.querySelectorAll("[data-step]");
  const lastResetEl = document.getElementById("last-reset");

  const render = async () => {
    const { tutorialProgress = {}, lastResetAt } = await api.storage.local.get([
      "tutorialProgress",
      "lastResetAt",
    ]);
    boxes.forEach((box) => (box.checked = !!tutorialProgress[box.dataset.step]));
    lastResetEl.textContent = lastResetAt ? new Date(lastResetAt).toLocaleString() : "never";
  };

  boxes.forEach((box) =>
    box.addEventListener("change", async () => {
      const tutorialProgress = {};
      boxes.forEach((b) => (tutorialProgress[b.dataset.step] = b.checked));
      console.info("[EuroBonus Finder] tutorial progress set:", tutorialProgress);
      await api.runtime.sendMessage({ type: "set-tutorial-progress", tutorialProgress });
    }),
  );

  document.getElementById("reset").addEventListener("click", async () => {
    await api.runtime.sendMessage({ type: "reset" });
    console.info("[EuroBonus Finder] reset");
    await render();
  });

  await render();
})();
