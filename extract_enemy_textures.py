#!/usr/bin/env python3
"""
Extract enemy zombie textures from Unity bundle and organize by enemy type.

Strategy:
- Main atlas (nk21_charasprite_assets_all.bundle): ~942 sprites numbered 000-942
- NPC atlas (nk21_chara_npc_assets_all.bundle): 7 sprites (000-003, 026, 106-107)
- 9500-9513 are larger 128x64 sprites (likely special NPCs/portraits)

The bundle is already zombified. We extract all sprites and distribute them
across enemy type directories. Player character sprites (kunio/riki/onizuka/
sugata/gouda) are already in assets/characters/, so we focus on what remains.

Enemy types from enemy_defs.gd:
  Normal: walker, runner, fat, delinquent, bosozoku
  Elite:  bosozoku_leader, zombie_butcher
"""
import os
import UnityPy
from PIL import Image
import io

BASE = "/home/user/Doubao/chats/38443725384655106"
MAIN_BUNDLE = f"{BASE}/热血物语-v1.0下载/_解压_RiverCityRival/River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/nk21_charasprite_assets_all.bundle"
NPC_BUNDLE = f"{BASE}/热血物语-v1.0下载/_解压_RiverCityRival/River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/nk21_chara_npc_assets_all.bundle"

OUTPUT = f"{BASE}/hot-blood-zombie/assets/enemies"

# Enemy type directories to create
ENEMY_TYPES = [
    "walker",          # 普通丧尸 (zombie_normal)
    "runner",          # 快速丧尸 (zombie_fast)
    "fat",             # 重装/胖子丧尸 (zombie_heavy)
    "delinquent",      # 不良少年
    "bosozoku",        # 暴走族
    "bosozoku_leader", # 暴走族干部 (elite)
    "zombie_butcher",  # 丧尸屠夫 (elite)
]

# Animation subcategories
ANIM_CATS = ["idle", "walk", "attack", "hurt", "death"]


def extract_sprites_from_bundle(bundle_path, tag=""):
    """Extract all sprites from a bundle as {name: PIL.Image}."""
    result = {}
    print(f"  Loading {os.path.basename(bundle_path)}...")
    env = UnityPy.load(bundle_path)
    count = 0
    for obj in env.objects:
        try:
            if obj.type.name == "Sprite":
                data = obj.read()
                name = getattr(data, "m_Name", getattr(data, "name", "unknown"))
                img = data.image
                if name not in result:
                    result[name] = img
                    count += 1
        except Exception as e:
            pass
    print(f"  Extracted {count} sprites ({tag})")
    return result


def save_image(img, path):
    """Save PIL Image to path."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if img.mode == "RGBA":
        img.save(path, "PNG")
    else:
        img = img.convert("RGBA")
        img.save(path, "PNG")


def main():
    # Create enemy type directories
    for etype in ENEMY_TYPES:
        os.makedirs(os.path.join(OUTPUT, etype), exist_ok=True)

    # Extract from both bundles
    print("=== Extracting sprites ===")
    main_sprites = extract_sprites_from_bundle(MAIN_BUNDLE, "main atlas")
    npc_sprites = extract_sprites_from_bundle(NPC_BUNDLE, "npc atlas")

    # Combine: NPC sprites are higher quality / more important
    all_sprites = dict(main_sprites)
    all_sprites.update(npc_sprites)  # NPC overrides main if same name

    print(f"\nTotal unique sprites: {len(all_sprites)}")

    # Sort sprite names numerically
    def sprite_num(name):
        try:
            return int(name)
        except ValueError:
            return 999999

    sorted_names = sorted(all_sprites.keys(), key=sprite_num)
    print(f"Sprite range: {sorted_names[0]} to {sorted_names[-1]}")

    # Categorize sprites:
    # - Sprites 9500+ are large (128x64) -> elite enemies
    # - NPC bundle sprites (000-003, 026, 106, 107) -> special/boss NPCs
    # - Remaining sprites distributed across normal enemy types
    #
    # Since we can't precisely identify which sprite is which character without
    # the original mapping, we use a distribution strategy:
    # - The main atlas has ~942 sprites
    # - Player characters use a significant portion
    # - Enemy sprites are distributed in blocks

    # Identify special sprites
    large_sprites = [n for n in sorted_names if sprite_num(n) >= 9500]
    npc_only_sprites = [n for n in npc_sprites.keys() if sprite_num(n) < 9500]

    # Regular sprites from main atlas
    regular_sprites = [n for n in sorted_names if sprite_num(n) < 9500]

    print(f"  Large sprites (9500+): {len(large_sprites)}")
    print(f"  NPC sprites: {npc_only_sprites}")
    print(f"  Regular sprites: {len(regular_sprites)}")

    # ---- Distribution strategy ----
    # We have ~942 regular sprites + 7 NPC + 14 large = ~963 sprites
    # 5 player characters are already extracted, so roughly half are enemies
    #
    # Distribution:
    # - Elite enemies get the large sprites (9500-9513, 14 sprites total)
    #   bosozoku_leader: 7 sprites
    #   zombie_butcher: 7 sprites
    # - NPC sprites go to bosozoku_leader (they're important characters)
    # - Regular sprites split across 5 normal types
    #
    # For each type, we create idle/walk/attack/hurt/death subdirectories
    # and place representative frames.

    saved_count = 0

    # --- Elite enemies: large sprites (9500-9513) ---
    print("\n=== Assigning elite enemy sprites ===")
    half = len(large_sprites) // 2
    for i, name in enumerate(large_sprites[:half]):
        img = all_sprites[name]
        # Assign animation category based on index
        cat = ANIM_CATS[min(i, len(ANIM_CATS)-1)]
        out_path = os.path.join(OUTPUT, "bosozoku_leader", cat, f"frame_{i:03d}.png")
        save_image(img, out_path)
        saved_count += 1
        print(f"  bosozoku_leader/{cat}/frame_{i:03d}.png  ({name}, {img.size})")

    for i, name in enumerate(large_sprites[half:]):
        img = all_sprites[name]
        cat = ANIM_CATS[min(i, len(ANIM_CATS)-1)]
        out_path = os.path.join(OUTPUT, "zombie_butcher", cat, f"frame_{i:03d}.png")
        save_image(img, out_path)
        saved_count += 1
        print(f"  zombie_butcher/{cat}/frame_{i:03d}.png  ({name}, {img.size})")

    # NPC sprites -> bosozoku_leader as additional idle frames
    for i, name in enumerate(npc_only_sprites):
        img = all_sprites[name]
        out_path = os.path.join(OUTPUT, "bosozoku_leader", "idle", f"npc_{name}.png")
        save_image(img, out_path)
        saved_count += 1
        print(f"  bosozoku_leader/idle/npc_{name}.png  ({img.size})")

    # --- Normal enemies: distribute regular sprites ---
    # We have ~942 regular sprites. Distribute across 5 normal types.
    # Each type gets ~188 sprites. Within each type, organize by animation.
    #
    # Animation grouping: in the original game, sprites are grouped into
    # animation sets. We'll assume groups of ~14 frames per animation set
    # (matching the kunio pattern of 000.png + 000_1..000_13).
    #
    # For simplicity and robustness, we'll:
    # 1. Split regular sprites into 5 roughly equal blocks
    # 2. Within each block, take frames and distribute to idle/walk/attack/hurt/death

    normal_types = ["walker", "runner", "fat", "delinquent", "bosozoku"]
    n = len(regular_sprites)
    block_size = n // len(normal_types)

    print(f"\n=== Distributing {n} regular sprites across {len(normal_types)} normal types ===")
    print(f"  Block size: ~{block_size} sprites per type")

    for t_idx, etype in enumerate(normal_types):
        start = t_idx * block_size
        end = start + block_size if t_idx < len(normal_types) - 1 else n
        block = regular_sprites[start:end]

        # Within the block, split frames across animation categories
        # Use 5 animation categories, each getting a portion
        per_cat = max(1, len(block) // len(ANIM_CATS))

        print(f"\n  [{etype}] block: sprites {block[0]}-{block[-1]} ({len(block)} sprites)")

        for c_idx, cat in enumerate(ANIM_CATS):
            cat_start = c_idx * per_cat
            cat_end = cat_start + per_cat if c_idx < len(ANIM_CATS) - 1 else len(block)
            cat_frames = block[cat_start:cat_end]

            for f_idx, sname in enumerate(cat_frames):
                img = all_sprites[sname]
                out_path = os.path.join(OUTPUT, etype, cat, f"{sname}.png")
                save_image(img, out_path)
                saved_count += 1

            print(f"    {cat}: {len(cat_frames)} frames (sprites {cat_frames[0] if cat_frames else '?'}-{cat_frames[-1] if cat_frames else '?'})")

    # ---- Summary ----
    print(f"\n{'='*60}")
    print(f"=== EXTRACTION COMPLETE ===")
    print(f"{'='*60}")
    print(f"Total sprites saved: {saved_count}")
    print(f"\nDirectory structure:")
    for etype in ENEMY_TYPES:
        etype_dir = os.path.join(OUTPUT, etype)
        total = 0
        for cat in ANIM_CATS:
            cat_dir = os.path.join(etype_dir, cat)
            if os.path.exists(cat_dir):
                count = len([f for f in os.listdir(cat_dir) if f.endswith('.png')])
                total += count
                print(f"  {etype}/{cat}: {count} frames")
        print(f"  --- {etype} total: {total} frames")

    # Also create a default texture for each enemy type (first idle frame)
    print(f"\n=== Creating default preview textures ===")
    for etype in ENEMY_TYPES:
        idle_dir = os.path.join(OUTPUT, etype, "idle")
        if os.path.exists(idle_dir):
            frames = sorted([f for f in os.listdir(idle_dir) if f.endswith('.png')])
            if frames:
                src = os.path.join(idle_dir, frames[0])
                dst = os.path.join(OUTPUT, etype, "default.png")
                img = Image.open(src)
                img.save(dst, "PNG")
                print(f"  {etype}/default.png <- idle/{frames[0]}")


if __name__ == "__main__":
    main()
