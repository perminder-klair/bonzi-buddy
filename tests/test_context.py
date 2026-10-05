import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('context', Path(__file__).resolve().parents[1] / 'bin/context.py')
context = importlib.util.module_from_spec(spec)
spec.loader.exec_module(context)

class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.window = {'class':'kitty','title':'private.txt','at':[1930,20],'size':[400,500], 'monitor':1,'fullscreen':2,'workspace':{'id':3,'name':'3'}}
        self.monitors = [{'id':1,'name':'DP-1','x':1920,'y':0,'width':2160,'height':3840,'scale':2,'transform':1,'focused':True}]

    def test_title_opt_in_and_logical_rotated_geometry(self):
        d=context.desktop_snapshot(self.window,self.monitors,windows=True,titles=False)
        self.assertNotIn('title', d)
        self.assertEqual(d['rect'], {'x':10,'y':20,'width':400,'height':500})
        self.assertEqual(d['monitor']['width'],1920)
        self.assertEqual(d['monitor']['height'],1080)
        self.assertEqual(d['side'],'left')
        self.assertEqual(context.desktop_snapshot(self.window,self.monitors,windows=True,titles=True)['title'],'private.txt')

    def test_privacy_when_windows_disabled_but_focus_needed(self):
        d=context.desktop_snapshot(self.window,self.monitors,windows=False,titles=True,blocked_apps='firefox, KITTY')
        self.assertNotIn('title',d)
        self.assertNotIn('app',d)
        self.assertNotIn('rect',d)
        self.assertTrue(d['blockedApp'])
        self.assertTrue(d['fullscreen'])

    def test_empty_desktop_and_unavailable_are_distinct(self):
        self.assertTrue(context.desktop_snapshot({},self.monitors)['available'])
        self.assertFalse(context.desktop_snapshot(None,None)['available'])

    def test_cpu_delta_does_not_count_guest_twice(self):
        self.assertEqual(context.cpu_percent([100,0,50,850,0,0,0,0,10,0],[130,0,70,900,0,0,0,0,30,0]),50)
        self.assertIsNone(context.cpu_percent(None,[1,2,3,4]))

if __name__=='__main__':unittest.main()
