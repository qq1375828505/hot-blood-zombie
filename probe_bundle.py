#!/usr/bin/env python3
"""Probe Unity bundle to list all sprite names and categorize by character."""
import os
import sys
import UnityPy
from collections import defaultdict

BUNDLES = [
    "/home/user/Doubao/chats/38443725384655106/热血物语-v1.0下载/_解压_RiverCityRival/River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/nk21_charasprite_assets_all.bundle",
    "/home/user/Doubao/chats/38443725384655106/热血物语-v1.0下载/_解压_RiverCityRival/River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/nk21_chara_npc_assets_all.bundle",
]

# Player characters we already have
PLAYER_NAMES = {"kunio", "riki", "gouda", "onizuka", "sugata"}

def main():
    all_sprites = []
    all_textures = []

    for bundle_path in BUNDLES:
        print(f"\n=== Loading: {os.path.basename(bundle_path)} ===")
        try:
            env = UnityPy.load(bundle_path)
        except Exception as e:
            print(f"  ERROR: {e}")
            continue

        for obj in env.objects:
            try:
                if obj.type.name == "Sprite":
                    data = obj.read()
                    name = getattr(data, "m_Name", getattr(data, "name", "unknown"))
                    # Get texture rect info
                    tex_rect = getattr(data, "m_Rect", None)
                    all_sprites.append((os.path.basename(bundle_path), name, tex_rect, data))
                elif obj.type.name == "Texture2D":
                    data = obj.read()
                    name = getattr(data, "m_Name", getattr(data, "name", "unknown"))
                    w = getattr(data, "m_Width", 0)
                    h = getattr(data, "m_Height", 0)
                    all_textures.append((os.path.basename(bundle_path), name, w, h, data))
            except Exception as e:
                pass

    print(f"\nTotal Sprites: {len(all_sprites)}")
    print(f"Total Textures: {len(all_textures)}")

    # Print all sprite names grouped by prefix
    print("\n=== All Sprite Names ===")
    name_groups = defaultdict(list)
    for bname, sname, rect, data in all_sprites:
        # Try to extract character prefix from name
        # Names might be like "chara_001_idle_01" or similar
        prefix = sname.split("_")[0] if "_" in sname else sname[:6]
        name_groups[prefix].append((bname, sname, rect))

    for prefix in sorted(name_groups.keys()):
        items = name_groups[prefix]
        print(f"\n  [{prefix}] ({len(items)} sprites)")
        for bname, sname, rect in items[:5]:
            rect_str = f"{rect.width}x{rect.height} at ({rect.x},{rect.y})" if rect else "no rect"
            print(f"    {sname}  [{rect_str}]")
        if len(items) > 5:
            print(f"    ... and {len(items)-5} more")

    # Print all texture names
    print("\n=== All Texture2D Names ===")
    for bname, tname, w, h, data in all_textures:
        is_player = any(pn in tname.lower() for pn in PLAYER_NAMES)
        marker = "[PLAYER]" if is_player else "[ENEMY]"
        print(f"  {marker} [{bname}] {tname}  ({w}x{h})")

if __name__ == "__main__":
    main()
