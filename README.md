# Snake Game VHDL

A classic Snake game implemented in VHDL for FPGA boards with VGA output.

## About

This project is a hardware implementation of the classic Snake game written in VHDL. The game runs on FPGA boards and outputs video to a VGA monitor. Score is displayed both on-screen and on a 7-segment display.

## Features

- **VGA Output:** 640x480 @ 60Hz resolution
- **Game Grid:** 40x30 cells (16x16 pixels per cell)
- **Maximum Snake Length:** 100 segments
- **5 Difficulty Levels:** Speed increases as you progress
- **Poison Fruit:** Appears from level 2 onwards
- **Score Display:** On-screen and 7-segment display
- **Game States:** Idle, Playing, Paused, Game Over
- **Button Controls:** Up, Down, Left, Right, Center (pause/restart)

## Hardware Requirements

- FPGA Board (tested on Basys 3 / Nexys series)
- VGA Monitor
- 100 MHz system clock

## Pin Mapping

| Signal | Description |
|--------|-------------|
| clk | 100 MHz system clock |
| btnU | Up button |
| btnD | Down button |
| btnL | Left button |
| btnR | Right button |
| btnC | Center button (pause/restart) |
| vgaRed[3:0] | VGA Red channel |
| vgaGreen[3:0] | VGA Green channel |
| vgaBlue[3:0] | VGA Blue channel |
| Hsync | VGA Horizontal sync |
| Vsync | VGA Vertical sync |
| seg[6:0] | 7-segment display segments |
| an[3:0] | 7-segment display anodes |

## Project Structure

| File | Description |
|------|-------------|
| `snake_top.vhd` | Top-level module that instantiates all components |
| `game_logic.vhd` | Main game logic, rendering, and state machine |
| `vga_controller.vhd` | VGA timing and signal generation (640x480 @ 60Hz) |
| `clock_divider.vhd` | Generates 50MHz VGA clock and 25Hz game clock |
| `lfsr.vhd` | 8-bit Linear Feedback Shift Register for random number generation |
| `segment_display.vhd` | 7-segment display controller for score output |

## Controls

| Button | Action |
|--------|--------|
| Up | Move snake up |
| Down | Move snake down |
| Left | Move snake left |
| Right | Move snake right |
| Center (short press) | Pause/Resume game |
| Center (long press ~2s) | Restart game |

## Game Mechanics

- Eat food (regular fruit) to grow and increase score
- Avoid poison fruit (appears from level 2)
- Don't hit the walls or yourself
- Speed increases with difficulty level
- Score is displayed on 7-segment display (0-999)

## Clock Domains

- **100 MHz:** System clock input
- **50 MHz:** VGA pixel clock
- **25 Hz:** Game logic update rate

## Installation

1. Open the project in Vivado (or your preferred FPGA IDE)
2. Add all `.vhd` files to the project
3. Create/modify constraints file for your specific FPGA board
4. Synthesize and implement the design
5. Generate bitstream and program the FPGA
6. Connect VGA monitor and play!

## License

This project was developed for educational purposes.
