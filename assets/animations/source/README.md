# Motion source provenance

Human captures: Carnegie Mellon University Graphics Lab, https://mocap.cs.cmu.edu/.
The database was created with funding from NSF EIA-0196217. CMU permits all uses.
BVH conversion: Bruce Hahne / cgspeed; READMEFIRST.txt preserves the converter's
usage notes and permission. Individual files downloaded from the una-dinosauria/
cmu-mocap conversion mirror on2026-10-19. SHA256SUMS.json records source bytes.

35_01 walk;35_17 run/jog;16_01 jump;143_40 sideways walk. Original sources are
preserved. JSON files are derived joint trajectories. Retargeting/adaptations are
ArenaBattle work. No claim that these unarmored captures measure armor performance.

Rebuild using Blender5.2 Python: tools/prepare_cmu_motion.py; then Godot4.7.2
--headless --path . --script res://tools/build_cmu_gaits.gd. Both scripts preserve
the original model GLBs. Runtime needs only the generated .tres libraries.

Directional batch:143_39 backward,143_40 sideways,143_03 start,143_02 stop,69_18/69_16 opposite turns and144_07/144_26 blocks. Original captured root trajectories are retained in derived JSON. Directions use anatomical local coordinates, not time reversal. Downloaded during19–20 October2026.
