This directory stores pristine base disk images.

Current images:

- `LSX162b.d88` for the main LSX-Dodgers deployment flow
- `S-OS.d88` for the optional S-OS deployment flow

Rules:

- Treat these files as read-only masters.
- Deploy by copying them into `../work/`.
- Never write build outputs into these originals.
