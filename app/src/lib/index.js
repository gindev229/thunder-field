// place files you want to import through the `$lib` alias in this folder.
export function emitRightText(value, numberChar) {
    // Convert value to string if it's a number
    value = value.toString();

    if (value.length > numberChar) {
        value = value.slice(0, numberChar) + "...";
    }
    return value;
};
export function emitBetweenText(value, numberChar) {
    // Convert value to string if it's a number
    if(!value){
      return
    }
    value = value.toString();

    if (value.length > numberChar) {
        value = value.slice(0, 5) + "..." + value.slice(value.length - 5, value.length);
    }
    return value;
}

export function bigIntToFloat(number) {
    const natural = number / 10n ** 18n;
    const decimal = number % 10n ** 18n;

    return parseFloat(natural.toString() + "." + decimal.toString().padStart(18, "0"));
}

//Convert number
export function roundNum(num, decimals) {
    // Convert the number to the desired number of decimal places
    let str = num.toFixed(decimals);
    let str2;
    // Remove trailing zeros
    str2 = str.replace(/(\.\d*?[1-9])0+$|\.0*$/, '$1');
    str2 = str2;
    return str2;
  }

  // Caculate time ago
export function timeAgo(timeCreated) {
    const now = Date.now(); // Current time in milliseconds
    const difference = now - timeCreated; // Difference in milliseconds
  
    // Convert difference to different units
    const seconds = Math.floor(difference / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    const weeks = Math.floor(days / 7);
    // Rough approximation for months and years, more accurate calculation could be done with Date objects
    const months = Math.floor(days / 30);
    const years = Math.floor(days / 365);
  
    // Format the output
    if (seconds < 60) {
      return `${seconds} seconds ago`;
    } else if (minutes < 60) {
      return `${minutes} minutes ago`;
    } else if (hours < 24) {
      return `${hours} hours ago`;
    } else if (days < 7) {
      return `${days} days ago`;
    } else if (weeks < 4) {
      return `${weeks} weeks ago`;
    } else if (months < 12) {
      return `${months} months ago`;
    } else {
      return `${years} years ago`;
    }
  }


  export function formatTimeLeft(milliseconds) {
    const totalSeconds = Math.floor(milliseconds / 1000);
    const totalMinutes = Math.floor(totalSeconds / 60);
    const totalHours = Math.floor(totalMinutes / 60);
    const totalDays = Math.floor(totalHours / 24);
    const totalWeeks = Math.floor(totalDays / 7);

    if (totalDays >= 7) {
    return `${totalWeeks} weeks ${totalDays % 7} days`;
    } else if (totalDays < 7 && totalDays >= 1) {
    return `${totalDays} days ${totalHours % 24} hours`;
    } else if (totalDays < 1) {
    return `${totalHours} hours ${totalMinutes % 60} minutes`;
    }
}