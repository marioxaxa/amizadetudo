# TileSet Standard

All levels inherit `res://node_2d.tscn`, which uses the shared resource
`res://platform_tileset.tres`. New levels must be created from
`res://levels/level_template.tscn` so the same TileMap and gameplay rules are
kept.

## Standard Tiles

| Atlas tile | Behavior |
| --- | --- |
| `0:0` | Hazard (`hazard = true`) |
| `1:0` | Solid ground |
| `2:0` | One-way platform |
| `3:0` | Solid North magnetic field |
| `4:0` | Solid South magnetic field |
| `5:0` | North magnetic slope rising right |
| `6:0` | South magnetic slope rising left |

Do not create per-level TileSet resources. Configure the shared
`platform_tileset.tres` resource when a standard tile needs to change.
