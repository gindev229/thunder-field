<script>
  import { fade } from 'svelte/transition'; 
</script>

<div class="fixed flex font-semibold flex flex-col inset-0 bg-black bg-opacity-70 z-30 mt-[10px] gap-[20px]" in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}> 
  <div class="flex flex-col items-center sm:w-[400px] w-[300px] bg-darkCard mx-auto my-auto pt-4 pb-6 gap-[10px] rounded-lg shadow">
      <span class="text-3xl text-blue">
          Success
      </span>
      <svg class="checkmark h-[100px] inline-block my-[10px]" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 52">
          <circle class="checkmark__circle" cx="26" cy="26" r="25" fill="none"/>
          <path class="checkmark__check" fill="none" d="M14.1 27.2l7.1 7.2 16.7-16.8"/> 
          <style>
              .checkmark {
              border-radius: 50%;
              display: block;
              stroke-width: 2;
              stroke: #0ABFFF;
              stroke-miterlimit: 10;
              box-shadow: inset 0px 0px 0px #0ABFFF;
              animation: fill 0.4s ease-in-out 0.4s forwards, scale 0.3s ease-in-out 0.9s both;
              }
          
              .checkmark__circle {
              stroke-dasharray: 166;
              stroke-dashoffset: 166;
              stroke-width: 2;
              stroke-miterlimit: 10;
              stroke: #0ABFFF;
              fill: none;
              animation: stroke 0.6s cubic-bezier(0.65, 0, 0.45, 1) forwards;
              }
          
              .checkmark__check {
              transform-origin: 50% 50%;
              stroke-dasharray: 48;
              stroke-dashoffset: 48;
              animation: stroke 0.3s cubic-bezier(0.65, 0, 0.45, 1) 0.8s forwards;
              }
          
              @keyframes stroke {
              100% {
                  stroke-dashoffset: 0;
              }
              }
              @keyframes scale {
              0%, 100% {
                  transform: none;
              }
              50% {
                  transform: scale3d(1.1, 1.1, 1);
              }
              }
              @keyframes fill {
              100% {
                  box-shadow: inset 0px 0px 0px 0px #0ABFFF;
              }
              }
          </style>
      </svg>
  </div>
</div>