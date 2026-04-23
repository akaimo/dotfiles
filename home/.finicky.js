export default {
  defaultBrowser: "Firefox",
  handlers: [
    {
      match: [
        "google.com/*",
        "*.google.com/*",
        "g.co/*",
        "*.g.co/*",
        "*.esa.io/*",
      ],
      browser: {
        name: "Google Chrome",
        profile: "Default",
      },
    },
  ],
};
