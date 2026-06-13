{ ... }:
{
  programs.plasma = {
    shortcuts = {
      ActivityManager.switch-to-activity-cbef4d8b-ee87-4267-9087-99926a9d4640 = [ ];
    };
    configFile = {
      kactivitymanagerdrc.activities.cbef4d8b-ee87-4267-9087-99926a9d4640 = "Default";
      kwinrc.Desktops.Id_1 = "ff808ca8-e8a7-43c7-971b-fbb976fd8f50";
      kwinrc."Tiling/ff808ca8-e8a7-43c7-971b-fbb976fd8f50/20ddf343-f5de-4e01-a9b8-35c13ca692c2".padding = 4;
      kwinrc."Tiling/ff808ca8-e8a7-43c7-971b-fbb976fd8f50/20ddf343-f5de-4e01-a9b8-35c13ca692c2".tiles =
        "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
      kwinrc."Tiling/ff808ca8-e8a7-43c7-971b-fbb976fd8f50/a4a8dfa8-c6c9-4b6e-8d4a-daa1c8f565bf".padding = 4;
      kwinrc."Tiling/ff808ca8-e8a7-43c7-971b-fbb976fd8f50/a4a8dfa8-c6c9-4b6e-8d4a-daa1c8f565bf".tiles =
        "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
      kwinrc."Tiling/ff808ca8-e8a7-43c7-971b-fbb976fd8f50/ec653ff8-619c-474a-9428-45a2e1cb0fab".padding = 4;
      kwinrc."Tiling/ff808ca8-e8a7-43c7-971b-fbb976fd8f50/ec653ff8-619c-474a-9428-45a2e1cb0fab".tiles =
        "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
      # Lock screen wallpaper — absolute path, only valid on this machine
      kscreenlockerrc."Greeter/Wallpaper/org.kde.image/General".Image =
        "/home/vcaaron/Downloads/wp7017665-halo-infinite-4k-wallpapers.png";
      kscreenlockerrc."Greeter/Wallpaper/org.kde.image/General".PreviewImage =
        "/home/vcaaron/Downloads/wp7017665-halo-infinite-4k-wallpapers.png";
    };
  };
}
