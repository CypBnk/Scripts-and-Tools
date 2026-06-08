# KQL Queries - Entra / Azure AD Analysis

## Übersicht

Dieses Verzeichnis enthält Kusto Query Language (KQL) Queries für die Analyse von Azure AD / Entra ID Logs.

## Verfügbare Queries

### 1. **Report-Only-CA-Failures-UnmanagedDevices.kql**

**Beschreibung:**  
Detaillierte Ansicht aller Sign-in Fehler, die durch Report Only Conditional Access Policies verursacht werden, gefiltert auf Benutzer ohne verwaltete Windows Devices.

**Felder:**

- **UPN** - User Principal Name des Benutzers
- **CARule** - Name der Conditional Access Regel
- **CAStatus** - Status der CA Policy (failure, success, etc.)
- **CAResult** - Detailliertes Ergebnis der CA Evaluierung
- **IPAddress** - IP-Adresse des Zugriffs
- **City** - Stadt (aus LocationDetails)
- **Country** - Land (aus LocationDetails)
- **FailureReason** - Detaillierter Fehlergrund
- **Timestamp** - Zeitstempel des Ereignisses
- **CorrelationID** - Eindeutige Korrelations-ID für Troubleshooting

**Zeitraum:** Letzte 30 Tage  
**Filter:**

- ReportSeverity = "Information" (Report Only Policies)
- Status muss CA-Fehler enthalten
- DeviceDetail.deviceId ist leer (unverwaltetes Gerät)

**Verwendung:**  
Ideal für:

- Detaillierte Fehleranalyse pro Benutzer
- Geolocation-basierte Anomalie-Erkennung
- Troubleshooting einzelner Sign-in Fehler

---

### 2. **Report-Only-CA-Failures-Aggregated.kql**

**Beschreibung:**  
Aggregierte Ansicht der Report Only CA Policy Fehler, gruppiert nach CA-Regel.

**Felder:**

- **ConditionalAccessRule** - CA Policy Name
- **ConditionalAccessStatus** - Status
- **FailureCount** - Gesamtanzahl Fehlgeschlagener Attempts
- **UniqueUsers** - Anzahl betroffener Benutzer
- **TopUsers** - Top 10 Benutzer mit Fehlern
- **FirstFailure** - Zeitstempel des ersten Fehlers
- **LastFailure** - Zeitstempel des letzten Fehlers

**Zeitraum:** Letzte 30 Tage  
**Filter:** Identisch mit Report-Only-CA-Failures-UnmanagedDevices.kql

**Verwendung:**  
Ideal für:

- Überblick über betroffene Policies
- Priorisierung von Policy-Adjustments
- Trend-Analyse über Zeit

---

## Ausführung in Azure Portal

1. **Öffne** Azure Portal → Log Analytics Workspace
2. **Wähle** den entsprechenden Workspace aus
3. **Kopiere** eine der Queries in den Query Editor
4. **Passe** den `ago(30d)` Parameter an, falls nötig (z.B. `ago(7d)` für 7 Tage)
5. **Klicke** "Run" oder drücke `Shift+Alt+Enter`

### Zeitraum-Anpassungen

```kusto
| where TimeGenerated > ago(24h)   // Letzte 24 Stunden
| where TimeGenerated > ago(7d)    // Letzte 7 Tage
| where TimeGenerated > ago(30d)   // Letzte 30 Tage
```

---

## Troubleshooting

### Keine Ergebnisse?

1. **Zeitraum prüfen** - Sind in diesem Zeitraum Report Only CA Policy Events vorhanden?
2. **DeviceDetail.deviceId** - Prüfe, ob Events mit null/leer DeviceID vorhanden sind
3. **ReportSeverity** - Verifiziere, dass deine CA Policies auf "Report Only" gesetzt sind

### Feldmapping validieren

Die genaue Verfügbarkeit von Feldern kann je nach Log Analytics Version variieren:

- `ConditionalAccessRule` - Kann leer sein, wenn nicht explizit in Log vorhanden
- `LocationDetails.city/countryOrRegion` - Können null sein, wenn Geolocation nicht verfügbar
- `DeviceDetail` - Komplexes Nested Object; nutze `isempty()` für Prüfung

---

## Best Practices

1. **Für Echtzeit-Alerting**: Nutze Azure Monitor Alert Rules mit diesen Queries
2. **Für Reports**: Exportiere Ergebnisse als CSV über "Export" Button
3. **Für Automation**: Nutze Azure Logic Apps oder PowerShell mit KQL REST API
4. **Für Dashboards**: Pinne häufig genutzte Queries an

---

## Verwandte Ressourcen

- [Microsoft KQL Documentation](https://learn.microsoft.com/en-us/kusto/query/)
- [SignInLogs Table Reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/signinlogs)
- [Conditional Access Policy Overview](https://learn.microsoft.com/en-us/entra/identity/conditional-access/overview)
