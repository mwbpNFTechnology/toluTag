# toluTag Bill of Materials

Everything needed to build and program one toluTag.

Values marked **[verify]** are placeholders. Fill in the exact part number or
value from your own schematic before publishing, so the BOM matches the boards
you ship.

## Per-tag components

These go into every finished tag.

| Ref | Component | Value / Part | Package | Qty | Notes |
|---|---|---|---|---|---|
| PCB1 | Printed circuit board | toluTag PCB [verify: layers, thickness, rigid/flex] | Sticker / Textile / Embedded variant | 1 | Gerbers in this folder |
| U1 | Secure element | NXP SE051C [verify: exact variant] | [verify: SON / HX2QFN] | 1 | The chip; generates and holds the key |
| C1 | Capacitor | [verify: value] | 0603 | 1 | LC resonance tuning for the NFC field |
| L1 | NFC antenna | Coil [verify: PCB trace or discrete] | [verify] | 1 | If etched into the PCB, mark as part of PCB1 |

> Passive NFC tags are powered by the reader's field, so there is no battery and
> no power regulator. Confirm against your schematic whether the antenna is a
> PCB trace (no separate part) or a discrete coil.

## Tools

Bought once, used across many tags. Not part of a finished tag.

| Item | Suggested | Notes |
|---|---|---|
| Solder paste | [verify: leaded / lead-free] | For attaching the SE051C and the 0603 cap |
| Soldering iron | Fine tip | The SE051C is small; work carefully |
| NFC reader | iPhone with NFC, or an ISO 14443 PC/SC contactless reader (ACR1552-class) | Needed to provision and program the tag |

## Notes

- To program a tag you need either the iOS app (iPhone with NFC) or the Java CLI
  with a PC/SC reader. Any ISO 14443 reader (ACR1552-class) works.
- Order the PCB from the Gerbers in this folder. Minimum order quantities from
  most fabs are 5 boards, so a single build still yields spares.
- Quantities above are per one tag unless noted.
