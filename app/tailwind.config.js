/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      fontFamily: {
        Lexend: ['Lexend', 'sans-serif'],
        Orbitron: ['Orbitron', 'sans-serif'],
        Oxanium: ['Oxanium', 'sans-serif'],
        Marvel: ['Marvel', 'sans-serif']
      },
      colors: {
        lightGray:'#C1C1C1',
        darkGray: '#838B92',
        dark: '#181823',
        lightDark: '#1F202E',
        lightBg: '#F4F7F9',
        sea: '#58F6F7',
        sea: '#58F6F7',
        darkGreen: '#2B7E21',
        yellowOverlay: '#F4F1E7',
        lightYellow:'#F9F0B1',
        yellow:'#FDFAE5',
        yellowButton:'#E2BF00',
        green:'#AFED64',
        greenHover:'#215B1A',
        yellowHover:'#B69C0F',
        grayBorder:'#D4D6D3',
        grayInput:'#F4F7F9',
        lightWood:'#806E2F',
        darkWood:'#372F1F',
        lightestWood:"#D6C99E",
        button:"#0ABFFF",
        buttonHover:"#0A9ACD",
        darkBlue:'#0E242C',
        blue:"#0ABFFF"
      },
      backgroundImage: {
        'orange': 'linear-gradient(to bottom, #00843F, #CAA201)',
        'greenYellow': 'linear-gradient(to bottom, #FFFBE6, #C9DED3)',
        'yellowGreenHigh': 'linear-gradient(to right, #F2EDC3, #8EDD85)',
        'yellowGreenBold': 'linear-gradient(to right, #2F8D2D, #889916)',
        'linearRed': 'linear-gradient(to right, #F61616, #900D0D)',
        'linearGreen': 'linear-gradient(to right, #C8FFA7, #79E139)',
        'linearYellow': 'linear-gradient(to bottom, #FFFBAB, #BDB623)'

      }
    },
  },
  plugins: [],
}

