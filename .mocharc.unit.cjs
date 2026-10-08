const path = require("path");

require("@babel/register")({ extensions: [".ts"], only: [path.join(__dirname, "src")], cache: false });

module.exports = {
  extension: ["ts"],
  spec: ["src/**/__tests__/**/*.test.ts"],
};
