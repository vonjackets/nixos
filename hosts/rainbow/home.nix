{ ... }:
{
  programs.plasma = {
    shortcuts = {
      ActivityManager.switch-to-activity-3d0e4b44-5c26-436d-b77b-049600a0a0c6 = [ ];
    };
    configFile = {
      kactivitymanagerdrc.activities."3d0e4b44-5c26-436d-b77b-049600a0a0c6" = "Default";
      kwinrc.Desktops.Id_1 = "e81bac7d-fcc9-4d47-bdb3-22b40cb6b0d5";
      kwinrc."Tiling/e81bac7d-fcc9-4d47-bdb3-22b40cb6b0d5/dd4dfa18-b528-4a29-a9a5-da1d037c8084".padding = 4;
      kwinrc."Tiling/e81bac7d-fcc9-4d47-bdb3-22b40cb6b0d5/dd4dfa18-b528-4a29-a9a5-da1d037c8084".tiles =
        "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";
    };
  };
}
