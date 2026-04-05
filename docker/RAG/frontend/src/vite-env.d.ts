/// <reference types="vite/client" />

declare module 'katex/contrib/auto-render' {
  interface Delimiter {
    left: string;
    right: string;
    display: boolean;
  }

  interface AutoRenderOptions {
    delimiters?: Delimiter[];
    throwOnError?: boolean;
  }

  const renderMathInElement: (element: HTMLElement, options?: AutoRenderOptions) => void;
  export default renderMathInElement;
}
