# TopMeOffFromBank

Automatically withdraws items from your bank to maintain specified quantities in your bags.

## Description

TopMeOffFromBank is inspired by TopMeOff but works with your bank instead of vendors. When you open your bank, it automatically checks your bags and withdraws items from the bank to reach your configured quantities.

## Features

- Automatically withdraws items when you open the bank
- Configure specific quantities for each item
- Handles multiple stacks and partial withdrawals intelligently
- Works seamlessly with Bagshui addon (automatically triggers restack when done)
- Clean, minimal chat output showing what was withdrawn
- Retries until all items are topped off (up to 10 attempts)

## Installation

1. Extract the `TopMeOffFromBank` folder to your `Interface\AddOns` directory
2. Restart WoW or reload UI (`/reload`)

## Usage

### Commands

- `/tmob add <itemlink> <amount>` - Add an item to your withdrawal list (shift-click an item for the link)
- `/tmob ls` - List all configured items
- `/tmob ls need` - Show items you need
- `/tmob ls have` - Show items you have
- `/tmob del <itemlink>` - Remove an item from the list
- `/tmob reset` - Clear all items from the list
- `/tmob debug` - Show debug log window (for troubleshooting)

### Examples

```
/tmob add [Major Mana Potion] 20
/tmob add [Nightfin Soup] 20
/tmob ls
```

When you open your bank, the addon will automatically withdraw items to reach your configured quantities.

### Output

The addon provides clean output showing what was withdrawn:

```
<TopMeOffFromBank> [Major Mana Potion] withdrew 20
<TopMeOffFromBank> [Nightfin Soup] withdrew 5
<TopMeOffFromBank> [Spirit of Zanza] withdrew 1
```

## Compatibility

- **World of Warcraft Classic (Vanilla 1.12)**
- **Bagshui**: Fully compatible - automatically triggers restack when withdrawals are complete
- Works with all bag addons

## Technical Details

- Uses timed queue system with 200ms delays between withdrawals
- Waits 500ms after bank opens for UI to settle
- Rechecks bags after each batch with 1.5s delays (Bagshui reorganization time)
- Maximum 10 recheck attempts to ensure all items are withdrawn
- Compares starting vs. ending bag counts for accurate reporting

## Configuration

All settings are saved per character in the `bankItemsWanted` SavedVariable.

## Credits

Based on TopMeOff by melba - adapted for bank withdrawals.

## Version

1.0 - Initial release
