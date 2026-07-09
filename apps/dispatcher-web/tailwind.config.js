/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{vue,js}'],
  theme: {
    extend: {
      colors: {
        flovi: {
          ink: '#100B2F',
          night: '#17113F',
          violet: '#6246EA',
          mint: '#34F5A6',
          sky: '#9BD8FF',
          lemon: '#FFE985',
          lilac: '#C7B8FF',
        },
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        glow: '0 24px 80px rgba(52, 245, 166, 0.18)',
        card: '0 22px 70px rgba(8, 6, 28, 0.22)',
      },
    },
  },
  plugins: [],
};
