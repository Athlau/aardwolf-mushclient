# ADB
Items database, reporting and enchanting tool.
Automatically tracks items you loot and adds to sqlite DB.
Has built-in identify/report commands, database search, configurable actions for picked up items,
inline bonus loot level display, enchats search in bags with disenchant hyperlinks, single/batch
enchanting modes and more.
Has highly customizable output format and other usefull features.

See **adb help** for details.

**This is under active development**

*******************************************
**!!! PLUGIN REQUIRES MUSH CLIENT r2249 or LATER !!!**
*******************************************

*******************************************
**!!! Most of the functionality requires IDENTIFY WISH !!!**
*******************************************

Some screenshots:
![image](https://user-images.githubusercontent.com/118027636/214982543-8e73df32-be2e-4950-bbfb-e80dfaf31e83.png)
![image](https://user-images.githubusercontent.com/118027636/214982660-f88b4e44-4307-4a11-bfff-149b221e4467.png)
![image](https://user-images.githubusercontent.com/118027636/216733840-fed1d047-da0f-4eb6-af30-d0c257689a28.png)
![image](https://user-images.githubusercontent.com/118027636/230222703-3b538dc5-adbb-44eb-babf-4823732f6891.png)
![image](https://user-images.githubusercontent.com/118027636/214982774-c8d2077d-4674-4757-b81b-55e225745e47.png)
![image](https://user-images.githubusercontent.com/118027636/218615827-6bd36e72-e18b-4df3-8457-109899654980.png)
![image](https://user-images.githubusercontent.com/118027636/214982993-9775707e-ed6b-46e3-8890-75b2f46f8e02.png)
![image](https://user-images.githubusercontent.com/118027636/214982206-5414e08f-4f09-4c5e-8fd5-4ed4a943dc67.png)
![image](https://user-images.githubusercontent.com/118027636/215364023-c58b8007-5629-4235-9a74-54cb0aad6de8.png)

# HyperlinkMapperNotes.xml
Parses mapper notes for current room and shows clickable hyperlinks with certain commands.
Also updates "mappernotecommand" alias with those commands to be used with macro keys etc.
UPDATE: if you're running client r2249 or later then it will show current room cexits
as Hyperlinks too.

Just add Hyperlink() to any part of mapper note:
Hyperlink(whatever_commnd_in_this_room;another_cmd)

When passing by this room plugin will show clickable hyperlink with provided command(s) 
and update "mappernotecommand" alias with the same command(s).

For ex in room [6348]
Mapper note: key on a mountain goat Hyperlink(qw mountain goat)
When passing by it will allow you to click a link to do "qw mountain goat",
you can also bind mappernotecommand to any key and have the same executed without clicking.

![image](https://user-images.githubusercontent.com/118027636/216854746-f7347f66-4a08-405d-9419-b6e1b242bdb2.png)
![image](https://user-images.githubusercontent.com/118027636/216854810-197cdaf7-8689-4afd-83d4-dea113c9b2ee.png)

# TranscendenceController.xml
Plugin to simplify controller task in Transcendence epic.

![image](https://user-images.githubusercontent.com/118027636/214983696-e29adcb9-0014-495a-8beb-afc17555dbd0.png)

# ExitTo.xml
Allows you to make mapper cexits to a direction with a given room name
or minimap output.
Good example is Vlad entrance, where room [15973] always have exit to
"Before the Grand Gates of Castle Vlad-Shamir" but direction changes.
Can be easily added to mapper like this:
```
mapper cexit exit_to Before the Grand Gates of Castle Vlad-Shamir;;wait(0.3)
```

Instead of "hunting Pete" one could do something like this:
```
maze_to_noresume_once
In [34037] Winding tunnels (G), mapper cexit wait(0.1);maze_to 34042;wait(30)
In [34042] Winding tunnels, mapper cexit wait(0.1);;minimap_to [ . >|];;wait(0.1)
```

Also have maze_to command, which uses separate maze-solver plugin (Trachx_MazeSolver.xml) to get to given room #
That's somewhat experimental and has some bugs, but works in most cases.
```
In [19648] The Skullgore Plain, mapper cexit wait(0.1);;maze_to 19652;;wait(30)
In [19652] The Skullgore Plain, mapper cexit exit_to The Dark Path;;wait(0.1)
```


# Desa.xml
Tiny plugin without help.
Allows you to automatically cast desolation untill you kill everything without stacking.
des - cast desolation (will continue casting on success)
desc - clear desolation stacks, rarely used when something goes off due to stuns etc.
