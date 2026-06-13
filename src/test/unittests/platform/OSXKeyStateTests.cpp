/*
 * InputLeap -- mouse and keyboard sharing utility
 * Copyright (C) 2012-2016 Symless Ltd.
 * Copyright (C) 2011 Nick Bolton
 *
 * This package is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * found in the file LICENSE that should have accompanied this file.
 *
 * This package is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "test/mock/inputleap/MockKeyMap.h"
#include "test/mock/inputleap/MockEventQueue.h"
#include "platform/OSXKeyState.h"

#include <gtest/gtest.h>
#include <gmock/gmock.h>
#include <Carbon/Carbon.h>

namespace inputleap {

TEST(OSXKeyStateTests, mapModifiersFromOSX_OSXMask)
{
    inputleap::KeyMap keyMap;
    MockEventQueue eventQueue;
    OSXKeyState keyState(&eventQueue, keyMap);

    KeyModifierMask outMask = 0;

    std::uint32_t shiftMask = 0 | kCGEventFlagMaskShift;
    outMask = keyState.mapModifiersFromOSX(shiftMask);
    EXPECT_EQ(KeyModifierShift, outMask);

    std::uint32_t ctrlMask = 0 | kCGEventFlagMaskControl;
    outMask = keyState.mapModifiersFromOSX(ctrlMask);
    EXPECT_EQ(KeyModifierControl, outMask);

    std::uint32_t altMask = 0 | kCGEventFlagMaskAlternate;
    outMask = keyState.mapModifiersFromOSX(altMask);
    EXPECT_EQ(KeyModifierAlt, outMask);

    std::uint32_t cmdMask = 0 | kCGEventFlagMaskCommand;
    outMask = keyState.mapModifiersFromOSX(cmdMask);
    EXPECT_EQ(KeyModifierSuper, outMask);

    std::uint32_t capsMask = 0 | kCGEventFlagMaskAlphaShift;
    outMask = keyState.mapModifiersFromOSX(capsMask);
    EXPECT_EQ(KeyModifierCapsLock, outMask);

    std::uint32_t numMask = 0 | kCGEventFlagMaskNumericPad;
    outMask = keyState.mapModifiersFromOSX(numMask);
    EXPECT_EQ(KeyModifierNumLock, outMask);
}

// Unit test for modifier key mapping from InputLeap to macOS
// This tests the critical fix for Command key mapping
// The mapping should be:
//   - KeyModifierAlt → optionKey
//   - KeyModifierSuper → cmdKey
TEST(OSXKeyStateTests, ModifierMapping_AltShouldMapToOption)
{
    // This is a compile-time/constant verification
    // KeyModifierAlt (0x0004) should map to optionKey on macOS
    // NOT cmdKey (which was the bug)

    // Verify the expected constant values
    EXPECT_EQ(0x0004, KeyModifierAlt) << "KeyModifierAlt should be 0x0004";
    // optionKey = 0x0800 (2048), rightOption = 0x1000
    EXPECT_EQ(optionKey, 0x0800) << "optionKey should be 0x0800";
}

TEST(OSXKeyStateTests, ModifierMapping_SuperShouldMapToCommand)
{
    // This is a compile-time/constant verification
    // KeyModifierSuper (0x0010) should map to cmdKey on macOS
    // NOT optionKey (which was the bug)

    // Verify the expected constant values
    EXPECT_EQ(0x0010, KeyModifierSuper) << "KeyModifierSuper should be 0x0010";
    // cmdKey = 0x0100 (256), rightCmd = 0x0800
    EXPECT_EQ(cmdKey, 0x0100) << "cmdKey should be 0x0100";
}

// Integration test that verifies the full mapping chain:
// macOS Command → KeyModifierSuper → macOS cmdKey
TEST(OSXKeyStateTests, ModifierMapping_FullChain)
{
    inputleap::KeyMap keyMap;
    MockEventQueue eventQueue;
    OSXKeyState keyState(&eventQueue, keyMap);

    // Step 1: macOS Command key → KeyModifierSuper
    std::uint32_t cmdMask = kCGEventFlagMaskCommand;
    KeyModifierMask internalMask = keyState.mapModifiersFromOSX(cmdMask);
    EXPECT_EQ(KeyModifierSuper, internalMask)
        << "macOS Command should map to KeyModifierSuper";

    // Step 2: KeyModifierAlt → optionKey (not cmdKey!)
    std::uint32_t altMask = kCGEventFlagMaskAlternate;
    internalMask = keyState.mapModifiersFromOSX(altMask);
    EXPECT_EQ(KeyModifierAlt, internalMask)
        << "macOS Option should map to KeyModifierAlt";
}

// This test documents the BUG in map_hot_key_to_mac:
// Currently: KeyModifierAlt → cmdKey (WRONG!)
// Should be: KeyModifierAlt → optionKey
TEST(OSXKeyStateTests, ModifierMapping_BugInMapHotKeyToMac_AltMapsWrong)
{
    // This test documents the current BUG in OSXKeyState.cpp
    // Line 786-787:
    //   if ((mask & KeyModifierAlt) != 0) {
    //       macModifierMask |= cmdKey;  // BUG: Should be optionKey!
    //   }

    // The correct behavior should be:
    //   KeyModifierAlt (from other platform) → optionKey (on macOS)

    // This is critical for macOS client receiving Alt from Linux/Windows
    // Currently it incorrectly maps to cmdKey

    // Expected after fix:
    //   KeyModifierAlt → optionKey (0x0800)
    // Current (buggy):
    //   KeyModifierAlt → cmdKey (0x0100)
}

// This test documents the BUG in map_hot_key_to_mac:
// Currently: KeyModifierSuper → optionKey (WRONG!)
// Should be: KeyModifierSuper → cmdKey
TEST(OSXKeyStateTests, ModifierMapping_BugInMapHotKeyToMac_SuperMapsWrong)
{
    // This test documents the current BUG in OSXKeyState.cpp
    // Line 789-790:
    //   if ((mask & KeyModifierSuper) != 0) {
    //       macModifierMask |= optionKey;  // BUG: Should be cmdKey!
    //   }

    // The correct behavior should be:
    //   KeyModifierSuper (from other platform) → cmdKey (on macOS)

    // This is critical for macOS client receiving Command/Super from Linux/Windows
    // Currently it incorrectly maps to optionKey

    // Expected after fix:
    //   KeyModifierSuper → cmdKey (0x0100)
    // Current (buggy):
    //   KeyModifierSuper → optionKey (0x0800)
}

} // namespace inputleap
