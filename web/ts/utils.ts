export const isMobile = (): boolean => {
  const phone = window.matchMedia("(max-width: 768px)").matches;
  const hasTouch = "ontouchstart" in window;
  return phone || hasTouch;
};

type HexColor = {
  (v: number): string;
  (r: number, g: number, b: number, a: number): string;
};
export const hexColor: HexColor = (r: number, g?: number, b?: number, a?: number): string => {
  if (g === undefined) {
    return `#${r.toString(16).padStart(8, "0")}`;
  }

  const red = r.toString(16).padStart(2, "0");
  const green = g.toString(16).padStart(2, "0");
  const blue = b!.toString(16).padStart(2, "0");
  const alpha = a!.toString(16).padStart(2, "0");

  return `#${red}${green}${blue}${alpha}`;
};
