import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "#121212",
        primary: "#FF6B00",
        surface: "#1C1C1C",
        border: "#2A2A2A",
      },
    },
  },
  plugins: [],
};
export default config;
