export function throttle(fun, delay, fallback) {
  let lastTime = 0;
  return function (...args) {
    let now = Date.now();
    if (now - lastTime >= delay) {
      fun(...args);
      lastTime = now;
    } else if (fallback) {
      fallback(...args);
    }
  };
}
export const debounce = (callback, wait) => {
  let timeoutId = null;
  return (...args) => {
    window.clearTimeout(timeoutId);
    timeoutId = window.setTimeout(() => {
      callback(...args);
    }, wait);
  };
};
