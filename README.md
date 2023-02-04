# ADB
Items database and reporting tool. Automatically tracks items you loot and adds to sqlite DB.
Has built-in identify/report commands, database search, configurable actions for picked up items,
inline bonus loot level display, enchats search in bags with disenchant hyperlinks and more.

Has highly customizable output format and some other usefull features.
See **adb help** for details.

**This is under active development**

*******************************************
**!!! PLUGIN REQUIRES MUSH CLIENT r2245 or LATER !!!**
*******************************************

Some screenshots:
![image](https://user-images.githubusercontent.com/118027636/214982543-8e73df32-be2e-4950-bbfb-e80dfaf31e83.png)
![image](https://user-images.githubusercontent.com/118027636/214982660-f88b4e44-4307-4a11-bfff-149b221e4467.png)
![image](https://user-images.githubusercontent.com/118027636/216733840-fed1d047-da0f-4eb6-af30-d0c257689a28.png)
![image](https://user-images.githubusercontent.com/118027636/214982774-c8d2077d-4674-4757-b81b-55e225745e47.png)
![image](https://user-images.githubusercontent.com/118027636/214982993-9775707e-ed6b-46e3-8890-75b2f46f8e02.png)
![image](https://user-images.githubusercontent.com/118027636/214982206-5414e08f-4f09-4c5e-8fd5-4ed4a943dc67.png)
![image](https://user-images.githubusercontent.com/118027636/215364023-c58b8007-5629-4235-9a74-54cb0aad6de8.png)

# HyperlinkMapperNotes.xml
Parses mapper notes for current room and shows clickable hyperlinks with certain commands.
Also updates "mappernotecommand" alias with those commands to be used with macro keys etc.

Just add Hyperlink() to any part of mapper note:
Hyperlink(whatever_commnd_in_this_room;another_cmd)

When passing by this room plugin will show clickable hyperlink with provided command(s) 
and update "mappernotecommand" alias with the same command(s).

For ex in room [6348]
Mapper note: key on a mountain goat Hyperlink(qw mountain goat)
When passing by it will allow you to click a link to do "qw mountain goat",
you can also bind mappernotecommand to any key and have the same executed without clicking.

With recent change to build-in mapper code (thanks Fiendish for implementing requested change)
this plugin is going to be updated to include hyperlinks to room cexits as well. (pending)

# TranscendenceController.xml
Plugin to simplify controller task in Transcendence epic.

![image](https://user-images.githubusercontent.com/118027636/214983696-e29adcb9-0014-495a-8beb-afc17555dbd0.png)

# ExitTo.xml
Allows you to make mapper cexits to a direction with a given room name.
Good example is Vlad entrance, where room [15973] always have exit to
"Before the Grand Gates of Castle Vlad-Shamir" but direction changes.
Can be easily added to mapper like this:
```
mapper cexit exit_to Before the Grand Gates of Castle Vlad-Shamir;;wait(0.3)
```

Also have maze_to command, which uses separate maze-solver plugin to get to given room #
That's somewhat experimental and has some bugs, but works in most cases.

# Desa.xml
Tiny plugin without help.
Allows you to automatically cast desolation untill you kill everything without stacking.
des - cast desolation (will continue casting on success)
desc - clear desolation stacks, rarely used when something goes off due to stuns etc.
