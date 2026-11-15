const fs = require("node:fs");
const { parse, printParseErrorCode } = require("jsonc-parser");

const errors = [];
parse(fs.readFileSync(process.argv[2], "utf8"), errors, {
  allowTrailingComma: true,
});
for (const error of errors) {
  console.error(
    `${printParseErrorCode(error.error)} at offset ${error.offset}`,
  );
}
process.exitCode = errors.length ? 1 : 0;
