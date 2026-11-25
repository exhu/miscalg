# Phase 01: Project Scaffolding & Static Assets

## Objective

Create the project directory structure and static web assets to be served by the HTTP server.

## Step-by-Step Instructions

1. **Create directories** in the project root:
   - `assets`
   - `src`
   - `build`

2. **Create `assets/index.html`**:
   Write a valid HTML5 document (`<!DOCTYPE html>`, `<meta charset="utf-8">`, `<link rel="stylesheet" href="/style.css">`) that includes:
   - A clear line of text describing the program, e.g.:
     `<p>Minimal HTTP server written in FreePascal (ObjFPC mode) with simple routing and static file serving.</p>`
   - A form `<form action="/hello" method="get">` containing:
     - `<label for="name">Type your name:</label>`
     - `<input type="text" id="name" name="name" placeholder="Enter your name" required>`
     - `<button type="submit">Submit</button>`

3. **Create `assets/style.css`**:
   Write clean, minimal CSS styling for the page body, container, heading, form label, text input, submit button, and links so that `/style.css` serves as a real static stylesheet asset.

4. **Verify**:
   - Confirm `assets/`, `src/`, and `build/` exist.
   - Confirm `assets/index.html` and `assets/style.css` exist and contain the expected markup/styles.
   - Report created paths and verification output.
