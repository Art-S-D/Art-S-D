const fs = require("fs").promises;
const { $, cd } = require("zx");
const { SSM } = require("@aws-sdk/client-ssm");

const ssm = new SSM({ region: process.env.REGION });

async function handler(event, context) {
    const pat = (
        await ssm.getParameter({
            Name: process.env.PAT,
            WithDecryption: true,
        })
    ).Parameter.Value;

    cd("/tmp");
    await $`git clone https://Art-S-D:${pat}@github.com/Art-S-D/Art-S-D.git`;
    cd("Art-S-D");

    const age = new Date().getFullYear() - 1998;
    const readmeTemplate = await fs.readFile("src/template.md", {
        encoding: "utf-8",
    });
    const readme = readmeTemplate.replace(/%AGE%/g, age);
    await fs.writeFile("README.md", readme);

    await $`git config user.email darthopicoeur@gmail.com`;
    await $`git config user.name Readme-Bot`;
    await $`git add README.md`;
    await $`git commit -m "bump age" && git push`;
}

module.exports = { handler };
