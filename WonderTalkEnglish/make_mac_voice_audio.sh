#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p Audio
VOICE="${1:-Samantha}"
echo "Using macOS voice: $VOICE"
say -v "$VOICE" -r 155 -o Audio/rates_full.aiff 'When a central bank raises interest rates, borrowing usually becomes more expensive. Businesses may postpone investment projects, while households may reduce spending. Higher interest rates can also change the way investors value companies. Analysts often discount future cash flows to estimate what a business is worth today. When the discount rate rises, distant cash flows generally become less valuable in today'"'"'s terms. This is one reason why fast-growing companies can be sensitive to interest rate changes. However, stock prices also depend on profits, competition, risk and market expectations. A thoughtful investor asks not only what changed, but also what the market had already expected.'
say -v "$VOICE" -r 155 -o Audio/rates_01.aiff 'When a central bank raises interest rates, borrowing usually becomes more expensive.'
say -v "$VOICE" -r 155 -o Audio/rates_02.aiff 'Businesses may postpone investment projects, while households may reduce spending.'
say -v "$VOICE" -r 155 -o Audio/rates_03.aiff 'Higher interest rates can also change the way investors value companies.'
say -v "$VOICE" -r 155 -o Audio/rates_04.aiff 'Analysts often discount future cash flows to estimate what a business is worth today.'
say -v "$VOICE" -r 155 -o Audio/rates_05.aiff 'When the discount rate rises, distant cash flows generally become less valuable in today'"'"'s terms.'
say -v "$VOICE" -r 155 -o Audio/rates_06.aiff 'This is one reason why fast-growing companies can be sensitive to interest rate changes.'
say -v "$VOICE" -r 155 -o Audio/rates_07.aiff 'However, stock prices also depend on profits, competition, risk and market expectations.'
say -v "$VOICE" -r 155 -o Audio/rates_08.aiff 'A thoughtful investor asks not only what changed, but also what the market had already expected.'
say -v "$VOICE" -r 155 -o Audio/renaissance_full.aiff 'The Renaissance did not begin with a single event or a single brilliant artist. It developed gradually in a network of Italian cities, including Florence and Venice. Trade and finance helped some merchant families accumulate substantial wealth. These families supported painters, architects and scholars through patronage. Patronage created opportunities, but it also shaped which projects received attention. Competition between city-states encouraged rulers to display their prestige through art. At the same time, humanist scholars studied ancient Greek and Roman writing with renewed interest. The Renaissance emerged from the interaction of economic, political and intellectual forces.'
say -v "$VOICE" -r 155 -o Audio/renaissance_01.aiff 'The Renaissance did not begin with a single event or a single brilliant artist.'
say -v "$VOICE" -r 155 -o Audio/renaissance_02.aiff 'It developed gradually in a network of Italian cities, including Florence and Venice.'
say -v "$VOICE" -r 155 -o Audio/renaissance_03.aiff 'Trade and finance helped some merchant families accumulate substantial wealth.'
say -v "$VOICE" -r 155 -o Audio/renaissance_04.aiff 'These families supported painters, architects and scholars through patronage.'
say -v "$VOICE" -r 155 -o Audio/renaissance_05.aiff 'Patronage created opportunities, but it also shaped which projects received attention.'
say -v "$VOICE" -r 155 -o Audio/renaissance_06.aiff 'Competition between city-states encouraged rulers to display their prestige through art.'
say -v "$VOICE" -r 155 -o Audio/renaissance_07.aiff 'At the same time, humanist scholars studied ancient Greek and Roman writing with renewed interest.'
say -v "$VOICE" -r 155 -o Audio/renaissance_08.aiff 'The Renaissance emerged from the interaction of economic, political and intellectual forces.'
echo "Done: AIFF audio created in Audio/. Add this folder to the Xcode target."
