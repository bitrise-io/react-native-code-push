// Globals the RN runtime provides that are not in the ES lib, declared narrowly instead of pulling in lib "dom" or @types/node.
// Interface + var (not const) so this merges with those declarations when an editor or other config also loads them.
// TODO: replace this file with `"types": ["react-native"]` (as @react-native/typescript-config does) once the build
// moves to TypeScript 5 and `moduleResolution: "bundler"`: RN exposes its types only through package.json "exports".
interface Console {
    log(...data: any[]): void;
}
declare var console: Console;
