export const isMobile = (): boolean => {
  const phone = window.matchMedia("(max-width: 768px)").matches;
  const hasTouch = "ontouchstart" in window;
  return phone || hasTouch;
};

export const hexColor = (r: number, g: number, b: number, a: number): string => {
  const red = r.toString(16).padStart(2, "0");
  const green = g.toString(16).padStart(2, "0");
  const blue = b.toString(16).padStart(2, "0");
  const alpha = a.toString(16).padStart(2, "0");
  return `#${red}${green}${blue}${alpha}`;
};
