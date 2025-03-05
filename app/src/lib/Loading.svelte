<script>
  import { fade } from 'svelte/transition'; 
</script>
<div class="fixed font-semibold flex flex-col justify-center items-center inset-0 bg-black bg-opacity-70 z-30 mt-[10px]" in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}> 
  <svg class=" relative lg:h-[400px] lg:w-[400px] md:h-[350px] md:w-[350px] sm:h-[300px] sm:w-[300px]  h-[230px] w-[230px] mx-auto my-auto overflow-hidden" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300">
      <defs>
        <filter id="glow" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="4" result="blur" />
          <feComposite in="SourceGraphic" in2="blur" operator="over" />
        </filter>
        
        <linearGradient id="cyberpunkGradient1" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#00ccff" />
          <stop offset="100%" stop-color="#0066cc" />
        </linearGradient>
        
        <linearGradient id="cyberpunkGradient2" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#4169E1" />
          <stop offset="100%" stop-color="#00BFFF" />
        </linearGradient>
        
        <linearGradient id="cyberpunkGradient3" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#1E90FF" />
          <stop offset="100%" stop-color="#87CEFA" />
        </linearGradient>
      </defs>
      
      <style>
        @keyframes rotateSegment1 {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
        
        @keyframes rotateSegment2 {
          0% { transform: rotate(180deg); }
          100% { transform: rotate(540deg); }
        }
        
        @keyframes rotateMiddle {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
        
        @keyframes rotateSlow {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
        
        @keyframes glitchEffect {
          0%, 100% { opacity: 1; }
          25% { opacity: 0.8; }
          35% { opacity: 0.9; }
          45% { opacity: 0.7; }
          60% { opacity: 1; }
          75% { opacity: 0.9; }
          85% { opacity: 0.8; }
        }
        
        .segment1 {
          transform-origin: 150px 150px;
          animation: rotateSegment1 4.5s infinite linear, glitchEffect 2s infinite;
        }
        
        .segment2 {
          transform-origin: 150px 150px;
          animation: rotateSegment2 4.5s infinite linear, glitchEffect 2s infinite;
        }
        
        .middle-segment {
          transform-origin: 150px 150px;
          animation: rotateMiddle 1.8s infinite linear, glitchEffect 1.8s infinite;
        }
        
        .inner-segment {
          transform-origin: 150px 150px;
          animation: rotateSlow 8s infinite linear, glitchEffect 1.5s infinite;
        }
        
        .background-grid {
          opacity: 0.2;
        }
      </style>
    

      

      
      <g class="segment1">
        <circle cx="150" cy="150" r="90" fill="none" stroke="url(#cyberpunkGradient1)" stroke-width="4" stroke-dasharray="30 111.25 30 111.25 30 111.25 30 111.25" filter="url(#glow)" />
      </g>
      
      <g class="middle-segment">
        <circle cx="150" cy="150" r="70" fill="none" stroke="url(#cyberpunkGradient2)" stroke-width="4" stroke-dasharray="60 160 60 160" filter="url(#glow)" />
      </g>
      
      <g class="inner-segment">
        <circle cx="150" cy="150" r="50" fill="none" stroke="url(#cyberpunkGradient3)" stroke-width="4" stroke-dasharray="25 290" filter="url(#glow)" />
      </g>
  
  </svg>

  <span class="absolute text-white self-center md:mt-[300px] sm:mt-[200px]">
    TIP: Changing your RPC in wallet settings if loading takes too long
  </span>
</div>