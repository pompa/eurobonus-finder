// Dev page: stamp Tutorial steps, reset the Tutorial, or Reset everything.
// Writes go through the background script, like the rest of the extension, so
// the app sees the same state.
(async function () {
  const api = globalThis.browser || globalThis.chrome;
  const dumpEl = document.getElementById("tutorial");
  const lastResetEl = document.getElementById("last-reset");

  const render = async () => {
    const { tutorial = {}, lastResetAt } = await api.storage.local.get(["tutorial", "lastResetAt"]);
    dumpEl.textContent = JSON.stringify(tutorial, null, 2);
    lastResetEl.textContent = lastResetAt ? new Date(lastResetAt).toLocaleString() : "never";
  };

  document.querySelectorAll("[data-step]").forEach((btn) =>
    btn.addEventListener("click", async () => {
      await api.runtime.sendMessage({ type: "stamp-tutorial", step: btn.dataset.step });
      await render();
    }),
  );

  document.getElementById("reset-tutorial").addEventListener("click", async () => {
    await api.runtime.sendMessage({ type: "reset-tutorial" });
    await render();
  });

  document.getElementById("reset").addEventListener("click", async () => {
    await api.runtime.sendMessage({ type: "reset" });
    console.info("[EuroBonus Finder] reset");
    await render();
  });

  await render();
})();
