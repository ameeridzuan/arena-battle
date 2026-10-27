"""Rebuild the supplied Yixuan PMX as an Ashen Warden skin with weighted spring chains."""
from build_astra_skin import ROOT, build

if __name__ == '__main__':
    build(source=ROOT / 'Skins/Yixuan', pmx_name='仪玄.pmx', base_model='ashen_warden',
          skin_name='Yixuan', node_prefix='Yixuan', body_name='YixuanBody', output_name='yixuan',
          rig_name='AshenWardenRig', weapon_prefix='Longsword',
          skipped_materials=('髮+', '武器', '武器_alpha'))
