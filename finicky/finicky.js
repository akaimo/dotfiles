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
        "*.openai.com/*",
        "claude.ai/*",
        "claude.com/*",
        "forms.gle/*",
        "slack.com/*",
        "*.slack.com/*",
      ],
      browser: {
        name: "Google Chrome",
        profile: "Default",
      },
    },
  ],
};
