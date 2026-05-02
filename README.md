sudo -i then:

Ensure alacritty and docker is installed. 

copy Dockerfile and start.sh to /root/.local/share/coding-container-template/

do "chmod +x /root/.local/share/coding-container-template/start.sh"

add this to ~/.zshrc
-------


ccodebox() {
  local template_dir="/root/.local/share/coding-container-template"
  systemctl start docker
  mkdir -p ./mount

  cp "$template_dir/Dockerfile" ./Dockerfile
  cp "$template_dir/start.sh" ./start.sh
  chmod +x ./start.sh

  ./start.sh
}



-------

execute in root terminal with "ccodebox" command. -> session starts



Cheatsheet for myself:







````
# Continuous Claude Usage Cheat Sheet

## Start

```bash
cd /workspace/dein-projekt
claude-opus
````

Setup prüfen:

```text
/workflow
```

---

## Modell-Setup

```text
Main-Prozess: Opus
Subagents: Sonnet
```

Nur wenn du bewusst ohne Opus starten willst:

```bash
claude
```

---

## Neues Projekt

```text
/build greenfield "Projektziel kurz beschreiben"

Use Continuous Claude workflows.
Keep context minimal and sufficient.
Document architecture decisions.
Create/update handoff after milestones.
Do not overengineer.
```

Beispiel:

```text
/build greenfield "AI productivity app with auth, dashboard, backend API and multi-LLM routing"
```

---

## Bestehendes Projekt erweitern

```text
/build brownfield "Feature kurz beschreiben"

Use existing conventions.
Do not scan the whole repo.
Use agents for exploration if needed.
Before editing, identify the minimal file set.
Run targeted verification.
Update handoff.
```

Beispiel:

```text
/build brownfield "add image upload to the existing chat"
```

---

## Bug fixen

```text
/fix bug "Bug kurz beschreiben"

Find root cause first.
Make the smallest safe fix.
Run targeted verification.
Update handoff with cause and fix.
```

Beispiel:

```text
/fix bug "login redirects to wrong page after OAuth"
```

---

## Codebase verstehen

```text
/explore
```

Oder gezielter:

```text
/explore "understand auth flow and API structure"
```

---

## Risikoanalyse vor großem Umbau

```text
/premortem "geplante Änderung beschreiben"
```

Beispiel:

```text
/premortem "migrate auth from custom sessions to Auth.js"
```

---

## Session beenden

```text
create_handoff
```

Besser:

```text
Create a handoff now.

Include:
- current goal
- completed work
- files changed
- decisions made
- known issues
- tests run and results
- exact next steps
```

---

## Session fortsetzen

```text
resume_handoff
```

Besser:

```text
resume_handoff

Summarize where we are, then continue with the next concrete task.
```

---

## Gute Standard-Prompts

### Für fast jede Aufgabe

```text
Use Continuous Claude workflows.
Keep context minimal and sufficient.
Do not scan the whole repo.
Use subagents for broad exploration.
Before editing, identify the minimal file set.
Run the smallest relevant verification.
Update handoff when done.
```

### Für API/Frontend-Arbeit

```text
Use the API contract as source of truth.
Do not inspect backend implementation for frontend-only work unless the contract is missing or inconsistent.
If backend verification is needed, use an agent and return only a summary.
```

### Für bestehende Projekte

```text
Respect existing architecture, naming, style and conventions.
Avoid unrelated refactors.
Make the smallest safe change.
```

---

## Begriffe

```text
greenfield = neues Projekt von 0
brownfield = bestehendes Projekt erweitern
handoff    = gespeicherter Arbeitsstand für spätere Sessions
agent      = ausgelagerter Helfer mit eigenem Kontext
skill      = spezialisierter Workflow / Fähigkeit
hook       = automatische Regel oder Aktion im Hintergrund
```

---

## Vermeiden

```text
Lies die ganze Codebase.
Mach einfach alles fertig.
Refactor mal alles.
Mach es perfekt.
```

Besser:

```text
Ziel + Kontextgrenze + Verifikation + Handoff
```

---

## Updates / Wartung

Im Container:

```bash
cc-update
```

Uninstall:

```bash
cc-uninstall
```

Docker prüfen:

```bash
docker ps
```

GitHub HTTPS-Rewrite prüfen:

```bash
git config --global --get-regexp '^url\.https://github\.com/'
```

```
```
