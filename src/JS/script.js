const DISPLAY_CHAR_LIMIT = 50;
const commandPanels = document.querySelectorAll(".command-panel");

function getFullCommandText(commandElement) {
  return (
    commandElement?.dataset?.fullCommand ||
    commandElement?.textContent?.trim() ||
    ""
  );
}

function setCommandDisplay(commandElement) {
  if (!commandElement) {
    return;
  }

  const fullText = getFullCommandText(commandElement);

  commandElement.dataset.fullCommand = fullText;
  commandElement.textContent =
    fullText.length > DISPLAY_CHAR_LIMIT
      ? `${fullText.slice(0, DISPLAY_CHAR_LIMIT)}...`
      : fullText;
  commandElement.title = fullText;
}

async function copyCustomCommand(commandElement, statusElement) {
  const commandText = getFullCommandText(commandElement);

  if (!commandText) {
    if (statusElement) {
      statusElement.textContent = "No command found to copy.";
    }
    return;
  }

  try {
    await navigator.clipboard.writeText(commandText);
    if (statusElement) {
      statusElement.textContent = "Command copied to clipboard.";
    }
  } catch (error) {
    // Fallback for environments that do not allow clipboard API.
    const range = document.createRange();
    range.selectNodeContents(commandElement);

    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);

    try {
      document.execCommand("copy");
      if (statusElement) {
        statusElement.textContent = "Command copied to clipboard.";
      }
    } catch (execError) {
      if (statusElement) {
        statusElement.textContent =
          "Unable to copy automatically. Select the command and press Ctrl+C.";
      }
    }

    selection.removeAllRanges();
  }
}

for (const panel of commandPanels) {
  const commandElement = panel.querySelector(".command-text");
  const copyButton = panel.querySelector(".copy-btn");
  const statusElement = panel.querySelector(".copy-status");

  setCommandDisplay(commandElement);

  if (copyButton && commandElement) {
    copyButton.addEventListener("click", () => {
      copyCustomCommand(commandElement, statusElement);
    });
  }
}
