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
