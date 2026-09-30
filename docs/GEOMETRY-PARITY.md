# Building geometry parity verification

Verified in Godot 4.6.3, headless Linux: **16,381 checks passed, zero failures**.

`scripts/building_geometry.gd` ports the final AEGEA 5.6 overrides in
`architecture-game-55.js`, `settlements.js`, and `company.js`. This includes:

- Approved half extents, oriented-rectangle SAT with the original 0.01 m tolerance
- All 15 inn wall, room, furniture and column rectangles; walkable courtyard/entrance
- Open gates retaining solid side posts and the source radius-aware central opening
- Final architecture solidity, including solid quarry/workbench and non-solid tannery
- Original 16 m placement limit, road slope limit of 1.6 m, other slope limit of 3.2 m
- Size-based rotated terrain samples, source tree-clearance and company-project rules
- Foundation material surcharge, floor elevation and depth
- Source foundation-ground lookup, outside-face approach points and signed clearance
- Four-meter road / one-meter building grid and JavaScript negative-half snap behavior

## Run the checked-in oracle

From the native project directory:

```sh
XDG_DATA_HOME=/tmp/aegea-geometry-data \
XDG_CONFIG_HOME=/tmp/aegea-geometry-config \
XDG_CACHE_HOME=/tmp/aegea-geometry-cache \
godot --headless --path . --script res://tests/test_parity_geometry.gd
```

The suite loads `tests/fixtures/geometry_browser_reference.json` automatically.
It combines 234 explicit edge/regression assertions with independently computed
browser reference results: 5,000 collision queries, 5,000 rotated footprint pairs,
and 4,000 placement scenarios, plus successful/rejected cost and foundation checks.
Numeric comparisons tolerate 0.00005 m for Godot vector precision; collision,
placement decisions and rejection messages must match exactly.

The recorded output is `tests/fixtures/geometry_verification.log`.

## Regenerate from the unchanged browser source

```sh
node tests/generate_geometry_reference.mjs /path/to/AEGEA-5.6/src
```

The generator imports the original browser functions directly. It does not import
or reproduce the native implementation. It installs settlement, company and
architecture placement in the original order, loads the `content-53.js` cost
overrides, and uses a fixed random seed (813467). Fixture metadata records SHA-256
hashes of its source inputs. No Node.js runtime is needed to play the native game
or to run the checked-in Godot fixtures.

These checks establish geometry/rule parity for the covered cases. They do not
establish iPhone frame rate, visual quality, or full end-to-end gameplay parity.
