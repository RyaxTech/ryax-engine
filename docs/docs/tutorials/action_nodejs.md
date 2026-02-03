# Create NodeJS Action

Ryax supports actions written in **NodeJS**.
To create a NodeJS action you need a ryax_handler.js that exports
a single function with a dict as input and a dict as output.

```js
var uc = require('upper-case');

function handle(ryax_input) {
    output_str = uc.upperCase(ryax_input["input_str"]);
    return { "output_str" : output_str };
}
module.exports = handle;
```

It is mandatory to have the `module.exports` assigned to the function to allow ryax to find the entrypoint of your applicaiton, you can add more files and functions but you must export only a single function on file `ryax_handler.js`.


You can add dependencies in a `packages.json` file on the same directory.

```json
{
 "name": "ryax_handler",
 "version": "1.1.1",
 "dependencies": {
  "upper-case": ""
 }
}
```

Now create a `ryax_metadata.yaml` file where you define inputs and outputs with
some description of your Ryax action and you're done! Don't forget to set the
type to `type: nodejs` :)

```yaml
apiVersion: "ryax.tech/v2.0"
kind: Processor
spec:
  id: upper-case
  human_name: Transform a string into uppercase.
  type: nodejs
  version: "0.0.1"
  description: "NodeJS upper case string, test nodejs with npm dependencies"
  categories:
  - Test
  - nodejs
  inputs:
    - help: input str
      human_name: input_str
      name: input_str
      type: string
  outputs:
    - help: output str
      human_name: output_str
      name: output_str
      type: string
```

You can see the complete example [here](https://gitlab.com/ryax-tech/workflows/default-actions/-/tree/master/actions/nodejs-openweathermap)
